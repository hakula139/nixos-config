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
    assistant: str
    score: float
    floor: float
    body_chars: int
    passage: str
    # Keyed by feature name at runtime, so both stay plain mappings.
    metrics: dict[str, float]
    means: dict[str, dict[str, float]]
    hedge_per_1k: float
    hedge_hits: list[str]
    attitude_per_1k: float
    attitude_hits: list[str]
    antithesis: int


# One classifier per assistant. These are a fit, so one hand-edited row breaks
# the pooled variance the rest of it depends on. Corpus and method are in
# README.md. Gemini is absent on purpose, since its Chinese sits too close to
# human prose to separate.
ASSISTANTS: dict[str, dict[str, FeatureStats]] = {
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
MIN_CJK_OF_CHARS = 0.30
MIN_CJK_OF_ALPHA = 0.55
CJK = re.compile(r'[\u4e00-\u9fff]')
LATIN = re.compile(r'[A-Za-z]')
PARA_SPLIT = re.compile(r'\n\s*\n')

# Outside the fitted length range the class means are extrapolation, so scoring
# clamps to it.
LN_CHARS_RANGE = (math.log(MIN_CHARS), math.log(584))

# Calibrated so that one paragraph of the author's own typed Chinese clears the
# floor 20% of the time. The log term pays for worst-of-k: the verdict is the
# highest-scoring paragraph, so a longer payload draws more chances at the same
# threshold. Typed Chinese is the register to calibrate on, since a hook payload
# is typed and README.md measures how far it sits from essay prose.
SCORE_FLOOR = 3.04
FLOOR_PER_LOG_PARA = 1.23

# Chinese strings short clauses on commas where English divides with a
# punctuation hierarchy, and assistant Chinese imports the hierarchy.
LINK_MARKS = '；：'
CLAUSE_MARKS = '。！？…；：，、—'
MARKS = CLAUSE_MARKS + '（）()「」『』《》%'
CLAUSE_SPLIT = re.compile(f'[{CLAUSE_MARKS}]')
CLAUSE_MARK_RUN = re.compile(f'[{CLAUSE_MARKS}]{{2,}}')
# `%` rides along because jieba emits it as a token and the fit counted it.
MARK_SET = frozenset(MARKS)


def collapse_marks(match: re.Match[str]) -> str:
    # Removing quotes and code leaves marks adjacent, which would inflate `link`
    # and `pent`. A link mark cannot be that residue, so it survives.
    text = match.group(0)
    return next((ch for ch in LINK_MARKS if ch in text), text[0])


def strip_blocks(text: str) -> str:
    # These four span blank lines, so they run before the paragraph split. A fence
    # split first keeps its Chinese string literals, which then score as prose.
    text = re.sub(r'^\+\+\+.*?\+\+\+', '', text, flags=re.S)
    text = re.sub(r'```.*?```', '', text, flags=re.S)
    text = re.sub(r':::.*?:::', '', text, flags=re.S)
    return re.sub(r'<!--.*?-->', '', text, flags=re.S)


def strip_noise(text: str) -> str:
    text = re.sub(r'`[^`]*`', '', text)
    text = re.sub(r'!?\[([^\]]*)\]\([^)]*\)', r'\1', text)
    text = re.sub(r'^\s*#+ .*$', '', text, flags=re.M)
    text = re.sub(r'\[\^[^\]]+\]:?', '', text)
    text = re.sub(r'[*_>|#]', '', text)
    # A quoted Japanese line would otherwise measure as Chinese.
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
    words = [w for w in jieba.lcut(body) if w not in MARK_SET]
    tagged = pseg.lcut(body)
    total = len(words) or 1
    pos = Counter(t.flag[0] for t in tagged)
    tags = sum(pos.values()) or 1
    bigrams = Counter(zip(words, words[1:], strict=False))
    marks = Counter(ch for ch in body if ch in MARK_SET)
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
    # Two floors. The first refuses a payload that is mostly digits, rules or ASCII
    # art, where the second would read a single CJK character as 100% Chinese. The
    # second catches a technical Chinese paragraph carrying more Latin identifiers
    # than prose.
    if cjk / len(body) < MIN_CJK_OF_CHARS:
        return False
    return cjk / (cjk + len(LATIN.findall(body))) >= MIN_CJK_OF_ALPHA


class Scored(NamedTuple):
    score: float
    passage: str
    body: str
    metrics: dict[str, float]
    means: dict[str, dict[str, float]]


def discriminant(
    metrics: dict[str, float], stats: dict[str, FeatureStats], chars: int
) -> tuple[float, dict[str, dict[str, float]]]:
    lo, hi = LN_CHARS_RANGE
    ln = max(lo, min(hi, math.log(chars)))
    total = 0.0
    means: dict[str, dict[str, float]] = {}
    for k, f in stats.items():
        x = metrics[k]
        human_mean = f.human_intercept + f.human_slope * ln
        assistant_mean = f.assistant_intercept + f.assistant_slope * ln
        total += ((x - human_mean) ** 2 - (x - assistant_mean) ** 2) / f.pooled_sd**2
        means[k] = {
            'human': round(human_mean, 3),
            'assistant': round(assistant_mean, 3),
        }
    return total, means


def classify(text: str, assistant: str) -> Report | None:
    stats = ASSISTANTS[assistant]
    # Several features move with length, so scoring a whole payload would compare it
    # against means fitted for a length it does not have.
    scored: list[Scored] = []
    for para in PARA_SPLIT.split(strip_blocks(text)):
        body = strip_noise(para)
        if not admissible(body):
            continue
        metrics = measure(body)
        score, means = discriminant(metrics, stats, len(body))
        scored.append(Scored(score, para, body, metrics, means))
    if not scored:
        return None

    top = max(scored, key=lambda row: row.score)
    return {
        'assistant': assistant,
        # Positive means nearer this assistant's mean than a human's.
        'score': round(top.score, 2),
        'floor': round(SCORE_FLOOR + FLOOR_PER_LOG_PARA * math.log(len(scored)), 2),
        'body_chars': len(top.body),
        'passage': top.passage.strip(),
        'metrics': {k: round(v, 3) for k, v in top.metrics.items()},
        # Fitted at this passage's own length, so the judge compares like with like.
        'means': top.means,
        'hedge_per_1k': per_1k(top.body, HEDGES),
        'hedge_hits': [w for w in HEDGES if w in top.body],
        'attitude_per_1k': per_1k(top.body, ATTITUDES),
        'attitude_hits': [w for w in ATTITUDES if w in top.body],
        'antithesis': len(ANTITHESIS.findall(top.body)),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument('assistant', choices=list(ASSISTANTS))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = classify(sys.stdin.read(), args.assistant)
    if result is None:
        return 1
    json.dump(result, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == '__main__':
    sys.exit(main())
