---
type: Backlog Item
title: "アプリに依存しない道具・Lean のライブラリ・方法をスキルへ移す"
description: "tools/ の汎用の道具をスキルの scripts/ へ、Abstraction・Tests の汎用の Lean コードをスキルの assets へ移し、ATRS 固有の値を trace/project.json に集める。汎用の方法を文書でもスキルへ移し、スキルに紛れた ATRS 固有の記述を外す。"
tags: [backlog, skill, tooling, lean]
id: "38fb13cc-95c9-4e28-9758-7d94f97dcc39"
state: done
depends_on: ["114a8bdd-9aac-40c9-a364-048a59fa6224"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:30:00+09:00
---

# アプリに依存しない道具・Lean のライブラリ・方法をスキルへ移す

## 目的

[ADR edc8](../decision/edc8-skill-scripts-and-generic-lean-libraries.md) のとおり、アプリに依存しない要素をスキルへ移す。
他のアプリへ移植するときに、写さずに使えるようにするためである。

## 範囲

- 道具
  - `tools/trace`・`check_lean.py`・`check_obligations.py`・`check_upstream.py`・`with_postgres.sh`・`jvm_table.sh`・`pg_table.sh`・`ids.py` → スキルの `scripts/`
  - ATRS 固有の値 → `trace/project.json`
- Lean
  - `Machine.Kernel`
  - `LangSemantics.Core`（新設）
  - `LangSemantics.Sql.QueryLemmas`
  - `LangSemantics.Java`（`ResultLemmas`・`HashMapLemmas`・`DoubleCompare`）
  - `ConformanceKit`（新設）と `ConformanceKitTest`
  - obligation-check の G7 の拡張
- 文書
  - スキル: SKILL.md（版 0.6）、`scripts/README.md`、traceability・spec-documents・architecture・verification・conformance・upgrade・workflow・lean/rules・lean/trace-attributes・言語パック（java/sql/rust）
  - ATRS: AGENTS.md・atrs-porting・docs/spec の道具の記述・ADR edc8・index・log

## 対象外

- `lean/Tools/*.lean`（道具の入口）。規則どおり ATRS に残す。
- `Spec` の基本演算、フレームワークのモデル、SQL の列の等号 `eqText`・`eqInt`。理由は ADR edc8 にある。

## 完了条件

- [x] `tools/ci/lean.sh` が全段通る（JVM・PostgreSQL との突き合わせを含む）
- [x] 移動の前後で、次が同じである
  - `trace check` の誤り・警告の一覧
  - `check_obligations.py` の出力
  - `obligation-check` の R 課題の判定
  - `lake test` の検査の一覧
- [x] merkle が変わった定義が、移した補題を参照する `Abstraction` の定義だけである（`@[source]` の再検査が要らない）
- [x] `ConformanceKitTest`・`TraceTest`（`Machine.undefOrEq` の正例・違反例）・`check_lean.py --self-test`（`LangSemantics.Core` の依存）が通る
- [x] スキルの中に ATRS 固有の語（`atrs`・`ATRS`・ATRS の ADR の ID）が残っていない

## 参照

- [ADR edc8](../decision/edc8-skill-scripts-and-generic-lean-libraries.md)
- [ADR f4e1](../decision/f4e1-extract-porting-method-as-agent-skill.md)
- [backlog 114a](114a-gap-attributes-and-trace-in-skill.md)
