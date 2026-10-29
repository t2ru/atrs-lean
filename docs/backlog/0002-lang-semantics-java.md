---
type: Backlog Item
title: "LangSemantics.Java: Java 基本型の意味論"
description: "int32・IEEE 754 binary64（必要部分）・BigDecimal 丸め・UTF-16 文字列・LocalDate を、アプリ非依存の検証可能なモデルとして実装する。"
tags: [backlog, lang-semantics, java]
id: "0002"
state: todo
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# LangSemantics.Java: Java 基本型の意味論

> 2026-10-29: スキル port-lang の assets に、LangSemantics.Java の初版（core のみ、`#guard` 検査付き、Lean 4.35.0 でビルド済み）がある（[Java.lean](../../.agents/skills/port-lang/assets/LangSemantics/Java.lean)）。本項目は、それを `lean/LangSemantics/` に取り込み、ATRS で不足する演算を **assets 側に** 追加する作業として行う。

## 目的

[Source] の運賃計算・文字列長・日付演算を証明可能に表すため。

## 範囲

- `LangSemantics.Java.Int32`（`BitVec 32`、`j32add`, `j32sub`, `j32mul`, `jdiv32`）
- `LangSemantics.Java.JDouble`（有理数＋RNE 丸め。`jd`, `jdLit`, `jdmul`, `jdsub`, `jd2i`）
- `LangSemantics.Java.BigDecimal`（`setScale(-2, UP)` と `intValue`）
- `LangSemantics.Java.String`（UTF-16 長、`trim`、`split`）
- `LangSemantics.Java.LocalDate`（`plusDays`, `isBefore`, `ChronoUnit.YEARS.between`）

## 対象外

- ATRS 固有の型・関数
- 汎用の IEEE 754（除算・平方根など原典で使わない演算）

## 完了条件

- [ ] `jdLit("0.01")` のビット表現が `0x3F847AE147AE147B` であることを証明した
- [ ] `jdmul`, `jdsub`, `jd2i` がネイティブ `Float` とビット単位で一致することを、原典の値域を覆う入力で突き合わせた
- [ ] `BigDecimal`・`String`・`LocalDate` の写した演算を、JVM の実行結果と固定した入力の表で突き合わせた
- [ ] 突き合わせた入力の範囲を [assurance.md](../spec/assurance.md) に記載した
- [ ] `jd2i(jdmul(jd(1430), jdsub(jd(1), jdmul(jd(30), jdLit("0.01")))))` が 1000 になることを確認した
- [ ] ATRS 固有モジュールを import していない

## 参照

- [ADR 0005](../decision/0005-java-primitive-semantics.md)
- [ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)
