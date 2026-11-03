---
type: Backlog Item
title: "スキルの Lean のデータ型を、不正な状態を表現できない型にする"
description: "ADR bf1b に従い、Trace（ギャップの登録簿・追跡属性・道具の内部の記録）、Machine（Preserves の条件付きの成分）、LangSemantics・ConformanceKit（値の型）の妥当性の条件を型に移す。"
tags: [backlog, skill, lean, types, misu]
id: "d3fd1f35-7c8a-4218-a2a8-c7f617541769"
state: done
depends_on: []
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T14:00:00+09:00
---

# スキルの Lean のデータ型を、不正な状態を表現できない型にする

## 目的

[ADR bf1b](../decision/bf1b-make-illegal-states-unrepresentable.md) の規則を、スキルの assets の Lean に課す。値の妥当性の条件を、docstring・付けた時点の検査から型に移す。

## 範囲

- **S1 `Trace.Gap`**
  - 型付きの ID（`GapId`・`ObligationId`・`BacklogId`）と、空でない文字列・列を置く。
  - 本体を種類ごとの和型にし、証明の状態を種類ごとの型に分ける。
  - `Gap.problems` を、型で表せないものだけに減らす。
  - `trace-dump` の `gaps` の JSON の形は変えない。
- **S2 追跡属性と `Trace` の内部の型**
  - 属性の引数を、付けた時点で型付きの値に解析する。`@[deviation]` は引数を 1 つだけ受ける。
  - `Trace.Dump` の層を列挙にする。`Trace.Layout` の違反・例外を和型にする。`Trace.Obligation` の内部の記録の旗・位置の組を、和型と名前付きの `structure` にする。
- **S3 `Machine`**（棚卸しの結果、型は変えない。下の「S3 の判断」）
  - `Preserves`・`Abstracts` の `ch : Option Choice` と、それで守った成分を見直す。
- **S4 `LangSemantics`・`ConformanceKit`**
  - `JDouble` の有限値を正規形だけにし、`Rat'` の分母を正にする。
  - `JLocalDate`・`JLocalTime`・`JLocalDateTime`・`JHashMap`・`SequenceDef`・`Sql.Query` の並びのキー・`DecimalFormat.Symbols`・`Java.Expr` の内部の値・`JThrow.other`・`SqlTable` に、それぞれの不変条件を持たせる。
- **S5 締め**
  - 規約（[lang/lean/rules.md](../lang/lean/rules.md)・[lang/lean/trace-attributes.md](../lang/lean/trace-attributes.md)・言語パックの `semantics.md`）を直す。
  - 型の棚卸しの手順 [guide/type-inventory.md](../guide/type-inventory.md) を置く。
  - 検査 MISU-1（`scripts/ci/check_lean.py`）と属性 `@[raw_input]` を置く。

### 進み具合

- 済み: S1（`Trace.Gap`）、S2（属性・`Trace` の内部の型）、S3（判断のみ。下）、S4 の `JLocalDate`・`JLocalTime`・`JLocalDateTime`・`JDouble`・`Rat'`・`SequenceDef`・`JHashMap`（キーの一意性 `nodup`）・`DecimalFormat.Symbols`（`Symbols.valid`）・`JThrow.other`（クラス名 `JClassName`）・SQL の並びのキー（向きとキーの組 `OrderBy`）・`Java.Expr` の内部の値（`Kind`・`Shape`、束縛の数は `Vector`）・`ConformanceKit.SqlTable`（行の幅の証明 `wf`）、S5 の検査 MISU-1 と型の棚卸しの手順。
- 残り: なし（S1〜S5 を終えた）。

### S3 の判断

型の棚卸し（[guide/type-inventory.md](../guide/type-inventory.md)）の観点 T1・T6 で見直した。

- `Preserves`・`Abstracts` は命題（証明の義務の束）で、値の型ではない。基底が `ofChoice` のときだけ要る成分は、
  `∀ c, ch = some c → …` の形で、すでに形式的に条件付けられている（`ch = some c` なら、その成分を省けない）。
- 残る対応は、`ch` が基底の形（`ofChoice`・`pure`）に合うことと、`Choice.f`・`Choice.e₀` が基底の `ofChoice` の引数と同じ式であることである。
  これは R 課題の命題の書き方（式の形）の性質で、環境の全体にわたる性質として obligation-check の G6 が照合する（ADR bf1b の規則 3）。
- `Choice`・`OutLayer` を基底の機械から作る形にすると、`Spec` の機械の書き方と G3・G6 の読み取りが変わる。G6 の照合で足りるので行わない。

## 対象外

- 機械の PRE・INV、独立な入力の間の関係、環境の全体にわたる性質の検査（ADR bf1b の規則 3）。
- 適用先の `Spec` の型（適用先の作業項目で行う）。

## 完了条件

- [x] `Trace.Gap` の不正な組み合わせが型の誤りになり、`Test/Trace/GapErrors.lean` がそれを `#guard_msgs` で確かめる。
- [x] `trace-dump` の `gaps` と属性の JSON が、変更前の適用先の出力と同じである。
- [x] `Machine.Preserves` の条件付きの成分を見直し、型を変えず obligation-check の G6 の照合で足りるとした（下の「S3 の判断」）。
- [x] `JDouble` の有限値が正規形だけを表し、assets と適用先の証明が通る。
- [x] MISU-1 が CI で動き、違反が 0 件である。
- [x] `lake build`・`lake test`（assets）、`trace-test`、`layout-check` が通る。

## 参照

- [ADR bf1b](../decision/bf1b-make-illegal-states-unrepresentable.md)
- [guide/type-inventory.md](../guide/type-inventory.md)
