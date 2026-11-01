---
type: Backlog Item
title: "スキルの文書を spec/・rules/・guide/・lang/ に分ける"
description: "references/docs の方法の文書を spec/・rules/・guide/ に、言語パックを lang/<lang>/ に移し、type・プロファイル・索引を改める。移動とリンクの張り直しの道具 scripts/docs/docmv.py を作る。"
tags: [backlog, documentation, okf, skill]
id: "97a7bd76-1909-40bb-94f6-53f9b6f9904b"
state: done
depends_on: ["a49c6bc4-0de0-4bb8-8ead-7b4d8715937c"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:20:00+09:00
---

# スキルの文書を spec/・rules/・guide/・lang/ に分ける

## 目的

方法の文書の性格（規範・規約・手引き）を、置き場所と `type` から分かるようにする（[ADR 748c](../decision/748c-skill-docs-category-directories.md)）。

## 範囲

- 道具 `scripts/docs/docmv.py`（標準ライブラリと `git`）と `--self-test`。`scripts/README.md`
- 移動: 方法の文書 11 本を `spec/`・`rules/`・`guide/` へ、`java/`・`sql/`・`rust/`・`lean/` を `lang/` へ
- 張り直し: スキル・適用先の文書のリンク、コード・設定の中のパスの言及
- `type`（`Specification`・`Guide`）、プロファイル `scripts/docs/profiles/spec-pivot.json`、[index.md](../index.md) の節、[maintenance.md](../rules/maintenance.md#バンドルの構成) の表、SKILL.md の版（0.11）

## 対象外

- 文書の内容の書き換え（パスと構成の記述を除く）
- 来歴（`log.md`・既存の意思決定記録）にある、リンクでない旧パスの書き換え
- `ids.py move` を `docmv.py` の実装で置き換えること

## 完了条件

- [x] `docmv.py --self-test` が通る
- [x] このバンドルと適用先のバンドルが `okf_check.py` と `ids.py check` を違反なしで通る
- [x] 旧パス（`references/docs/<方法の文書>.md`・`references/docs/<lang>/`）の言及が、来歴の他に残っていない

## 参照

- [ADR 748c](../decision/748c-skill-docs-category-directories.md)、[maintenance.md](../rules/maintenance.md)
