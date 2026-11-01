---
type: Architecture Decision Record
title: "検査を常時の段・変更時の段・全数に分け、長い段は関係する変更があったときだけ実行する"
description: "コミット前と PR の CI では、常時の段（ci:fast）と、変更に関係する変更時の段だけを実行する（mise run check）。CI で 20 秒以上かかる段は変更時の段とし、範囲（パスの glob と Lean の import の閉包）を tools/ci/check-scopes.toml に宣言する。main への push・週次・手動・backlog の完了・版上げでは全数（mise run ci）を実行する。lake test から 20 秒以上かかる節（シードの DB を使う SourceModel の照合と空席照会の SQL の結果、暦日の全日、double の総当たり）を実行ファイル long-tests に分け、CI の push と pull_request の二重起動をやめる。"
tags: [adr, ci, tooling, verification]
id: "9c1cca9f-c289-4ed6-bef0-131472eaa46d"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:30:00+09:00
---

# 検査を常時の段・変更時の段・全数に分け、長い段は関係する変更があったときだけ実行する

## Context and Problem Statement

[ADR 44a0](44a0-mise-tasks-and-uv-for-tools.md) で、検査の段を `mise.toml` のタスクにし、一括検査を `mise run ci` にした。コミット前の確認（[version-control.md](../rules/version-control.md#コミット前の確認)）も CI も、変更の内容によらず `mise run ci` の全段を実行していた。
CI の 1 回は約 11 分で、そのうち `mise run ci` が 554 秒だった（2026-11-01 の run）。主な段は次のとおりである。

| 段 | 時間 | 中身 |
| --- | --- | --- |
| `lean:test` | 384 s | 節ごとに測ると、シードの DB を使う SourceModel の照合が大半を占める（`source-model/flight-search` 176 s、空席照会の SQL の結果 138 s、`shared/master-data` 30 s、`shared/flight-search` 15 s）。暦日の全日と double の総当たりは合わせて約 20 s、残りの適合ベクタは 1 s 未満 |
| `ci:java-origin-run` | 101 s | Java の原典実行（原典のビルドと、ドメイン層・HTTP レベルの実行） |
| `assets:trace-test` | 87 s | スキルの追跡属性の道具のフィクスチャ |
| `lean:layout-check` | 41 s | ATRS の Lean の全宣言の配置 |
| `trace:build`・`trace:self-test` | 41 s・40 s | 追跡の CLI（Rust）のビルドと自己テスト |
| `ci:pg-table`・`ci:master-sql`・`assets:layout-check` | 23 s・13 s・13 s | PostgreSQL との突き合わせ表、SQL の結果、assets の宣言の配置 |

長い段の多くは、文書だけの変更や、関係の無い Lean の変更では結果が変わらない。また CI は `push`（全ブランチ）と `pull_request` の両方で起動しており、PR のブランチでは同じコミットを 2 回検査していた。
コミット前と PR の検査を短くしつつ、基本原則 1（[ADR c336](c336-foundational-principles.md)。両端の一致を決定論的な検証で確かめる）を弱めない、実行の時点の規則が要る。

## Decision Drivers

* コミット前と PR の検査を、変更の内容に見合った長さにすること
* 飛ばした段の入力が、最後に全数が通った時点から変わっていないと言えること（範囲を宣言し、検査で腐らせない）
* 範囲の漏れがあっても、全数が定期的に走って検出されること
* 段の追加で、分類の漏れが起きないこと
* 何を実行し何を飛ばしたかが、CI の記録に残ること

## Considered Options

* 3 層（常時の段・変更時の段・全数）に分け、変更時の段の範囲を宣言して、道具で選ぶ
* mise の `sources`・`outputs`（更新時刻）で段を飛ばす
* CI の `paths` フィルタ（ワークフローの単位）で分ける
* 現状のまま全段を実行し、CI の並列化（ジョブの分割）だけで短くする

## Decision Outcome

Chosen option: "3 層（常時の段・変更時の段・全数）に分け、変更時の段の範囲を宣言して、道具で選ぶ", because 範囲の宣言を 1 か所に置いて検査でき、コミット前と CI で同じ選び方をし、全数の時点を規則で決められるため。mise の更新時刻はチェックアウトの直後には使えず、ワークフローの `paths` は段の単位で選べず、ジョブの分割は検査の量を減らさない。

### 構成

* 層（規則は [checks.md](../rules/checks.md)）
  * 常時の段: mise の `ci:fast`。どの変更でも実行する短い段（文書・静的検査・Lean のビルド・`lake test`・公理・義務・trace-dump・追跡の検査など）。
  * 変更時の段: CI で 20 秒以上かかる段。`lean:test-long`・`lean:layout-check`・`assets:trace-test`・`assets:layout-check`・`trace:self-test`・`ci:pg-table`・`ci:master-sql`・`ci:java-origin-run`。
  * 全数: mise の `ci`（`ci:fast` とすべての変更時の段）。
* 範囲: `tools/ci/check-scopes.toml`。変更時の段ごとに、パスの glob（`paths`）と Lean のモジュール（`lean_roots`。`import` をたどった閉包のファイル）を書く。`[full]` に当たる変更（検査の設定・ワークフロー・道具の版・上流の版）は全数にする。
* 選択: `tools/ci/select_checks.py`（標準ライブラリだけ）。変更は `git diff HEAD` と未追跡のファイル、`CHECK_BASE` があれば merge-base からの変更も加える。`CHECK_FULL=1`・git の失敗でも全数にする。`mise run check` が `mise run ci:fast ::: <選んだ段>…` を起動し、`GITHUB_STEP_SUMMARY` に実行した段と飛ばした段と理由を書く。
* 整合: `select_checks.py check-config`（mise の `static:check-scopes`。常時の段）が、`ci` の depends が `ci:fast` と範囲を持つ段とに重ならずに分かれること、すべての glob とモジュールが実在のファイルに当たることを確かめる。
* `lake test` の分割: 20 秒以上かかる節を、実行ファイル `long-tests`（本体 `lean/Tests/Long.lean`、入口 `Tests.LongMain`。mise の `lean:test-long`）に移した。移した節は、暦日の全日の検査、double の総当たり、シードの DB を使う SourceModel の適合ベクタ（`shared/master-data`・`shared/flight-search`・`source-model/flight-search`）、空席照会の SQL の結果の照合である。`lake test` の実行ファイルは、これらのモジュールを import しない。`lake test` の各節は経過時間を表示し、層の分類の根拠にする。`trace/checks.json` で `lean:test` を実行する検査は、`lean:test-long` も実行する（`trace rehash` の意味を変えない）。
* layout-check のメモリ: `lake exe layout-check` は、モジュールの組ごとに環境を読み込んで解放しない。組を 1 つ足しただけで、CI の runner（8 GB）のメモリが尽きた（使用量が 1.2 GB から 40 秒で 7.4 GB になり、runner が止められた）。このため組は増やさず、`main` を持たない本体（`Tests.Long`）を既存の組に入れ、`main` だけの入口は組に入れない。
* CI: `pull_request` は選択実行（`CHECK_BASE=origin/<base>`）。`push`（main だけ）・週次の `schedule`・`workflow_dispatch` は全数。全ブランチの `push` をやめ、PR の古い実行は取り消す（`concurrency`）。
* 選択の道具はアプリに依存しないが、移植の方法でも文書の管理でもないため、当面 ATRS の `tools/ci/` に置く。他のリポジトリで要るときにスキルへ移す。

### Consequences

* Good, because 文書だけの PR は長い段を実行せず、Lean の PR も関係する長い段だけを実行する。PR の二重起動も無くなる。
* Good, because 測ると（この ADR の PR の全数の実行。run 41310667003）、`lake test` は 384 s から約 3 s になった。分けた `long-tests` は約 216 s（シードの DB を使う適合ベクタ 131 s、空席照会の SQL 78 s）である。証明だけの変更（`lean/Abstraction/**`）では、`long-tests`・原典実行・`assets:trace-test` などの長い段を飛ばす。runner のメモリの最大は 6.3 GB（上限 7.9 GB）だった。
* Good, because 範囲が宣言され、改名や段の追加で腐らないことを常時の段が確かめる。
* Good, because 飛ばした段と理由が CI の記録に残る。
* Bad, because 範囲の宣言に漏れがあると、PR では検出されず、main への push か週次の全数まで遅れる。限界として [assurance.md](../spec/assurance.md#追跡の道具) に書いた。
* Bad, because 全数が main で落ちたときは、取り込んだ後に直すことになる（規則で最優先とする）。
* Bad, because 空席照会とマスタの SourceModel の照合は遅いまま（約 6 分）で、関係する変更のたびに実行される。照合そのものを速くすることは別の作業とする。

### Confirmation

* `select_checks.py --self-test` と `check-config` が通る（常時の段）。
* PR の CI のステップサマリに、実行した段と飛ばした段が出る。
* main への push と `workflow_dispatch` で、`mise run ci`（全数）が通る。

## Pros and Cons of the Options

### mise の `sources`・`outputs`（更新時刻）で段を飛ばす

* Good, because mise の機能だけで済む。
* Bad, because チェックアウトの直後は全ファイルの更新時刻が新しく、CI では効かない。ローカルでも、前回の実行の記録に依存し、何を飛ばしたかが残らない。

### CI の `paths` フィルタ（ワークフローの単位）で分ける

* Good, because GitHub Actions の機能だけで済む。
* Bad, because ワークフローの単位でしか選べず、コミット前の確認には使えない。範囲がワークフローの YAML に散らばる。

### 現状のまま全段を実行し、CI の並列化（ジョブの分割）だけで短くする

* Good, because 飛ばす段が無い。
* Bad, because 検査の量は減らず、Lake のビルドの共有と PostgreSQL の直列化のために、ジョブの分割の効果も小さい。コミット前の確認は短くならない。

## More Information

* 規則: [checks.md](../rules/checks.md)（実行の時点）、[version-control.md](../rules/version-control.md#コミット前の確認)、[backlog.md](../rules/backlog.md#完了の定義definition-of-done)
* 作業: [backlog 7d08](../backlog/7d08-change-scoped-checks.md)
* 補う記録: [ADR 44a0](44a0-mise-tasks-and-uv-for-tools.md)（タスクと一括検査 `ci`）
