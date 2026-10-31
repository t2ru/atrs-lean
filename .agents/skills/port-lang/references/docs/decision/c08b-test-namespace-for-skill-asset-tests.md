---
type: Architecture Decision Record
title: "スキルの assets の Lean の検査を名前空間 Test.<ライブラリ> にまとめる"
description: "assets/lean の検査（LangSemanticsTest・MachineTest・ConformanceKitTest・TraceTest）を、トップレベルの Test の下の Test.LangSemantics・Test.Machine・Test.ConformanceKit・Test.Trace に移し、ディレクトリも Test/ にまとめる。Lake のライブラリは Test の 1 つにし、静的検査は Test を Tests の層として扱う。"
tags: [adr, skill, lean, tests]
id: "c08b0db1-bb34-4db9-a428-547e40bf25a1"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T22:00:00+09:00
---

# スキルの assets の Lean の検査を名前空間 Test.<ライブラリ> にまとめる

## Context and Problem Statement

`assets/lean/` には、4 つのライブラリ（`LangSemantics`・`Machine`・`ConformanceKit`・`Trace`）と、その検査（`LangSemanticsTest`・`MachineTest`・`ConformanceKitTest`・`TraceTest`）が、同じ階層に並んでいた。
検査はライブラリごとに、ディレクトリと集約のファイル（`XxxTest/`・`XxxTest.lean`）を持つ。そのため、ファイルの一覧の半分を検査が占め、ライブラリの本体が見つけにくかった。
[ADR 6edf](6edf-lean-package-under-skill-assets-lean.md) は、パッケージを `assets/lean/` に移したときに、モジュール名を変えないとした。この ADR は、その後の名前の整理である。

## Decision Drivers

* `assets/lean/` の一覧で、ライブラリの本体と検査を見分けられること
* ファイルパスと名前空間を一致させる規則（[lean/rules.md](../lean/rules.md)）を保つこと
* ライブラリの本体の名前（`Machine.Refines` など）と、検査の名前が衝突しないこと
* 検査の一部だけを実行できること（`trace/checks.json` の Java・PostgreSQL の突き合わせ）

## Considered Options

* 名前空間とディレクトリ
  * トップレベルの `Test` の下に置く（`Test.LangSemantics`・`Test.Machine`・`Test.ConformanceKit`・`Test.Trace`。ディレクトリは `Test/<ライブラリ>/`）
  * ディレクトリだけ `Test/` にまとめ、名前空間は `XxxTest` のままにする
  * そのままにする
* Lake のライブラリ
  * `Test` の 1 つにし、一部の実行はモジュールの指定（`lake build +Test.LangSemantics`）で行う
  * ライブラリごとに 4 つ残す

## Decision Outcome

Chosen option: "トップレベルの `Test` の下に置き、Lake のライブラリは `Test` の 1 つにする", because 一覧が本体と `Test/` に分かれ、パスと名前空間の一致も保てるため。ディレクトリだけ移すと、パスと名前空間がずれる。Lake のライブラリを 4 つ残しても、名前（`Test.X` のライブラリ名）が増えるだけで、モジュールの指定で同じことができる。

* モジュールと名前空間の `XxxTest` を `Test.Xxx` に改める。名前の比較（`trace-test` のフィクスチャの接頭辞 `Test.Trace.Fixture`・`Test.Trace.ObFix`、`#guard_msgs` の期待するメッセージ、`#print axioms` の名前）もあわせて改める。
* `Test.lean` が 4 つの集約（`Test.LangSemantics` など）を取り込む。`trace-test` の入口は `Test.Trace.Main` とし、ライブラリには含めない。
* 生成器（`Test/LangSemantics/jvm/JavaTable.java`・`Test/LangSemantics/pg/pg_table.py`）の出力の見出しと名前空間も改め、生成物と一致させる。
* `scripts/ci/check_lean.py` は、トップレベルの `Test` を `Tests` の層として扱う（`native_decide`・`Float` を許す）。違反例の置き場所も `scripts/ci/fixtures/lean/Test/Machine/` に改める。
* 適用先のテスト（ATRS の `Tests` など）の名前は変えない。適用先のパッケージに `Test.lean` を置くと、このパッケージの `Test` と衝突するため、適用先は `Test` を使わない。

### Consequences

* Good, because `assets/lean/` の一覧が、4 つのライブラリと `Test/` に分かれる
* Good, because パスと名前空間の一致が保たれる
* Bad, because `namespace Test.Machine.…` の中で `open Machine` と書くと、Lean は `Test.Machine` を開き、本体の `Machine` を開かない（警告 Ambiguous namespace）。検査の名前空間の中では `open _root_.Machine`・`open _root_.Trace` と書く。`open` を `namespace` の外に置いてもよい

### Confirmation

* `assets/lean/` で `lake build` と `lake exe trace-test` が通る。
* `scripts/ci/check_lean.py --self-test` と `check_lean.py` が通る。
* `scripts/ci/jvm_table.sh`・`pg_table.sh` が、生成物と生成器の出力の一致を確かめる。

## More Information

* 前の決定: [ADR 6edf](6edf-lean-package-under-skill-assets-lean.md)（パッケージの置き場所。モジュール名は変えなかった）
* 来歴: 適用先 ATRS のオーナーの依頼（ファイルの一覧が見にくい）。
