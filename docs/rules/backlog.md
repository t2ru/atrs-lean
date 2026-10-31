---
type: Guideline
title: "バックログ規約"
description: "バックログ項目の形式・状態・完了の定義。"
tags: [rules, backlog]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
---

# バックログ規約

## ファイル

```
docs/backlog/<ID の先頭 4 文字>-<slug>.md
```

- 命名規則は ADR と同じ（ID は UUID v4、ファイル名の先頭は ID の先頭 4 文字、英小文字スラッグ、改名・削除しない。[decision-records.md](decision-records.md#ファイル名)）。`python3 -I .agents/skills/port-lang/scripts/docs/ids.py new backlog <slug>` が ID とファイル名を出す。
- `id`・`depends_on` と、`trace/features.json`・登録簿の backlog の列には ID 全体を、本文の参照には先頭 4 文字を書く（[documentation.md](documentation.md#リンク)）。
- 索引 [docs/backlog/README.md](../backlog/README.md) の表（ID の列は先頭 4 文字）と [docs/index.md](../index.md) を常に最新に保つ。
- アプリに依存しない作業（スキル port-lang の道具・Lean のライブラリ・方法の文書）は、スキルの [`references/docs/backlog/`](../../.agents/skills/port-lang/references/docs/backlog/README.md) に置く（[ADR 50f9](../decision/50f9-move-skill-records-to-skill-bundle.md)）。採番は `ids.py new backlog <slug> --dir .agents/skills/port-lang/references/docs/backlog`。ATRS の項目は `depends_on` でスキルの項目を指してよいが、スキルの項目は ATRS の項目を指さない。

## 項目の形式

```markdown
---
type: Backlog Item
title: "<題名>"
description: "<1 文の要約>"
tags: [backlog, <分野>]
id: "<UUID v4>"
state: todo
depends_on: ["<UUID v4>", ...]
generated:
  by: <producer>/<version>
  at: YYYY-MM-DDThh:mm:ss+09:00
---

# <題名>

## 目的
<なぜやるか。1〜3 文>

## 範囲
- <やること>

## 対象外
- <やらないこと>

## 完了条件
- [ ] <検証可能な条件>

## 参照
- <spec / ADR / 出典へのリンク>
```

## 状態

作業状態は frontmatter の **`state`** に書く。OKF の `status`（文書のライフサイクル）とは別物であり、backlog 項目では `status` を省略する（＝`stable`）。

| state | 意味 |
| --- | --- |
| `todo` | 未着手 |
| `doing` | 着手中（同時に `doing` にする項目は原則 1 つ） |
| `blocked` | 依存・未決事項で停止中。理由を本文に書く |
| `done` | 完了条件をすべて満たした |
| `dropped` | 取りやめ。理由を本文に書く |

- 節（`目的`・`範囲`・`対象外`・`完了条件`・`参照`。この順。間に別の節を足してよい）と `state` の値、`done` の項目の完了条件が埋まっていることは、`okf_check.py` が検査する（[documentation.md](documentation.md#検査)）。
- `depends_on` の項目が `done` になるまで着手してはならない（仕様の調査など、依存しない部分を先行する場合は範囲を分割した新項目を作る）。

## 完了の定義（Definition of Done）

すべての項目に共通して、次を満たしたときに `done` とする。

- 完了条件のチェックボックスがすべて埋まっている。
- 関係する spec・ADR・[traceability.md](../spec/traceability.md) が更新されている。
- Lean を変更した場合、`lake build` と `lake test` が成功し、`sorry`・新規 `axiom`・証明中の `native_decide`・`bv_decide` が無い。
- 基本原則（[ADR c336](../decision/c336-foundational-principles.md)）を満たす。項目が扱う機能について、次をすべて満たす。
  - R 課題・W 課題と、関係する `Spec` 自身の課題（SPEC-NNN）が証明されている。R 課題は束（`Machine.Preserves`。同じ課題 ID。`InitSurj`・`Pinned`・出力のみの差異の `StateSafe` などを成分に持つ）を、W 課題は両向きの例を含む（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)）。
  - 機能の R 課題の主定理と束が、トップレベルの主定理（`Abstraction.refines`・`Abstraction.preserves`・`Refinement.refines`・`Refinement.preserves`）の並置に入っている（`Spec.machine`・`SourceModel.machine`・`TargetModel.machine` に機能の機械を加える。[ADR 91be](../decision/91be-top-level-preserves-refines-abstracts.md)）。
  - `lake exe obligation-check` と port-lang の `scripts/ci/check_obligations.py` が、その機能について警告なしで通る（TR-G・TR-N）。
  - 両端の決定論的な手段がすべて通る（`source-model/` ベクタと Java オラクルの照合、SQL の差分実行、`target-model/` ベクタ、写しの再生成、Verus・Kani）。
  - 追跡の検査 TR-*（TR-D を含む）が失敗扱いで通る。段階導入は側ごとに判定する（`trace/features.json` の `source`・`target`）。移植元側の項目を `done` にする時点で、その機能の移植元側の検査（TR-S1・TR-P・TR-D・TR-K）が失敗扱いで通っていなければならない。以後は CI がそれを保ち、後の機能の取り込みで実装済みの範囲が壊れれば失敗する。未対応の一覧は `trace check --verbose --feature <機能>` で出す。
  - 決定論的な手段の届かない部分が [assurance.md](../spec/assurance.md) に載っている。
  - 項目の範囲が一部だけの場合は、残りを扱う項目が存在する。
- 新しい `TODO(spec)` を残した場合、それを扱う backlog 項目が存在する。
- 変更を `git commit` した（push は自分で作ったブランチに限る。[version-control.md](version-control.md)）。
