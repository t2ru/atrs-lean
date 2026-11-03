---
type: Backlog Item
title: "検査の層を分け、長い段を関係する変更があったときだけ実行する"
description: "コミット前と PR の CI を、常時の段と変更に関係する長い段だけにし（mise run check）、全数（mise run ci）を main への push・週次・節目に実行する。範囲の宣言と選択の道具、lake test の総当たりの分割、CI の起動の整理、実行の時点の規約を置く。"
tags: [backlog, ci, tooling]
id: "7d087470-a80e-4b03-8220-4f70a9b1e685"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:30:00+09:00
---

# 検査の層を分け、長い段を関係する変更があったときだけ実行する

## 目的

コミット前の確認と CI が、変更の内容によらず全段（約 9 分）を実行していた。長い段を関係する変更があったときだけ実行し、全数を実行する時点を規則で決めて、基本原則 1 を弱めずに検査を短くする。

## 範囲

- `mise.toml`: 常時の段 `ci:fast`、全数 `ci`、選択実行 `check`・`check:list`、`lean:test-long`、`static:check-scopes`。
- `tools/ci/check-scopes.toml`（変更時の段の範囲と、全数にする変更）と `tools/ci/select_checks.py`（選択・整合の検査・自己テスト）。
- `lean/`: `lake test` から 20 秒以上かかる節（シードの DB を使う SourceModel の照合・空席照会の SQL の結果・暦日の全日・double の総当たり）を、実行ファイル `long-tests`（`Tests.Long`・`Tests.LongMain`・`Tests.DateExhaustive`）に分け、`lake test` の各節に経過時間を表示する（`Tests.Report`）。layout-check の組は増やさない。`trace/checks.json` で `lean:test` を実行する検査に `lean:test-long` を足す。
- `.github/workflows/lean.yml`: PR は選択実行、main への push・週次・手動は全数。全ブランチの push をやめ、PR の古い実行を取り消す。
- 規約 [checks.md](../rules/checks.md) を置き、[version-control.md](../rules/version-control.md)・[backlog.md](../rules/backlog.md)・[README.md](../rules/README.md)・[atrs-porting.md](../rules/atrs-porting.md)・`AGENTS.md`・[assurance.md](../spec/assurance.md)・[`Spec.Model`](../../lean/Spec/Model.lean) を改める（[ADR 9c1c](../decision/9c1c-check-tiers-and-change-scoped-long-checks.md)）。

## 対象外

- 選択の道具のスキルへの移動（他のリポジトリで要るときに行う）。
- git のフック（コミット前の確認は規約で求め、フックは入れない）。
- 常時の段の中の短縮（`trace:build` のキャッシュの効き方など）。

## 完了条件

- [x] `select_checks.py --self-test` と `check-config` が通る（`static:self-test`・`static:check-scopes`）。
- [x] 変更の例で選択が期待どおりになる（文書だけ → 長い段なし、`lean/Spec/Prim/Date.lean` → `lean:test-long`・`lean:layout-check`、`tools/origin-run/` → `ci:java-origin-run`、`mise.toml` → 全数）。
- [x] PR の CI が `mise run check` で起動し、ステップサマリに選択の結果が出る（この PR は層の設定を変えるので全数に切り替わった。run 41310667003）。
- [x] `lean:test-long` を含む全数が CI で通り、`[mem]` の最大が runner の上限より十分下にあり、`lake test` が長い節の分だけ短くなる（全数 531 s で通過。メモリの最大 6,274 / 7,931 MB。`lake test` 384 s → 約 3 s、`long-tests` 約 216 s）。
- [x] `docs:ids`・`docs:okf` が通る。

## 参照

- [ADR 9c1c](../decision/9c1c-check-tiers-and-change-scoped-long-checks.md)、[ADR 44a0](../decision/44a0-mise-tasks-and-uv-for-tools.md)
- [rules/checks.md](../rules/checks.md)
