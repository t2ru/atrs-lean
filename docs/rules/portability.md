---
type: Guideline
title: "言語中立性（portability）規約"
description: "他言語へ同一ロジックを移植するための数値・文字列・日付・順序・副作用の制約。"
tags: [rules, portability]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 言語中立性（portability）規約

最終目標は「あらゆる言語へ同一ロジックを移植可能にすること」である。
そのため **抽象モデル [Spec]** と仕様の記述は、次の制約を満たさなければならない。
移植元モデル [Source] は Java の意味論を再現するためにこれらを破ってよいが、
その場合も演算は [ADR 0005](../decision/0005-java-primitive-semantics.md) で定義した名前付き演算として、
**どの言語でも整数演算だけでエミュレートできる形** で定義する。

## 数値

- [Spec] は **任意精度整数** の意味で定義する。実装言語の固定長整数を使う場合は、仕様に書かれた値域でオーバーフローしないことを確認しなければならない（値域は [domain-model.md](../spec/domain-model.md) に記載）。
- 浮動小数点数・10 進小数型を使ってはならない（[ADR 0006](../decision/0006-exact-integer-arithmetic-in-abstract-model.md)）。
- 除算は `floorDiv` / `ceilDiv` を明示し、被除数・除数の符号を事前条件で定める。言語既定の `/` や `%` の丸め方向に依存してはならない。
- 百分率は整数（`discountRate = 30` は 30%）で保持し、`* rate / 100` の順序と丸めを明記する。

## 文字列

- 文字列は Unicode スカラ値の列とする。長さ・添字はスカラ値単位（[ADR 0010](../decision/0010-text-length-and-character-classes.md)）。
- 文字クラスは **コードポイント範囲の集合** として定義する。正規表現の方言（`\d` や `\w` の意味、Unicode フラグ）に依存してはならない。
- 大文字小文字変換・正規化（NFC 等）・照合順序・ロケール依存の書式を使ってはならない。文字列比較は **スカラ値ごとの完全一致** のみ。
- 数値の書式化（`28,800` のような 3 桁区切り）は手順として定義する。

## 日付・時刻

- 日付はタイムゾーンを持たない暦日（先発グレゴリオ暦）。時刻は `HHmm` の 4 桁文字列または「分」単位の整数（[ADR 0009](../decision/0009-date-and-time-model.md)）。
- 「今日」「現在時刻」は暗黙に取得してはならない。必ず入力（Clock ポート）として受け取る。

## 集合・順序

- ハッシュ表・集合の反復順序に依存してはならない。出力に順序がある場合は、並び替えキーと同順位の扱いを明記する。
- データベースの `ORDER BY` が無い取得結果に依存する原典の振る舞いは、[Spec] では不変条件（例: ピーク時期は重ならない）で一意化し、[Source] では「順序未規定」として扱い、差異を [abstraction.md](../spec/abstraction.md) に記録する。

## 副作用

- 業務ロジックは純粋関数として定義する。I/O・時刻・乱数・採番・永続化はポート（[ports.md](../spec/ports.md)）経由とする（[ADR 0007](../decision/0007-functional-core-with-ports.md)）。
- エラーは値として返す（[ADR 0008](../decision/0008-errors-as-values-with-stable-codes.md)）。例外の有無や伝播規則に依存した定義を書いてはならない。

## 確認方法

- 新しい定義を書いたら、[Spec] の定義が「整数・真偽・文字列（スカラ値列）・暦日・列・レコード・直和」だけで書けていることを確認する。
- 適合テストベクタ（[ADR 0013](../decision/0013-conformance-test-vectors.md)）は JSON の基本型だけで表現できなければならない。
