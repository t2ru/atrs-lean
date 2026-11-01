---
type: Guideline
title: "検査の実行規約"
description: "検査を常時の段・変更時の段・全数に分け、コミット前・push 前・PR・main・定期・節目のそれぞれで実行するものを決める。長い段は関係する変更があったときだけ実行し、範囲を tools/ci/check-scopes.toml に宣言する。"
tags: [rules, ci, verification]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:30:00+09:00
---

# 検査の実行規約

検査の段は、ルートの `mise.toml` のタスクである（[ADR 44a0](../decision/44a0-mise-tasks-and-uv-for-tools.md)）。本書は、どの段をいつ実行するかを決める（[ADR 9c1c](../decision/9c1c-check-tiers-and-change-scoped-long-checks.md)）。

## 層

| 層 | タスク | 中身 |
| --- | --- | --- |
| 常時の段 | `ci:fast` | どの変更でも実行する短い段。文書（`docs:*`）、上流の版、共有入力とシード、静的検査（`static:*`。層の設定の整合 `static:check-scopes` を含む）、JVM の表、Lean のビルド・`lake test`・公理・義務・trace-dump、追跡の検査（`trace:build`・`trace:manifest`・`trace:check`・`trace:review`）、ルートの `lake setup-file` |
| 変更時の段 | `tools/ci/check-scopes.toml` の `[scopes]` | 長い段。関係する変更があったときだけ実行する。`lean:exhaustive`（暦日の全日・double の総当たり）、`lean:layout-check`、`assets:trace-test`、`assets:layout-check`、`trace:self-test`、`ci:pg-table`、`ci:master-sql`、`ci:java-origin-run` |
| 全数 | `ci` | 常時の段と、すべての変更時の段 |

選択実行 `mise run check` は、常時の段と、変更に関係する変更時の段を実行する。何を実行するかは `mise run check:list` で事前に見られる。選ぶのは `tools/ci/select_checks.py` である。

- 変更: `git diff HEAD`（索引と作業木）と未追跡のファイル。`CHECK_BASE=<rev>` を付けると、`merge-base(<rev>, HEAD)` からの変更も加える。
- 次のときは全数にする: `CHECK_FULL=1`、git が失敗した、`[full]` に当たる変更がある（`mise.toml`・層の設定と道具・ワークフロー・Lean のツールチェーンと Lake の依存・上流の版・Python の版）。

## 実行の時点

| 時点 | 実行するもの |
| --- | --- |
| 作業中 | 必要な段を個別に（`mise run lean:test` など。一覧は `mise tasks`） |
| コミット前 | `mise run check`（コミットしていない変更に関係する長い段だけを含む） |
| push・PR の作成の前 | `CHECK_BASE=origin/main mise run check`（ブランチ全体の変更。PR の CI と同じ選び方） |
| PR の CI | 自動で選択実行（`CHECK_BASE=origin/<base>`）。ステップサマリに、実行した段・飛ばした段と理由が出る |
| main への push・週次・手動（`workflow_dispatch`） | 自動で全数（`mise run ci`） |
| backlog 項目の完了・上流の版上げ・層の設定の変更 | `mise run ci`（全数）。完了の定義は [backlog.md](backlog.md#完了の定義definition-of-done) |

- PR のブランチへの push は、`pull_request` だけで検査する（`push` は main だけ。二重に起動しない）。
- main の全数が落ちたら、他の作業より先に直す（範囲の漏れが疑われるときは、範囲も直す）。
- 処理系（JDK・PostgreSQL）の無いローカルでは、それを使う段が飛ばされる（`tools/ci/skippable.sh`）。その段が選ばれた変更は、PR の CI で確かめる。

## 長い段の基準と範囲

- CI で **20 秒以上** かかる段は、変更時の段とし、`[scopes]` に範囲を書く。20 秒未満の段は `ci:fast` に入れる。時間は CI のログ（mise の `Finished in`、`lake test` の各節の `time`）で確かめる。
- 段を足すときは、`ci` の depends と、`ci:fast` か `[scopes]` のどちらか一方に入れる。`static:check-scopes` が、分類の漏れと重なりを検査する。
- 範囲は、その段の結果を変えうるファイルをすべて覆うように、保守的に書く（迷えば広く）。
  - Lean の段は、なるべく `lean_roots` で書く（入口のモジュールから `import` をたどった閉包。依存が変わっても追従する）。宣言の全体を見る段（`layout-check` など）は glob で書く。
  - 段が読むデータ・生成器・スクリプトを `paths` に書く。
  - 段を重くしている検査は、入口のモジュールを分け、その import を必要なものに絞る（`Tests.Exhaustive` が `Spec.Prim.Date` と `LangSemantics.Java` だけに依存するように）。
- すべての glob とモジュールは、実在のファイルに当たらなければならない（`static:check-scopes`）。改名したら範囲も直す。
- 範囲の漏れは PR では検出されず、全数で検出される。この限界は [assurance.md](../spec/assurance.md#追跡の道具) にある。

## 道具

```bash
mise run check                          # 選択実行（コミット前）
CHECK_BASE=origin/main mise run check   # 選択実行（push・PR の作成の前）
mise run check:list                     # 選ぶ段と理由を表示する
mise run ci                             # 全数
uv run python -I tools/ci/select_checks.py --self-test
```
