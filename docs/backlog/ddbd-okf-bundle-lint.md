---
type: Backlog Item
title: "OKF バンドルとリンクの検査"
description: "docs/ が OKF v0.2 に適合し、相対リンクとアンカーが切れていないことを CI で検査する。"
tags: [backlog, docs, okf, ci]
id: "ddbd8fec-9d87-4ba1-a2bf-58d0f159ae50"
state: done
depends_on: ["be4969d4-478c-47a9-8fd9-b8cf31202bc8", "a49c6bc4-0de0-4bb8-8ead-7b4d8715937c"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
---

# OKF バンドルとリンクの検査

## 目的

文書の形式と索引の整合を機械的に保つ。

## 範囲

- frontmatter の YAML 解析と `type` の検査（OKF §11）
- `docs/index.md` が全文書を列挙しているかの検査
- 相対リンクと見出しアンカーの検査
- ADR の必須節の検査

## 対象外

- なし

## 完了条件

- [x] CI で検査が走り、違反を検出できることを確認した

## 結果

- 道具はアプリに依存しないので、スキルに `scripts/docs/okf_check.py` として置いた（[スキルの backlog a49c](../../.agents/skills/port-lang/references/docs/backlog/a49c-okf-bundle-check-tool.md)、[スキルの ADR 330e](../../.agents/skills/port-lang/references/docs/decision/330e-okf-bundle-check-tool.md)）。
- ATRS の規則を `trace/project.json` の `okf` に置き、`tools/ci/lean.sh` から `--self-test` と検査を実行するようにした（[ADR 920d](../decision/920d-docs-bundle-check-in-ci.md)）。範囲の 4 項目に加えて、backlog の必須節・状態、`index.md`・`log.md` の形、スキルのバンドルも検査する。
- 違反を検出できることは、自己テストの違反例（スキルの `scripts/ci/fixtures/okf/violations`。すべての符号）で確かめた。
- 導入時に見つかった既存の違反 5 件（`rules/README.md` の `type`、索引の説明 2 件、backlog の `対象外` の節 2 件）を直した。リンクとアンカー（アンカー付きのリンク 370 件余り）に切れは無かった。

## 参照

- [ADR a0f1](../decision/a0f1-documentation-format-okf-v0-2.md)、[ADR 920d](../decision/920d-docs-bundle-check-in-ci.md)
- [rules/documentation.md](../rules/documentation.md#okf-v02)
