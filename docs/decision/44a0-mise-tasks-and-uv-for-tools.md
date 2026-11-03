---
type: Architecture Decision Record
title: "検査・生成を mise のタスクで実行し、Python を mise が入れる uv で実行する"
description: "一括検査 tools/ci/lean.sh を廃止し、各段をルートの mise.toml のタスクに分ける。一括検査は mise run ci とし、CI・trace/checks.json・規約もタスクを呼ぶ。mise が管理する道具は uv だけとし、Python の道具は uv run python -I で実行する（版は .python-version・pyproject.toml）。Lean は elan、Java・Rust・PostgreSQL は従来どおり。"
tags: [adr, ci, tooling, python]
id: "44a097de-86b3-4e2e-b696-a95d33333ad8"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T12:00:00+09:00
---

# 検査・生成を mise のタスクで実行し、Python を mise が入れる uv で実行する

## Context and Problem Statement

Lean 側の検査は、約 30 段の bash `tools/ci/lean.sh` で一括して実行していた。段を 1 つだけ実行する入口は無く、生成（`--check` を外した実行）の手順は各スクリプトの docstring にしか無かった。
Python の道具は、どれも `python3 -I <script>` でシステムの Python を呼んでいた。版は固定しておらず、呼び出しは lean.sh・`tools/ci/master_sql.sh`・スキルの `pg_table.sh`・`trace/checks.json`（`trace rehash` が実行する argv）・規約に散らばっていた。
検査・生成の入口をまとめ、Python の実行環境を固定したい。

## Decision Drivers

* 段を個別に、CI とローカルで同じ形で実行できること
* Python の版を宣言で固定し、手で入れなくてよいこと
* 道具の版を 1 か所で固定すること
* アプリに依存しないスキルに、ATRS の道具の選択を持ち込まないこと

## Considered Options

* mise のタスクに分け、mise が uv を入れ、Python は uv で実行する
* lean.sh を残し、Python だけ uv にする
* Makefile か just のタスクにし、uv は別に入れる

## Decision Outcome

Chosen option: "mise のタスクに分け、mise が uv を入れ、Python は uv で実行する", because タスクの定義と道具の版の固定を 1 つのファイル（`mise.toml`）で持て、CI でも `jdx/mise-action` で同じ定義を使えるため。

### 構成

* ルートの `mise.toml`
  * `[tools]` は uv だけ（版を固定）。Lean は elan（`lean-toolchain`）、Java・Rust・PostgreSQL は従来どおりとする。
  * タスクは lean.sh の各段を `<分野>:<内容>` の名前で写す（`check:upstream`・`docs:*`・`conformance:*`・`static:*`・`assets:*`・`lean:*`・`trace:*`・`workspace:setup-file`）。一括検査は `ci` で、すべてを `depends` で束ねる。生成の `conformance:gen` を足した。一覧は `mise tasks`。
  * 実際の依存は `depends`、同じ起動の中での直列化は `wait_for` で表す。lake は同じパッケージの `.lake` を同時に書かないよう `assets:*` → `lean:*` → `workspace:setup-file` の順に、PostgreSQL を使う段（CI では同じサーバ）も直列にする。
  * lean.sh が `mktemp` で受け渡していた `trace-dump`・`obligation-check` の結果は、無視済みの `lean/.lake/ci/` に置く。
  * 「終了コード 2 は処理系が無いので飛ばした」の扱いは `tools/ci/skippable.sh` が受け持つ（CI では各スクリプトが 1 を返すので失敗する）。
* Python: `.python-version`（3.13）・`pyproject.toml`（依存なし、`package = false`）・`uv.lock` を置き、`uv run python -I <script>` で実行する。道具は標準ライブラリだけを使う。スキルの側の決定は [スキルの ADR 8cb7](../../.agents/skills/spec-pivot/references/docs/decision/8cb7-run-python-tools-with-uv.md)。
* `trace/checks.json` の各段は、対応するタスク（`mise run <task>`）を呼ぶ。
* `.github/workflows/lean.yml` は mise を入れて `mise run ci` を実行する。
* `tools/ci/lean.sh` は削除する。完了済みの ADR・backlog の本文にある `tools/ci/lean.sh` は来歴として残し、`mise run ci` と読み替える。

### Consequences

* Good, because 段を `mise run lean:test` のように個別に実行でき、独立な段は並行に走る。
* Good, because Python の版が宣言で固定され、uv が無ければ取得する。
* Bad, because ローカルで mise が要る（`mise trust`・`mise install` の一手間）。
* Bad, because `trace rehash` の実行にも mise が要る。

### Confirmation

* `mise run ci` が全段通る（CI とローカル）。
* 規約・`AGENTS.md`・`trace/checks.json` に `python3 -I` と `tools/ci/lean.sh` が残っていない（完了済みの記録の本文を除く）。

## Pros and Cons of the Options

### lean.sh を残し、Python だけ uv にする

* Good, because 変更が小さい。
* Bad, because 段を個別に実行する入口が無いままで、uv の版も別に固定する必要がある。

### Makefile か just のタスクにし、uv は別に入れる

* Good, because make はどこにでもある。
* Bad, because 道具の版の固定を別の仕組みで持つことになり、段の並行と直列の指定も書きにくい。

## More Information

* 補足（2026-11-03）: mise が管理する道具に mdbook を足した（[ADR 68a6](68a6-business-spec-in-lean-module-docs-and-book.md)。仕様の本）。
* スキルの側: [スキルの ADR 8cb7](../../.agents/skills/spec-pivot/references/docs/decision/8cb7-run-python-tools-with-uv.md)
* 置き換えた一括検査を導入した記録: [backlog be49](../backlog/be49-lean-project-scaffold.md)
* 規約: [version-control.md](../rules/version-control.md#コミット前の確認)、[atrs-porting.md](../rules/atrs-porting.md)
