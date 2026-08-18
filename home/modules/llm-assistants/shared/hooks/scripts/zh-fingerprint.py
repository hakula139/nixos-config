import argparse
import json
import math
import re
import sys
from collections import Counter
from collections.abc import Sequence
from typing import TypedDict

import jieba
import jieba.posseg as pseg


jieba.setLogLevel(60)


class Report(TypedDict):
    model: str
    score: float
    chars: int
    # Keyed dynamically off MEDIANS and `features`, so these stay plain mappings.
    metrics: dict[str, float]
    medians: dict[str, dict[str, float]]
    hedge_per_1k: float
    hedge_hits: list[str]
    attitude_per_1k: float
    attitude_hits: list[str]
    antithesis: int


class ModelConfig(TypedDict):
    features: list[str]
    mu: dict[str, float]
    sd: dict[str, float]
    human: list[float]
    assistant: list[float]


# Nearest-centroid parameters, one classifier per assistant, fitted on the
# training half of a labelled corpus (hakula.xyz-kiln prose for human, session
# transcripts for each assistant's own Chinese) and scored on the disjoint other
# half, over the paragraphs long enough to measure: claude-code 82% recall at
# 10% false positives, codex 92% at 3%. Gemini is absent on purpose: its Chinese
# sits too close to human prose to separate.
#
# `mu` and `sd` z-score a measured ratio against the training half. `human` and
# `assistant` are the two class centroids in that z-scored space, positional and
# aligned with `features`, so reordering one without the other silently corrupts
# every score. Only a length mismatch raises.
MODELS: dict[str, ModelConfig] = {
    'claude-code': {
        'features': ['ttr', 'adv', 'part', 'noun', 'link'],
        'mu': {
            'ttr': 0.7750,
            'adv': 0.0693,
            'part': 0.0839,
            'noun': 0.1726,
            'link': 0.0715,
        },
        'sd': {
            'ttr': 0.0761,
            'adv': 0.0298,
            'part': 0.0342,
            'noun': 0.0450,
            'link': 0.0812,
        },
        'human': [-0.463, 0.499, 0.573, 0.325, -0.432],
        'assistant': [0.561, -0.604, -0.694, -0.393, 0.523],
    },
    'codex': {
        'features': ['ttr', 'part', 'noun', 'pent', 'link'],
        'mu': {
            'ttr': 0.8128,
            'part': 0.0726,
            'noun': 0.1977,
            'pent': 1.7864,
            'link': 0.0983,
        },
        'sd': {
            'ttr': 0.0982,
            'part': 0.0409,
            'noun': 0.0504,
            'pent': 0.3636,
            'link': 0.1159,
        },
        'human': [-0.744, 0.755, -0.208, -0.054, -0.534],
        'assistant': [0.834, -0.847, 0.233, 0.060, 0.599],
    },
}

MEDIANS: dict[str, dict[str, float]] = {
    'ttr': {'human': 0.737, 'claude-code': 0.828, 'codex': 0.898},
    'adv': {'human': 0.083, 'claude-code': 0.046, 'codex': 0.062},
    'part': {'human': 0.103, 'claude-code': 0.062, 'codex': 0.035},
    'noun': {'human': 0.185, 'claude-code': 0.153, 'codex': 0.214},
    'link': {'human': 0.000, 'claude-code': 0.111, 'codex': 0.143},
    'reuse': {'human': 0.048, 'claude-code': 0.000, 'codex': 0.000},
    'pent': {'human': 1.811, 'claude-code': 2.121, 'codex': 1.842},
}

# Grouped by hand: E501 counts a CJK char as two columns, and the formatter
# would otherwise break these to one word per line.
# fmt: off
HEDGES = [
    '大概', '或许', '可能', '未必', '似乎', '多少', '有点', '稍微',
    '大抵', '不太', '恐怕', '说不定', '某种程度', '基本', '一般',
    '往往', '通常', '算是', '起码', '至少',
]
ATTITUDE = [
    '其实', '反而', '偏偏', '倒是', '本来', '无非', '早就', '照样',
    '明明', '毕竟', '居然', '竟然', '到底', '终究', '反正', '好歹',
    '干脆', '索性', '实在',
]
# fmt: on
ANTITHESIS = re.compile(
    r'不是[^，。；]{1,25}[，、]?\s*(?:而是|是)|而不是|并非[^，。；]{1,25}而是'
)

