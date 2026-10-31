---
type: Backlog Item
title: "OKF バンドルとリンクの検査の道具"
description: "OKF v0.2 の適合条件、バンドルのプロファイルの規則、索引の網羅、Markdown の相対リンクと見出しアンカーを検査する道具 scripts/docs/okf_check.py を作り、このバンドルの規則をプロファイルにする。"
tags: [backlog, documentation, okf, ci, skill]
id: "a49c6bc4-0de0-4bb8-8ead-7b4d8715937c"
state: done
depends_on: ["de901c3c-a586-476c-a419-faffc6093d41"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
---

# OKF バンドルとリンクの検査の道具

## 目的

スキルと適用先の OKF のバンドルの形と、文書の間のリンクを、機械的に保つ（[ADR 330e](../decision/330e-okf-bundle-check-tool.md)）。

## 範囲

- `scripts/docs/okf_check.py`（標準ライブラリだけ）
  - YAML の部分集合のパーサ
  - OKF §11 の適合条件（F1・F2・R1・R2）
  - プロファイルの規則（K1〜K4・H1・S1）と、種類 `adr`・`backlog` の検査（A1・B1）
  - 索引の網羅と一致（I1・I2）
  - 相対リンク・見出しアンカー・`/` で始まるリンク（L1〜L3）
  - `--self-test` と違反例（`scripts/ci/fixtures/okf/`）
- このバンドルの規則 `scripts/docs/profiles/port-lang.json`
- 文書: [maintenance.md](../maintenance.md#バンドルの検査)、[traceability.md](../traceability.md#プロジェクトの設定)、`scripts/README.md`、SKILL.md の版（0.9）

## 対象外

- 適用先の CI への組み込みと、適用先の規則（適用先の作業。来歴: ATRS の backlog ddbd）
- 参照形式のリンク（`[text][label]`）と、Markdown 以外のファイルの中のリンク

## 完了条件

- [x] `okf_check.py --self-test` が、すべての符号の違反を検出し、違反の無い例を通す
- [x] このバンドルが `okf_check.py` を違反なしで通る
- [x] 部分集合で読んだ既存の frontmatter が、PyYAML で読んだ値と一致する（日付・時刻の型を除く）

## 参照

- [ADR 330e](../decision/330e-okf-bundle-check-tool.md)、[maintenance.md](../maintenance.md#バンドルの検査)
