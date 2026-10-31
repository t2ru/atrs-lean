---
type: Architecture Decision Record
title: "抽象モデルの数値は任意精度整数と明示的な丸めで定義する"
description: "[Spec] の数値は任意精度整数とし、floorDiv/ceilDiv/ceilTo で丸めを明示する。"
tags: [adr, numeric]
id: "e41d046b-519e-43c7-872c-cd4f807f8941"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 抽象モデルの数値は任意精度整数と明示的な丸めで定義する

## Context and Problem Statement

抽象モデル [Spec]（[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)）は他言語移植の第一の対象である。
金額・人数・日数・百分率をどの数値型で表し、除算と丸めをどう定義するかを決める。

## Decision Drivers

* どの言語でも同一の結果を得られること
* 業務規則（「100 円未満切上げ」「割引率 %」）を式からそのまま読めること
* Lean で証明しやすいこと

## Considered Options

* 任意精度整数（非負量は自然数）と `floorDiv` / `ceilDiv` / `ceilTo` の明示
* 10 進固定小数（`BigDecimal` 相当）
* 有理数

## Decision Outcome

Chosen option: "任意精度整数と明示的な丸め", because 全言語に存在する最小の数値型で表現でき、丸めの位置と方向が式に現れるため。

規則:

* 金額・人数・日数・百分率・積算比率は **非負整数**（Lean: `Nat`）。負になりうる中間値のみ整数（`Int`）。
* 百分率は整数で保持する（30% は `30`）。百分率の適用は `floorDiv(x * rate, 100)` のように **乗算を先に行う**。
* 丸めは名前付き関数で書く。
  * `floorDiv(a, b)`（b > 0）: 床関数による除算
  * `ceilDiv(a, b)`（a ≥ 0, b > 0）: 天井関数による除算
  * `ceilTo(a, m)` = `ceilDiv(a, m) * m`（a ≥ 0, m > 0）
* 値域（オーバーフローしないための上限）は [spec/domain-model.md](../spec/domain-model.md) に書く。固定長整数で実装する言語は、その値域で溢れないことを確認しなければならない。

### Consequences

* Good, because 浮動小数点を持ち込まないので全言語で一致する
* Good, because `omega` 等で多くの性質を自動証明できる
* Bad, because 原典（double）と一部の入力で結果が異なる。差異は [spec/abstraction.md](../spec/abstraction.md) で管理する

### Confirmation

* `Spec` 配下で `Float` が使われていないことを CI で検査する（[port-lang/lean/rules.md](../../.agents/skills/port-lang/references/docs/lean/rules.md)）。
* 適合テストベクタの数値はすべて JSON の整数である。

## Pros and Cons of the Options

### 任意精度整数

* Good, because 最小・普遍・証明容易
* Bad, because 割合を含む式は乗算と除算の順序を注意深く書く必要がある

### 10 進固定小数

* Good, because 金額計算の慣習に近い
* Bad, because 多くの言語で標準でなく、丸めモードの意味が言語・ライブラリで異なる

### 有理数

* Good, because 途中計算が正確
* Bad, because 最終的に整数へ丸める位置が曖昧になりやすく、多くの言語で標準でない

## More Information

* [spec/fare-calculation.md](../spec/fare-calculation.md)
* [port-lang/portability.md](../../.agents/skills/port-lang/references/docs/portability.md)
