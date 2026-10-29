---
type: Guideline
title: "仕様執筆規約"
description: "docs/spec の書き方。規範・メタ情報・草案の区分、[Spec]/[Source] 併記、定義の節構成、記法、禁止事項。"
tags: [rules, spec]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# 仕様執筆規約

正規仕様は Lean の `Spec` であり、`docs/spec/` には **`Spec` で表現できない仕様** だけを規範として定義する（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

## 区分

`docs/spec/` の各文書は、frontmatter の `spec_role` と本文冒頭の一文で区分を示す。1 文書に複数の区分が混在する場合は節ごとに示す。

| `spec_role` | 意味 | 規範性 |
| --- | --- | --- |
| `normative` | `Spec` で表現できない仕様（並行性・伝送・セキュリティ方式・実行環境・非機能） | 規範 |
| `meta` | 用語集・追跡表・テストベクタ形式・証明課題の一覧 | 規範（運用規則として） |
| `draft` | `Spec` で表現できるが未形式化の業務規則。Lean 形式化の入力 | 形式化までの暫定 |
| `informative` | 形式化済みの業務規則の要約と Lean 定義へのリンク | 非規範 |

- `draft` の節を Lean に形式化したら、その節を `informative` に書き換える。式・手順・エラー表などの規範的な定義は残さない。
- `informative` の要約と Lean `Spec` が食い違ったら、Lean `Spec` が正である。要約を直す。
- `Spec` で表現できるかどうか迷う仕様は、まず Lean で書くことを試み、書けなかった理由を `normative` の節に記録する。

以下の書き方の規則は `draft` と `normative` に適用する。

## モデルの併記

仕様は次の層を扱う（[ADR 0004](../decision/0004-two-layer-model-java-faithful-and-abstract.md), [ADR 0018](../decision/0018-language-neutral-top-level-namespaces.md)）。

| 層（名前空間） | 記号 | 目的 |
| --- | --- | --- |
| 抽象モデル `Spec` | **[Spec]** | 正規の業務仕様。厳密な整数演算。すべての移植先が従う |
| 移植元モデル `SourceModel` | **[Source]** | 原典の観測可能な振る舞いを原典言語（Java）の意味論ごと再現する |
| 抽象化証明課題 `Abstraction` | `ABS-NNN` | [Source] → [Spec] の関係。[abstraction.md](../spec/abstraction.md) |
| 移植先モデル `TargetModel` | **[Target]** | 各言語の実装。仕様本文には書かない |
| 具体化証明課題 `Refinement` | `REF-NNN` | [Spec] → [Target] の関係。[refinement.md](../spec/refinement.md) |

草案（各機能の文書）には [Spec] と [Source] を書く。[Target] 固有の事項（Rust のクレート構成など）は書かない。

- 両モデルで同じ定義になる場合は 1 回だけ書き、冒頭に **[Spec=Source]** と明記する。
- 異なる場合は **[Spec]** と **[Source]** の定義を並べ、差異を [abstraction.md](../spec/abstraction.md) の「既知差異」に ID（`D-NNN`）付きで登録し、相互にリンクする。
- [Source] の記述では Java の意味論（int32 の折り返し、`/` の 0 方向切捨て、IEEE 754 binary64、`BigDecimal` の丸めモード、UTF-16 長）を [ADR 0005](../decision/0005-java-primitive-semantics.md) の名前付き演算で書く（例: `j32mul`, `jdmul`, `jd2i`）。

## 定義の書き方

ひとつの操作（関数・ユースケース）は次の節を持つ。

1. **シグネチャ**: 入力・出力の型（[domain-model.md](../spec/domain-model.md) の型名）。暗黙の入力（今日の日付・設定値・マスタ）も明示的な引数として書く。
2. **事前条件**: 呼び出し側が保証する条件。破った場合の扱い（[Spec] では型で排除または `PreconditionViolation`、[Source] では Java の `Assert` 失敗＝`IllegalArgumentException`）。
3. **定義**: 計算式または手順。番号付き手順は **評価順序が意味を持つ**（最初に失敗した検査のエラーを返す）。
4. **エラー**: 返しうるエラーコードと条件の表（[errors-and-messages.md](../spec/errors-and-messages.md)）。
5. **事後条件・不変条件**: 状態変更がある場合は前後の状態の関係。
6. **例**: 最低 1 つの具体例（入力と期待出力）。境界値を含めることが望ましい。例は適合テストベクタの種になる。
7. **出典**: Java 原典のファイルとシンボル（[documentation.md](documentation.md#出典java-原典の記法)）。

## 記法

- 整数演算: `+ - *` は数学的整数。除算は `floorDiv(a, b)`・`ceilDiv(a, b)`、[Source] では `jdiv32(a, b)`（0 方向切捨て）を使い、`/` は使わない。
- 切上げ: `ceilTo(x, 100)` = `ceilDiv(x, 100) * 100`（x ≥ 0 のとき）。
- 列: `[a, b, c]`、長さ `len(xs)`、添字は **0 始まり**。
- 写像: `{k ↦ v}`。**反復順序が意味を持つ場合は必ず順序を定義する**（挿入順など）。
- 日付: `Date` 型、`addDays(d, n)`、`daysBetween(a, b)`（b − a の日数）。
- 真偽: `true` / `false`、論理演算 `∧ ∨ ¬`。
- 文字列: Unicode スカラ値の列。長さは [Spec] では `scalarLen`、[Source] では `utf16Len`（[ADR 0010](../decision/0010-text-length-and-character-classes.md)）。

## してはならないこと

- 「Java と同じ」「Spring の既定どおり」のように **外部の実装に意味を委ねてはならない**。必要な意味はすべて本文に書き下す。
- 浮動小数点数を [Spec] の定義に使ってはならない（[ADR 0006](../decision/0006-exact-integer-arithmetic-in-abstract-model.md)）。
- ハッシュ表の反復順序・ロケール・タイムゾーン・実行環境に依存する定義を書いてはならない（[portability.md](portability.md)）。

## 未確定事項

調査が終わっていない点は本文中に `> **TODO(spec):** …` と書き、対応する backlog 項目へリンクする。
`TODO(spec)` が残る節を根拠に実装を確定してはならない。
