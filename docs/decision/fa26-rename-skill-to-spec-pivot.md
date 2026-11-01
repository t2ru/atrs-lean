---
type: Architecture Decision Record
title: "スキルの名前を port-lang から spec-pivot に改め、ATRS のパスと参照を張り直す"
description: "スキルの ADR cfad で方法を Spec Pivot と名付け、スキルの名前を spec-pivot に改めた。ATRS では、スキルのパス（Lake の require・lake-manifest・CI・trace/project.json・trace/checks.json・tools/ci）と文書の参照を新しい名前に張り直す。ADR f4e1 のほかの決定は変えない。"
tags: [adr, skill, naming]
id: "fa26abb0-4821-48f4-ab4d-beeeca07af36"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T14:50:00+09:00
---

# スキルの名前を port-lang から spec-pivot に改め、ATRS のパスと参照を張り直す

## Context and Problem Statement

[ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md) は、言語間移植の方法をスキル `port-lang` に切り出した。
プロジェクトオーナーの指示で、この方法を **Spec Pivot** と名付け、スキルの名前を `spec-pivot` に改めた（[スキルの ADR cfad](../../.agents/skills/spec-pivot/references/docs/decision/cfad-name-the-method-spec-pivot.md)）。
ADR f4e1 は、ATRS にも影響するスキルの改訂について、ATRS の ADR を作ることを求めている。改名は、ATRS のビルド・CI・追跡の設定にあるスキルのパスに及ぶ。

## Decision Drivers

* ATRS のビルド・CI・検査が、改名の後もそのまま通ること
* 追跡のハッシュと、ADR・backlog の ID を変えないこと
* 過去の記録の来歴を保つこと

## Considered Options

* スキルのパスと、名前としての言及をすべて新しい名前に張り直す（来歴の文は残す）
* スキルのディレクトリを改名せず、文書で名前だけを使う

## Decision Outcome

Chosen option: "スキルのパスと、名前としての言及をすべて新しい名前に張り直す（来歴の文は残す）", because 識別子と名前を一致させ、2 つの呼び方が併存しないようにするため。プロジェクトオーナーが選んだ。

* `.agents/skills/port-lang` を `.agents/skills/spec-pivot` に、`scripts/docs/profiles/port-lang.json` を `profiles/spec-pivot.json` に移した。
* 次の箇所のパスを張り直した。
  * `lakefile.lean`・`lake-manifest.json`（ルートと `lean/`）
  * `.github/workflows/lean.yml`
  * `tools/ci/`・`tools/conformance/`
  * `trace/project.json`・`trace/checks.json`・`trace/renames.json`
* 文書・コード・コメントの `port-lang` を `spec-pivot` に改めた。次は旧名のまま残す。
  * `docs/log.md` の過去の項（来歴。リンクは張り直した）
  * ADR f4e1 の本文（`port-lang` と名付けた決定そのもの）
* Lean のパッケージ名・モジュール名・名前空間は変えない。追跡のハッシュは変わらない。

### Consequences

* Good, because ATRS の文書とスキルで、方法を同じ名前で呼べる。
* Bad, because 改名の前に分かれたブランチは、取り込むときにパスの競合が出る。

### Confirmation

* `tools/ci/lean.sh`（CI）が通ること。特に、`lake build`、`trace manifest --check`、`trace check`、`ids.py check`、`okf_check.py`。
* `git grep port-lang` の残りが、上の来歴の箇所だけであること。

## Pros and Cons of the Options

### パスと言及をすべて張り直す

* Good, because 呼び方が 1 つになる。
* Bad, because 変更が広い（約 150 ファイル）。

### ディレクトリを改名しない

* Good, because 変更が小さい。
* Bad, because 方法の名前と識別子が食い違い続ける。

## More Information

* [ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md), [ADR 50f9](50f9-move-skill-records-to-skill-bundle.md)
* [スキルの ADR cfad](../../.agents/skills/spec-pivot/references/docs/decision/cfad-name-the-method-spec-pivot.md)
