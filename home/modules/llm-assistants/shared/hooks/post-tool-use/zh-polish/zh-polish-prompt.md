# Chinese Rewrite Instruction

The two lines below are substituted at build time and the draft is appended last.
Both halves are load-bearing and were chosen against human scores, so read
`zh-quality/DESIGN.zh-CN.md` before editing either.

The English doctrine goes in as the system prompt because it scored highest of
five context frames on two models (6.0 / 7.0 against 3.0 to 5.0 for a Chinese
rule list, kiln exemplars, and a bare call). The instruction itself stays Chinese
because that is the configuration the rewrite scores were measured under.

Two things this prompt deliberately does NOT do, both of which cost points in an
earlier round: it does not ask the rewriter to preserve every information item
(the three most obedient models scored lowest), and it supplies no exemplar
paragraphs (five samples lost points for grafting the author's persona).

---

下面这段中文是模型写的，读起来有机器感。请重写它。

重写时可以合并句子、删掉次要的信息点、改变段落切分，只要保住主要论点就行。不必逐句对应，也不必保留原有的信息量——宁可少说几件事，把话说顺。

三件具体要做的事：

1. 汉字之间的标点一律用全角，`,` `;` `:` `!` `?` 都要换成 `，` `；` `：` `！` `？`，破折号用 `——`。
2. 把被压短的句子接回去。原文有把一个意思切成几个短句的毛病，该连的地方要连。
3. 补虚词。该有的「的」「了」「就」「而」「所以」不要省。

保持 Markdown 结构不变：标题、列表、链接、行内代码和围栏代码块里的内容一个字都不要改。

直接输出重写后的文本，不要解释，不要加标题，不要用围栏包起来。
