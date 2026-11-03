---
type: Backlog Item
title: "業務仕様を Spec のモジュール文書へ移し、HTML の本を作る"
description: "docs/spec の業務仕様を lean/Spec のモジュール文書（/-! -/）へ移し、mdgen と mdbook で HTML の本を作る。参照の書き換えと、移した後の検査（リンク・アンカー・出典・参照の行き先）を整える。"
tags: [backlog, spec, documentation, lean, mdbook]
id: "c89a3bd3-e71a-45cc-bb2f-f31de6f430d9"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
---

# 業務仕様を Spec のモジュール文書へ移し、HTML の本を作る

## 目的

業務仕様の散文を Lean の定義の隣に置き、通して読める HTML の本として渡す（[ADR 68a6](../decision/68a6-business-spec-in-lean-module-docs-and-book.md)）。

## 範囲

- `docs/spec` の業務仕様 14 本を `lean/Spec` のモジュール文書へ移す（移行の道具 `tools/docs/spec_to_lean.py`・`tools/docs/spec_link_text.py`、配置表 `tools/docs/spec-to-lean.json`、対応表 `tools/docs/spec-anchors.json`）
- 参照の書き換え（`@[spec_doc]`・登録簿の `sites`・ベクタの `specRef`・原典実行の記録・Markdown のリンク）
- 本の道具（スキル spec-pivot の `scripts/book/build.py`・`assets/mdgen`）、mise のタスク `book:check`・`book:build`、CI の artifact
- 検査の拡張（okf-bundle の Lean のモジュール文書のリンク、TR-R の Lean のモジュール文書、参照の行き先）

## 対象外

- メタ情報の文書（`abstraction`・`refinement`・`assurance`・`conformance`・`traceability`）の移動
- 本の公開（GitHub Pages など）。本は CI の artifact だけとする
- 移した散文の内容の見直し（区分の表示を含め、文言は移したときのまま）

## 完了条件

- [x] 業務仕様 14 本を移し、`docs/spec` にはメタ情報だけが残っている
- [x] 移した文書への参照がリポジトリに残っていない（`tools/docs/spec-anchors.json` の対応で書き換えた）
- [x] `docs:okf`・`book:check`・TR-R が、移した散文のリンク・アンカー・参照の行き先・「出典:」を検査する
- [x] `mise run book:build` が本を作り、CI が artifact として上げる

## 結果

- 14 本を 21 の Lean のファイルへ移した（186 の見出し）。形式化していない領域と用語集は、文書だけのモジュール 6 つにした。生成するファイル（`Spec.Seed`）には散文を置かず、シードデータの節は `Spec.MasterData` に置いた。
- 既存の 1 行の節の印（`/-! ## 列挙 -/` など）は、同じ題の節を移した位置で置き換えた。
- 本の見出しの id（mdbook）が、`@[spec_doc]`・`specRef` の行き先のアンカー（GitHub の規則）と一致することを、作った HTML で確かめた。

## 参照

- [ADR 68a6](../decision/68a6-business-spec-in-lean-module-docs-and-book.md)、[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)、[ADR 44a0](../decision/44a0-mise-tasks-and-uv-for-tools.md)
- スキル spec-pivot の [ADR c634](../../.agents/skills/spec-pivot/references/docs/decision/c634-spec-prose-in-lean-module-docs-and-book.md)、スキル okf-bundle の [ADR 75c9](../../.agents/skills/okf-bundle/references/docs/decision/75c9-check-links-in-lean-module-docs.md)
