---
type: Architecture Decision Record
title: "追跡属性の仕組み（Trace）をスキル port-lang の assets に移す"
description: "lean/Trace（追跡属性・trace-dump・obligation-check の本体）はアプリに依存しないので、スキル port-lang の assets/lean/Trace に移し、Lake の依存として取り込む。道具の入口（main）は ATRS の lean/Tools に残す。"
tags: [adr, lean, traceability, skill]
id: "7fe42612-f690-4ae3-abd9-173805fdaa76"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T16:30:00+09:00
---

# 追跡属性の仕組み（Trace）をスキル port-lang の assets に移す

## Context and Problem Statement

追跡属性（`@[source]`・`@[deviation]` など）と、その読み出し（`trace-dump`）・R 課題の形の判定（`obligation-check`）は、`lean/Trace/` にあった。
これらは層の名前としてスキルの標準名（`Spec`・`SourceModel`・`Abstraction` など）しか使わず、ATRS に固有の定義を持たない。
ATRS の ADR f4e1 は、移植の方法をアプリに依存しないスキルに置き、ATRS 固有の情報だけを `docs/` に置くと決めている。
`Machine`（リファインメントの枠組み）と `LangSemantics` は、すでにスキルの `assets/lean/` から Lake の依存として取り込んでいる。
`Trace` だけが ATRS の側にあり、他のアプリに方法を適用するときに写す必要があった。

## Decision Drivers

* 方法はスキルに、アプリ固有の情報は ATRS に置く（ATRS の ADR f4e1）
* 他のアプリへ移植するときに、追跡の仕組みを写さずに使える
* `trace-dump` の出力（`merkle` を含む）を変えない
* 道具の入口は、モデルを import するアプリの側にしか置けない

## Considered Options

* `Trace` のライブラリとそのテストをスキルの `assets/lean/` に移し、入口（`main`）は ATRS に残す
* 入口も含めてスキルに移し、読むモジュールを引数で受ける
* 現状のまま ATRS に置く

## Decision Outcome

採択: **`Trace` のライブラリとそのテストをスキルの `assets/lean/` に移し、入口は ATRS に残す**。

* `lean/Trace.lean`・`lean/Trace/{Attr,Dump,Obligation}.lean` を、スキルの `assets/lean/Trace{.lean,/}` に移す。`langSemantics` パッケージに `lean_lib Trace` を足す。ATRS の `lean/` は `require langSemantics` で取り込む。パッケージ名は変えない。
* 追跡属性のテスト（`Tests/TraceFixture`・`AttrErrors`・`ObligationFixture` と、`Tests/Main.lean` のうち merkle・fixture・obligation の検査）を、スキルの `assets/lean/TraceTest/` と `lake exe trace-test` に移す。ATRS の `lake test` には、適合テスト・暦日・double・SQL の検査だけを残す。
* `lean/Tools/`（`trace-dump`・`obligation-check`・`axiom-check` の `main`）は ATRS に残す。ATRS のモデルを import するためである。

入口までスキルに移す案は、実行時に任意のモジュールを読むことはできるが、Lake の実行ファイルは依存をビルド時に決めるので、ATRS のモデルをビルドする手順が別に要る。得るものが少ないので採らない。

### Consequences

* Good: `Trace` を他のアプリでもそのまま使える。`LangSemantics` も `Trace` を import できるようになる（移植元の言語の定義に `@[source "lang:…"]` を付ける余地ができる）。
* Good: `merkle` は変わらない（移動の前後で全定義の値が一致することを確かめた）。
* Neutral: `tools/ci/lean.sh` は、`assets/lean` で `lake exe trace-test` を実行する段を持つ。

### Confirmation

* スキルの `assets/lean` で `lake build`（`TraceTest` の `#guard_msgs` を含む）と `lake exe trace-test` が通る。
* `lean/` の `lake build`・`lake test` が通り、`trace-dump` の全定義の `merkle` が移動の前と一致する。
* `tools/ci/check_lean.py` が `TraceTest` をテストの層として扱う。

## More Information

* ギャップの登録簿（ATRS の ADR cc24）は、この移動の上に `Trace.Gap` として置いた。
* 作業項目: ATRS の backlog 114a
