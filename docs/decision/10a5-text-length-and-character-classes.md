---
type: Architecture Decision Record
title: "文字列長はスカラ値単位とし、文字クラスはコードポイント範囲で定義する"
description: "[Spec] の文字列長は Unicode スカラ値数、[Source] は UTF-16 単位とし、全角・半角・カナ等をコードポイント範囲で定義する。"
tags: [adr, text, validation]
id: "10a5a064-d7b8-4607-ae9a-ea41aacd46f8"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 文字列長はスカラ値単位とし、文字クラスはコードポイント範囲で定義する

## Context and Problem Statement

原典の入力検証は Java 正規表現（`@Pattern`）と `@Size`（`String.length()`、UTF-16 単位）で行われる。

| 制約 | 原典の定義 |
| --- | --- |
| `@FullWidth` | `^[^ -~｡-ﾟ]*$`（U+0020–U+007E と U+FF61–U+FF9F を含まない。空文字可） |
| `@FullWidthKatakana` | `^[゠-ヿ]+$`（1 文字以上） |
| `@HalfWidth` | `^[ -~]+$`（1 文字以上） |
| `@HalfWidthNumber` | `^[0-9]+$`（1 文字以上） |
| `@FixedLength(n)` | 長さがちょうど n |

正規表現の方言と文字列長の単位は言語ごとに異なるため、言語中立な定義が必要である。

## Decision Drivers

* 正規表現エンジンに依存しないこと
* [Source] で原典の長さ判定（補助文字は 2 と数える）を再現できること
* 文字クラスの境界を曖昧さなく書けること

## Considered Options

* [Spec] はスカラ値単位、[Source] は UTF-16 単位。文字クラスはコードポイント範囲の集合
* 両モデルとも UTF-16 単位
* 両モデルともスカラ値単位（UTF-16 の差は無視）

## Decision Outcome

Chosen option: "[Spec] はスカラ値単位、[Source] は UTF-16 単位", because [Spec] を UTF-16 という符号化方式から独立させつつ、[Source] で原典の観測可能な振る舞いを保てるため。

* 文字列は Unicode スカラ値（U+0000–U+D7FF, U+E000–U+10FFFF）の列とする。
* `scalarLen(s)`: スカラ値の個数（[Spec]）。`utf16Len(s)`: U+10000 以上を 2、それ以外を 1 として合計（[Source]）。
* 文字クラスは閉区間の集合で定義する（[spec/input-validation.md](../../lean/Spec/InputValidation.lean)）。
  * `HalfWidthChar = [U+0020, U+007E]`
  * `HalfWidthKanaChar = [U+FF61, U+FF9F]`
  * `FullWidthChar = 全スカラ値 − HalfWidthChar − HalfWidthKanaChar`（制御文字・補助文字も含む。原典どおり）
  * `KatakanaChar = [U+30A0, U+30FF]`
  * `DigitChar = [U+0030, U+0039]`
* 差異: 補助文字（例: U+20BB7 「𠮷」）を含む全角入力では、[Spec] と [Source] で長さ判定が異なりうる。これを既知差異として [spec/abstraction.md](../spec/abstraction.md) に登録し、「補助文字を含まない文字列では `scalarLen = utf16Len`」を証明義務とする。
* 入力の前処理（原典 `StringTrimmerEditor(true)`: 前後の空白除去、空文字は null）も手順として仕様化する。「空白」の定義は Java の `String.trim()` に合わせ U+0000–U+0020 とする（[spec/input-validation.md](../../lean/Spec/InputValidation.lean)）。

### Consequences

* Good, because 正規表現無しで全言語に実装できる
* Good, because 補助文字を含まない通常の入力では両モデルが一致する
* Bad, because 補助文字入力時の振る舞いが [Spec] と [Source] で異なる

### Confirmation

* 文字クラスの境界値（U+001F, U+0020, U+007E, U+007F, U+FF60, U+FF61, U+FF9F, U+FFA0, U+309F, U+30A0, U+30FF, U+3100）をテストベクタに含める。

## Pros and Cons of the Options

### [Spec] スカラ値 / [Source] UTF-16

* Good, because 抽象性と互換性の両立
* Bad, because 差異の管理が必要

### 両方 UTF-16

* Good, because 差異が無い
* Bad, because UTF-16 を内部表現に持たない言語で不自然

### 両方スカラ値

* Good, because 単純
* Bad, because [Source] が原典と一致しない入力が生じる

## More Information

* [spec/input-validation.md](../../lean/Spec/InputValidation.lean)