MIN_CHARS = 100
MIN_CJK_RATIO = 0.55
CJK = re.compile(r'[一-鿿]')
MARKS = '，。；、：！？…（）「」『』—()《》%'

# Chinese runs short clauses in series on commas, where English divides a
# sentence with a punctuation hierarchy. Assistant Chinese keeps the words and
# imports the hierarchy, which is where the translated feel comes from.
LINK_MARKS = '：；'
CLAUSE_SPLIT = re.compile(r'[，。；、：！？…—]')


def strip_noise(text: str) -> str:
    text = re.sub(r'^\+\+\+.*?\+\+\+', '', text, flags=re.S)
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    text = re.sub(r':::.*?:::', '', text, flags=re.S)
    text = re.sub(r'`[^`]*`', 'X', text)
    text = re.sub(r'!?\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'^\s*#+ .*$', '', text, flags=re.M)
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    text = re.sub(r'\[\^[^\]]+\]:?', '', text)
    text = re.sub(r'[*_>|#]', '', text)
    # The next three drop text whose diction belongs to someone else, since
    # dense quotation drags every ratio toward the assistant side. Japanese
    # first: a kana character pulls in the kana, ー and kanji run following it,
    # which is how a title or a lyric leaves no CJK residue behind.
    text = re.sub(r'[぀-ヿ][぀-ヿー一-鿿]*', '', text)
    text = re.sub(r'[「『][^」』]{0,80}[」』]', '', text)
    text = re.sub(r"[A-Za-z][A-Za-z',. ]{6,}", '', text)
    return re.sub(r'\s+', '', text)


def measure(body: str) -> dict[str, float]:
    words = [w for w in jieba.lcut(body) if w.strip() and w not in MARKS]
    tagged = pseg.lcut(body)
    total = len(words) or 1
    pos = Counter(t.flag[0] for t in tagged)
    tags = sum(pos.values()) or 1
    bigrams = Counter(zip(words, words[1:], strict=False))
    marks = Counter(ch for ch in body if ch in MARKS)
    mark_total = sum(marks.values()) or 1
    clauses = len([c for c in CLAUSE_SPLIT.split(body) if c]) or 1
    return {
        'ttr': len(set(words)) / total,
        'adv': pos.get('d', 0) / tags,
        'part': pos.get('u', 0) / tags,
        'noun': pos.get('n', 0) / tags,
        'link': sum(1 for ch in body if ch in LINK_MARKS) / clauses,
        'reuse': sum(v for v in bigrams.values() if v > 1) / max(1, total - 1),
        'pent': -sum(
            (v / mark_total) * math.log2(v / mark_total) for v in marks.values()
        ),
    }


def per_1k(body: str, words: Sequence[str]) -> float:
    return round(sum(body.count(w) for w in words) / len(body) * 1000, 2)


def classify(text: str, model: str) -> Report | None:
    body = strip_noise(text)
    if len(body) < MIN_CHARS:
        return None
    if len(CJK.findall(body)) / len(body) < MIN_CJK_RATIO:
        return None

    config = MODELS[model]
    metrics = measure(body)
    point = [
        (metrics[k] - config['mu'][k]) / config['sd'][k] for k in config['features']
    ]

    def distance(centroid: list[float]) -> float:
        return math.sqrt(
            sum((a - b) ** 2 for a, b in zip(point, centroid, strict=True))
        )

    return {
        'model': model,
        # Positive means closer to the assistant's centroid than to a human's.
        'score': round(distance(config['human']) - distance(config['assistant']), 2),
        'chars': len(body),
        'metrics': {k: round(metrics[k], 3) for k in MEDIANS},
        'medians': {
            k: {'human': v['human'], model: v[model]} for k, v in MEDIANS.items()
        },
        'hedge_per_1k': per_1k(body, HEDGES),
        'hedge_hits': [w for w in HEDGES if w in body],
        'attitude_per_1k': per_1k(body, ATTITUDE),
        'attitude_hits': [w for w in ATTITUDE if w in body],
        'antithesis': len(ANTITHESIS.findall(body)),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('model', choices=list(MODELS))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = classify(sys.stdin.read(), args.model)
    if result is None:
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == '__main__':
    sys.exit(main())
