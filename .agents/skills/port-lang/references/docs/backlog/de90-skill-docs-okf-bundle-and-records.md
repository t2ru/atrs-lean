---
type: Backlog Item
title: "スキルの文書を OKF バンドルにし、スキルの決定と作業項目を移す"
description: "references を references/docs/ の OKF v0.2 のバンドルにし、decision/・backlog/ を設けて、適用先にあったスキルの記録を移す。ID の道具を複数の置き場所と持ち出せることの検査に対応させる。"
tags: [backlog, documentation, okf, skill]
id: "de901c3c-a586-476c-a419-faffc6093d41"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:40:00+09:00
---

# スキルの文書を OKF バンドルにし、スキルの決定と作業項目を移す

## 目的

スキルを持ち出したとき、方法の文書と一緒に、方法を決めた理由と残りの作業も持ち出せるようにする（[ADR 87b9](../decision/87b9-skill-docs-as-okf-bundle.md)）。

## 範囲

- `references/*.md` と言語パックを `references/docs/` へ移す。SKILL.md・`scripts/`・`assets/` のリンクとパスを張り直す。
- 各文書に OKF v0.2 の frontmatter を付ける。`index.md`・`log.md`・`maintenance.md`・`decision/README.md`・`backlog/README.md` を作る。
- `scripts/docs/ids.py` を改める。
  - 種類ごとに複数の置き場所を持てるようにする（`ids.kinds` の配列）。
  - 持ち出すバンドルを検査する（`ids.isolated`）。
  - 置き場所を選んで採番する（`new --dir`）。
  - 記録を移してリンクを張り直す（`move`）。
- 適用先（ATRS）にあった、純粋にスキルの記録（ADR 6 件・backlog 2 件）を移す。

## 対象外

- ATRS の部分を含む記録を分けて移すこと（後の作業）
- OKF のバンドルの一般的な検査（frontmatter の必須キー・索引との一致）を道具にすること

## 完了条件

- [x] `references/docs/` の `index.md`・`log.md` 以外の `.md` が、`type` を持つ frontmatter を持つ
- [x] `ids.py check` が通り、スキルの項目が外の項目を frontmatter やリンクで指すと失敗する
- [x] スキルと適用先の Markdown の相対リンクがすべて解決する
- [x] SKILL.md の `metadata.version` を 0.8 にした

## 参照

- [ADR 87b9](../decision/87b9-skill-docs-as-okf-bundle.md)、[maintenance.md](../maintenance.md)
