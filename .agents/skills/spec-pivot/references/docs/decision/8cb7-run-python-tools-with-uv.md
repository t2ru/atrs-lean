---
type: Architecture Decision Record
title: "スキルの Python の道具を uv で実行する"
description: "scripts/ と assets/lean の Python の道具（標準ライブラリだけ）を、システムの python3 でなく uv run python -I で実行する。スキルのシェルの道具（pg_table.sh）もそう呼び、文書の使い方もそう書く。タスクの実行器（mise など）は適用先が選び、スキルは求めない。"
tags: [adr, skill, tooling, python]
id: "8cb7a3ea-9554-475d-abe7-f2d882dfd4c7"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T12:00:00+09:00
---

# スキルの Python の道具を uv で実行する

## Context and Problem Statement

スキルの Python の道具（`scripts/ci/*.py`・`scripts/docs/*.py`・`scripts/lean/rename.py`・`assets/lean/Test/LangSemantics/pg/pg_table.py`）は、`python3 -I` でシステムの Python を呼ぶ前提で書かれていた。Python の版は、適用先の環境任せだった。
適用先 ATRS は、Python を uv で実行すると決めた（適用先 ATRS の ADR 44a0）。スキルの側の呼び出しと文書をどう書くかを決める。

## Decision Drivers

* Python の版を適用先の宣言（`.python-version`・`pyproject.toml`）で固定できること
* スキルが特定のタスクの実行器に依存しないこと
* 道具は標準ライブラリだけで動き続けること

## Considered Options

* `uv run python -I` で実行する（タスクの実行器は求めない）
* `python3 -I` のままにする
* mise のタスクを前提にする

## Decision Outcome

Chosen option: "`uv run python -I` で実行する（タスクの実行器は求めない）", because uv は適用先の `.python-version`・`pyproject.toml` に従って版を選び（無ければ取得し）、適用先に Python の設定が無くても動くため。タスクの実行器は適用先ごとに違ってよい。

* スキルのシェルの道具（`scripts/ci/pg_table.sh`）は Python を `uv run --quiet python -I` で呼ぶ。
* 文書（`SKILL.md`・`scripts/README.md`）の使い方は `uv run python -I <skill>/scripts/...` と書く。依存の列は「Python 3（uv。標準ライブラリだけ）」とする。
* `-I`（隔離モード）は続けて付ける。道具のディレクトリのファイルを読み込まないためである。

### Consequences

* Good, because 適用先が Python の版を宣言で固定できる。
* Bad, because uv が要る。

### Confirmation

* 適用先 ATRS の一括検査（`mise run ci`）で、スキルの道具の自己テストと `pg_table.sh` が通る。

## Pros and Cons of the Options

### `python3 -I` のままにする

* Good, because 何も要らない。
* Bad, because 版が環境任せで、適用先の uv の宣言とずれる。

### mise のタスクを前提にする

* Good, because 適用先 ATRS と同じ形になる。
* Bad, because アプリに依存しないスキルに、特定のタスクの実行器を持ち込む。

## More Information

* 来歴: 適用先 ATRS の ADR 44a0
* 道具の一覧: [scripts/README.md](../../../scripts/README.md)
