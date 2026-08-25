import argparse
import json
import math
import re
import sys
from collections import Counter
from collections.abc import Sequence
from typing import NamedTuple, TypedDict


class FeatureStats(NamedTuple):
    human_intercept: float
    human_slope: float
    assistant_intercept: float
    assistant_slope: float
    pooled_sd: float


class Report(TypedDict):
    model: str
    score: float
    floor: float
    chars: int
    passage: str
    # Both are keyed off MEDIANS at runtime, so they stay plain mappings.
    metrics: dict[str, float]
    medians: dict[str, dict[str, float]]
    hedge_per_1k: float
    hedge_hits: list[str]
    attitude_per_1k: float
    attitude_hits: list[str]
    antithesis: int


# One classifier per assistant. Corpus, method and measured rates are in
# README.md; re-derive rather than hand-edit these. Gemini is absent on purpose,
# since its Chinese sits too close to human prose to separate.
MODELS: dict[str, dict[str, FeatureStats]] = {
    'claude-code': {
        'ttr': FeatureStats(1.2980, -0.1175, 1.1885, -0.0771, 0.1039),
        'adv': FeatureStats(0.0601, 0.0, 0.0530, 0.0, 0.0392),
        'part': FeatureStats(0.0757, 0.0, 0.0607, 0.0, 0.0365),
        'noun': FeatureStats(0.1810, 0.0, 0.1473, 0.0, 0.0630),
        'link': FeatureStats(0.0454, 0.0, 0.0863, 0.0, 0.1104),
        'reuse': FeatureStats(-0.1314, 0.0509, -0.0187, 0.0102, 0.1206),
        'pent': FeatureStats(0.0108, 0.3076, -1.1333, 0.6562, 0.5315),
    },
    'codex': {
        'ttr': FeatureStats(1.2980, -0.1175, 1.4582, -0.1298, 0.1002),
        'adv': FeatureStats(0.0601, 0.0, 0.0594, 0.0, 0.0397),
        'part': FeatureStats(0.0757, 0.0, 0.0412, 0.0, 0.0358),
        'noun': FeatureStats(0.1810, 0.0, 0.1858, 0.0, 0.0649),
        'link': FeatureStats(0.0454, 0.0, 0.1295, 0.0, 0.1207),
        'reuse': FeatureStats(-0.1314, 0.0509, -0.0798, 0.0220, 0.1185),
        'pent': FeatureStats(0.0108, 0.3076, -0.2894, 0.4118, 0.4745),
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
ATTITUDES = [
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
# A bare 是 needs the comma: without it the pattern matches ordinary sentences
# such as 不是所有人都是这样想的, and it caught none of the 这并非……，这是 forms it
# was meant for. 而是 takes the comma or not. The lookbehind drops 是不是 and 要不是.
ANTITHESIS = re.compile(
    r'(?<![是要])(?:不是|并非)[^，。；？！：—…,.;?!]{1,25}'
    r'(?:[，、](?:这|那)?是|[，、]?而是)'
    r'|而不是'
)

MIN_CHARS = 45
MIN_CJK_RATIO = 0.55
MIN_CJK_DENSITY = 0.30
CJK = re.compile(r'[\u4e00-\u9fff]')
LATIN = re.compile(r'[A-Za-z]')
PARA_SPLIT = re.compile(r'\n\s*\n')

# Outside the fitted length range the class means are extrapolation, so scoring
# clamps to it.
LN_CHARS_RANGE = (math.log(MIN_CHARS), math.log(584))

# Calibrated so that one paragraph of the author's own typed Chinese clears the
# floor 20% of the time. The log term pays for worst-of-k: the verdict is the
# highest-scoring paragraph, so a longer payload draws more chances at the same
# threshold. Typed Chinese is the register to calibrate on, since it disagrees
# with essay prose by 2.5 points of score and a hook payload is typed.
SCORE_FLOOR = 3.04
FLOOR_PER_LOG_BLOCK = 1.23

# Chinese strings short clauses on commas where English divides with a
# punctuation hierarchy, and assistant Chinese imports the hierarchy.
LINK_MARKS = '；：'
CLAUSE_MARKS = '。！？…；：，、—'
MARKS = CLAUSE_MARKS + '（）()「」『』《》%'
CLAUSE_SPLIT = re.compile(f'[{CLAUSE_MARKS}]')
CLAUSE_MARK_RUN = re.compile(f'[{CLAUSE_MARKS}]{{2,}}')


def collapse_marks(run: re.Match[str]) -> str:
    # A run of marks is residue from the removals above, and would inflate `link`
    # and `pent`. A link mark inside it cannot be residue, so it survives.
    text = run.group(0)
    return next((ch for ch in LINK_MARKS if ch in text), text[0])


def strip_noise(text: str) -> str:
    text = re.sub(r'^\+\+\+.*?\+\+\+', '', text, flags=re.S)
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    text = re.sub(r':::.*?:::', '', text, flags=re.S)
    text = re.sub(r'`[^`]*`', '', text)
    text = re.sub(r'!?\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'^\s*#+ .*$', '', text, flags=re.M)
    text = re.sub(r'<!--.*?-->', '', text, flags=re.S)
    text = re.sub(r'\[\^[^\]]+\]:?', '', text)
    text = re.sub(r'[*_>|#]', '', text)
    # Quoted diction is someone else's and drags every ratio toward the assistant
    # side, so the next three remove it. Japanese leads: one kana character pulls in
    # the kana and kanji run after it, which is how a lyric leaves no CJK residue.
    text = re.sub(r'[\u3040-\u30ff][\u3040-\u30ff\u4e00-\u9fff]*', '', text)
    text = re.sub(r'[「『][^」』]{0,80}[」』]', '', text)
    text = re.sub(r"[A-Za-z][A-Za-z',. ]{6,}", '', text)
    text = re.sub(r'\s+', '', text)
    return CLAUSE_MARK_RUN.sub(collapse_marks, text)


def measure(body: str) -> dict[str, float]:
    # Imported inside the function: jieba costs 484ms to load, and the admission
    # guards reject before reaching this on most calls.
    import jieba
    import jieba.posseg as pseg

    jieba.setLogLevel(60)
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
        'link': sum(marks[ch] for ch in LINK_MARKS) / clauses,
        'reuse': sum(v for v in bigrams.values() if v > 1) / max(1, total - 1),
        'pent': -sum(
            (v / mark_total) * math.log2(v / mark_total) for v in marks.values()
        ),
    }


def per_1k(body: str, words: Sequence[str]) -> float:
    return round(sum(body.count(w) for w in words) / len(body) * 1000, 2)


def admissible(body: str) -> bool:
    if len(body) < MIN_CHARS:
        return False
    cjk = len(CJK.findall(body))
    # Two floors. Density refuses a payload that is mostly digits, rules or ASCII
    # art, none of which count as either script, so the ratio below would read a
    # single CJK character as 100% Chinese. The ratio then refuses real prose in
    # another language, where measuring against the whole body would instead have
    # counted a Chinese paragraph's own commas as foreign.
    if cjk / len(body) < MIN_CJK_DENSITY:
        return False
    alpha = cjk + len(LATIN.findall(body))
    return bool(alpha) and cjk / alpha >= MIN_CJK_RATIO


def class_score(
    metrics: dict[str, float], config: dict[str, FeatureStats], chars: int
) -> float:
    lo, hi = LN_CHARS_RANGE
    ln = max(lo, min(hi, math.log(chars)))
    total = 0.0
    for k, f in config.items():
        x = metrics[k]
        human = f.human_intercept + f.human_slope * ln
        assistant = f.assistant_intercept + f.assistant_slope * ln
        total += ((x - human) ** 2 - (x - assistant) ** 2) / f.pooled_sd**2
    return total


def classify(text: str, model: str) -> Report | None:
    config = MODELS[model]
    # Several features move with length, so scoring a whole payload would compare it
    # against means fitted for a length it does not have.
    scored = []
    for para in PARA_SPLIT.split(text):
        body = strip_noise(para)
        if not admissible(body):
            continue
        metrics = measure(body)
        scored.append((class_score(metrics, config, len(body)), para, body, metrics))
    if not scored:
        return None

    score, passage, body, metrics = max(scored, key=lambda row: row[0])
    return {
        'model': model,
        # Positive means nearer this assistant's mean than a human's.
        'score': round(score, 2),
        'floor': round(SCORE_FLOOR + FLOOR_PER_LOG_BLOCK * math.log(len(scored)), 2),
        'chars': len(body),
        'passage': passage.strip(),
        'metrics': {k: round(metrics[k], 3) for k in MEDIANS},
        'medians': {
            k: {'human': v['human'], model: v[model]} for k, v in MEDIANS.items()
        },
        'hedge_per_1k': per_1k(body, HEDGES),
        'hedge_hits': [w for w in HEDGES if w in body],
        'attitude_per_1k': per_1k(body, ATTITUDES),
        'attitude_hits': [w for w in ATTITUDES if w in body],
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
