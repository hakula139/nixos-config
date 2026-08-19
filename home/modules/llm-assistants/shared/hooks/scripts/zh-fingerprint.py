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


class FeatureStats(TypedDict):
    mu: float
    sd: float
    human: float
    assistant: float


class Report(TypedDict):
    model: str
    score: float
    chars: int
    # Both are keyed off MEDIANS at runtime, so they stay plain mappings.
    metrics: dict[str, float]
    medians: dict[str, dict[str, float]]
    hedge_per_1k: float
    hedge_hits: list[str]
    attitude_per_1k: float
    attitude_hits: list[str]
    antithesis: int


# Nearest-centroid parameters, one classifier per assistant, fitted on the
# training half of a labelled corpus (hakula.xyz-kiln prose for human, session
# transcripts for each assistant's own Chinese) and scored on the disjoint other
# half, over the paragraphs long enough to measure: claude-code 82% recall at
# 10% false positives, codex 92% at 3%. Gemini is absent on purpose: its Chinese
# sits too close to human prose to separate.
#
# Per feature, `mu` and `sd` z-score the measured ratio against the training
# half, and `human` and `assistant` are the two class centroids in that space.
MODELS: dict[str, dict[str, FeatureStats]] = {
    'claude-code': {
        'ttr': {'mu': 0.7750, 'sd': 0.0761, 'human': -0.463, 'assistant': 0.561},
        'adv': {'mu': 0.0693, 'sd': 0.0298, 'human': 0.499, 'assistant': -0.604},
        'part': {'mu': 0.0839, 'sd': 0.0342, 'human': 0.573, 'assistant': -0.694},
        'noun': {'mu': 0.1726, 'sd': 0.0450, 'human': 0.325, 'assistant': -0.393},
        'link': {'mu': 0.0715, 'sd': 0.0812, 'human': -0.432, 'assistant': 0.523},
    },
    'codex': {
        'ttr': {'mu': 0.8128, 'sd': 0.0982, 'human': -0.744, 'assistant': 0.834},
        'part': {'mu': 0.0726, 'sd': 0.0409, 'human': 0.755, 'assistant': -0.847},
        'noun': {'mu': 0.1977, 'sd': 0.0504, 'human': -0.208, 'assistant': 0.233},
        'pent': {'mu': 1.7864, 'sd': 0.3636, 'human': -0.054, 'assistant': 0.060},
        'link': {'mu': 0.0983, 'sd': 0.1159, 'human': -0.534, 'assistant': 0.599},
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

HEDGES = [
    '不太',
    '大抵',
    '大概',
    '多少',
    '或许',
    '基本',
    '可能',
    '恐怕',
    '某种程度',
    '起码',
    '稍微',
    '说不定',
    '似乎',
    '算是',
    '通常',
    '往往',
    '未必',
    '一般',
    '有点',
    '至少',
]
ATTITUDE = [
    '本来',
    '毕竟',
    '当然',
    '到底',
    '倒是',
    '反而',
    '反正',
    '干脆',
    '好歹',
    '竟然',
    '居然',
    '明明',
    '偏偏',
    '其实',
    '恰恰',
    '实际上',
    '实在',
    '索性',
    '无非',
    '早就',
    '照样',
    '终究',
]
# The gap spans clause dividers as well as sentence enders, or a match runs
# past a question mark into the next. The lookbehind drops the rhetorical 是不是.
ANTITHESIS = re.compile(
    r'(?<!是)(?:不是|并非)[^，。；？！：—…]{1,25}[，、]?\s*(?:而是|是)|而不是'
)

MIN_CHARS = 100
MIN_CJK_RATIO = 0.55
CJK = re.compile(r'[\u4e00-\u9fff]')

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
    # first: one kana character pulls in the kana and kanji run following it,
    # which is how a title or a lyric leaves no CJK residue behind.
    text = re.sub(r'[\u3040-\u30ff][\u3040-\u30ff\u4e00-\u9fff]*', '', text)
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
    point = {k: (metrics[k] - f['mu']) / f['sd'] for k, f in config.items()}

    def distance(centroid: str) -> float:
        return math.sqrt(sum((point[k] - f[centroid]) ** 2 for k, f in config.items()))

    return {
        'model': model,
        # Positive means closer to the assistant's centroid than to a human's.
        'score': round(distance('human') - distance('assistant'), 2),
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
