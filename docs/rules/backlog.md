---
type: Guideline
title: "バックログ規約"
description: "バックログ項目の形式・状態・完了の定義。"
tags: [rules, backlog]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T08:20:00+09:00
---

# バックログ規約

## ファイル

```
docs/backlog/NNNN-<slug>.md
```

- 命名規則は ADR と同じ（4 桁連番、英小文字スラッグ、改名・削除しない）。
- 索引 [docs/backlog/README.md](../backlog/README.md) の表と [docs/index.md](../index.md) を常に最新に保つ。

## 項目の形式

```markdown
---
type: Backlog Item
title: "<題名>"
description: "<1 文の要約>"
tags: [backlog, <分野>]
id: "NNNN"
state: todo
depends_on: ["NNNN", ...]
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

- `depends_on` の項目が `done` になるまで着手してはならない（仕様の調査など、依存しない部分を先行する場合は範囲を分割した新項目を作る）。

## 完了の定義（Definition of Done）

すべての項目に共通して、次を満たしたときに `done` とする。

- 完了条件のチェックボックスがすべて埋まっている。
- 関係する spec・ADR・[traceability.md](../spec/traceability.md) が更新されている。
- Lean を変更した場合、`lake build` と `lake test` が成功し、`sorry`・新規 `axiom`・証明中の `native_decide`・`bv_decide` が無い。
- 基本原則（[ADR 0033](../decision/0033-foundational-principles.md)）を満たす。項目が扱う機能について、次をすべて満たす。
  - R 課題・W 課題と、関係する `Spec` 自身の課題（SPEC-NNN）が証明されている。
  - 両端の決定論的な手段がすべて通る（`source-model/` ベクタと Java オラクルの照合、SQL の差分実行、`target-model/` ベクタ、写しの再生成、Verus・Kani）。
  - 追跡の検査 TR-*（TR-D を含む）が失敗扱いで通る。
  - 決定論的な手段の届かない部分が [assurance.md](../spec/assurance.md) に載っている。
  - 項目の範囲が一部だけの場合は、残りを扱う項目が存在する。
- 新しい `TODO(spec)` を残した場合、それを扱う backlog 項目が存在する。
- 変更を `git commit` した（push は自分で作ったブランチに限る。[version-control.md](version-control.md)）。
