---
type: Guideline
title: "仕様文書の書き方"
description: "Spec で表現できない仕様を書く Markdown の仕様文書の区分・節構成・差異の表と、道具が読む見出しと値。"
tags: [spec, documentation]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# 仕様文書の書き方

正規仕様は Lean の `Spec` である。Markdown の仕様文書には、**`Spec` で表現できない仕様** を規範として書き、加えてメタ情報と、形式化前の草案を置く。

## 区分

各文書は、frontmatter（またはそれに相当する見出し直下の一文）で区分を示す。混在する場合は節ごとに示す。

| 区分 | 意味 | 規範性 |
| --- | --- | --- |
| `normative` | `Spec` で表現できない仕様: 並行実行での原子性・直列化可能性、伝送とセキュリティの方式（CSRF・トークン・認証方式）、ポート実装の運用要件（ファイル配置・キュー・文字コード・パスワードハッシュの互換）、非機能要件。ここに書いた仕様はリファインメントの証明の対象外になる。そのため、どう確認するかを保証の限界の文書に書く | 規範 |
| `meta` | 用語集、追跡（[traceability.md](traceability.md)）、テストベクタの操作名、証明課題と既知差異の一覧、保証の限界 | 運用規則として規範 |
| `draft` | `Spec` で表現できるが、まだ形式化していない業務規則。Lean 形式化の入力 | 形式化までの暫定 |
| `informative` | 形式化済みの業務規則の要約と、Lean 定義へのリンク | 非規範 |

- `draft` の節を Lean に形式化したら、その節を `informative` に書き換える。式・手順・エラー表などの規範的な定義は残さない。
- `informative` の要約と Lean `Spec` が食い違ったら、Lean `Spec` が正である。要約を直す。
- `Spec` で表現できるか迷う仕様は、まず Lean で書くことを試みる。書けなかった理由を `normative` の節に記録する。

## モデルの併記

| 記号 | 意味 |
| --- | --- |
| **[Spec]** | 抽象モデル（意図） |
| **[Source]** | 移植元モデル（原典の観測可能な振る舞い） |
| **[Spec=Source]** | 両モデルで定義が同じ |
| **[Target]** | 移植先モデル。既知差異 `T-NNN` がある場合にだけ書く |

- 草案には [Spec] と [Source] を書く。[Target] 固有の事項（移植先のパッケージ構成など）は書かない。例外は、[Target] と [Spec] の差異（`T-NNN`）である。これは具体化の課題一覧に登録し、関係する節からリンクする。
- 異なる場合は両方の定義を並べ、差異を既知差異の一覧に ID（`D-NNN`）付きで登録し、相互にリンクする。一覧の正は Lean の登録簿（`@[gap_entry]`）であり、文書の表は道具が生成する。差異の行を足す・直すときは、Lean の宣言を書き、表を再生成する（[lean/trace-attributes.md](lean/trace-attributes.md#ギャップの登録簿)）。
- 差異には種類を付ける。種類は、前提型・観測型・モデル外の 3 つである（[architecture.md](architecture.md#差異)）。
  - 前提型と観測型には、次の 3 つを書く。
    - Lean の名前（`@[deviation]`）
    - それを含むリファインメントの課題（R）
    - 差異の証拠の課題（W）
  - モデル外の差異は、Lean 名と課題の欄に「— モデル外」と書き、保証の限界の文書へリンクする。
  - 前提型・観測型の差異では、課題欄を空欄や「—」にしてはならない。
- [Spec] の PRE の外での [Source] の振る舞い（前提違反など）は差異ではない。記録する場合は、既知差異とは別の表に置く（登録簿では種類「PRE の外」とする。ID は `D-NNN` の系列から採る）。種類を確かめる作業が残っている違いは、種類「未確定」として登録する。
- [Source] の記述では、移植元言語の意味論を言語パックの名前付き演算で書く（例: `j32mul`, `jdmul`, `jd2i`。[java/semantics.md](java/semantics.md)）。

## ID の体系

| ID | 対象 | 置き場所 |
| --- | --- | --- |
| `D-NNN` | 既知差異（[Spec] と [Source] の違い）と、それに準じて明示するもの（PRE の外・未確定） | Lean の `@[gap_entry]`（正）と、そこから生成する抽象化の課題一覧（meta）の表。差異の述語・成分の `@[deviation]`、箇所の印 `@[gap]` |
| `T-NNN` | 既知差異（[Spec] と [Target] の違い） | Lean の `@[gap_entry]`（正）と、そこから生成する具体化の課題一覧（meta）の表。`@[deviation]`・`@[gap]` |
| `ABS-NNN` | 抽象化の証明課題（R・W・C・L）。W は `ABS-1NN` が `D-0NN` に対応する | 抽象化の課題一覧。Lean `Abstraction` の `@[obligation]` |
| `REF-NNN` | 具体化の証明課題（R・W・C・L）。W は `REF-1NN` が `T-0NN` に対応する | 具体化の課題一覧（meta）。Lean `Refinement` の `@[obligation]` |
| `SRC-NNN` | `TargetModel` ⇔ 移植先ソースの決定論的な確認課題 | 同上 |
| `SPEC-NNN` | `Spec` 自身の証明課題（標準の選択が関係に含まれること、INIT ⇒ INV、INV の保存、選択の像としての形、入口の全域性、初期状態の 1 点） | 抽象化の課題一覧 |
| `N-NNN` | `Spec` の非決定性（環境の選択・自由な選択） | 抽象化の課題一覧（meta）。Lean の `@[nondet]` |
| `MD-N` | マスタデータの不変条件 | マスタデータの草案 |
| `TR-*` | 追跡の検査 | [traceability.md](traceability.md) |

## 定義の節構成（draft と normative）

1. **シグネチャ**: 入力・出力の型。暗黙の入力（今日の日付・設定値・マスタ）も明示的な引数として書く。
2. **事前条件**: 呼び出し側が保証する条件と、破った場合の扱い（[Spec] では型で排除する。[Source] では前提違反とする）。
3. **定義**: 計算式または手順。番号付き手順は **評価順序が意味を持つ**（最初に失敗した検査のエラーを返す）。
4. **エラー**: 返しうるエラーコードと条件の表。
5. **事後条件・不変条件**: 状態変更がある場合、前後の状態の関係。
6. **例**: 最低 1 つ。境界値を含めることが望ましい。許す例に加えて、拒む例（エラーになる入力、`Spec` が許さない結果）も書く。例は、期待値を手で書いた Lean 側の検査になる（[conformance.md](conformance.md#意図から書く例)）。
7. **出典**: 移植元ロケータ（[traceability.md](traceability.md#ロケータ)）。

## 記法

- 整数演算: `+ - *` は数学的整数。除算は `floorDiv(a, b)`・`ceilDiv(a, b)` で書き、`/` は使わない。[Source] では言語パックの演算（例 `jdiv32`）を使う。
- 切上げ: `ceilTo(x, m)` = `ceilDiv(x, m) * m`（x ≥ 0）。百分率: `pct(a, r)` = `floorDiv(a * r, 100)`。
- 列: `[a, b, c]`、長さ `len(xs)`、添字は **0 始まり**。
- 写像: `{k ↦ v}`。**反復順序が意味を持つ場合は必ず順序を定義する**（挿入順など）。
- 日付: `Date`、`addDays(d, n)`、`daysBetween(a, b)`（b − a の日数）、`fullYearsBetween(b, d)`（満年数）。
- 真偽: `true` / `false`、`∧ ∨ ¬`。
- 文字列: Unicode スカラ値の列。長さは [Spec] では `scalarLen`、[Source] では言語パックの長さ（例 `utf16Len`）。

- 移植元の式は、長いソースを写さず、記法で書き直す（例: `(int)(x * (ratio * 0.01))` は [Source] の `jd2i(jdmul(x, jdmul(ratio, 0.01)))`）。式は `floor(x / 100)` のように書き、LaTeX は使わない。日付は ISO 8601 で書く（移植元の書式そのものを示すときを除く）。

## 道具が読む見出しと値

スキルの道具（`scripts/`）は、課題一覧（抽象化・具体化）の次の見出しと値を、文字列のまま読む。綴りを変えてはならない。

| 見出し・値 | 置き場所 | 読む道具 |
| --- | --- | --- |
| `## 既知差異`（具体化では `## 既知差異（T-NNN）`）、`### 前提型の差異の影響`、`### [Spec] の前提の外での [Source] の振る舞い`、`### 未確定の差異` | 課題一覧。表は生成区画（`gaps-known`・`gaps-impact`・`gaps-outside-pre`・`gaps-undetermined`） | `trace manifest` |
| `### 入口の R 課題` | 課題一覧。行は `| <課題 ID> | … | <作業項目の ID> |` | `trace check`（TR-PE）、`check_obligations.py` |
| `## Spec の非決定性`、種類の値 `環境`・`自由` | 抽象化の課題一覧。行は `| N-NNN | <種類> | … | <作業項目の ID> |` | `check_obligations.py`（TR-N） |
| `## 証明課題`（具体化では `## REF:`）、種類の値 `R` | 課題一覧。行は `| <課題 ID> | R | … |` | `trace check`、`check_obligations.py` |
| 影響の値 `出力のみ`・`中断`、種類の名前（`前提型`・`観測型`・`モデル外`…） | 登録簿から生成する（`Trace.GapKind.label`・`Trace.Impact.label`） | `check_obligations.py` |
| 行頭の `出典:` と、バッククォートで囲んだロケータ | 仕様文書（`docs.spec`） | `trace check`（TR-R） |
| 作業項目の frontmatter の `id:`・`state:`（`done` で完了） | 作業項目（`docs.backlog`） | 段階導入（`trace check`・`check_obligations.py`） |

## してはならないこと

- 「Java と同じ」「フレームワークの既定どおり」のように、**外部の実装に意味を委ねる**。必要な意味はすべて本文に書き下す。
- 浮動小数点数を [Spec] の定義に使う。
- ハッシュ表の反復順序・ロケール・タイムゾーン・実行環境に依存する定義を書く（[portability.md](portability.md)）。

## 未確定事項

調査が終わっていない点は本文中に `> **TODO(spec):** …` と書き、作業項目へリンクする。`TODO(spec)` が残る節を根拠に実装を確定してはならない。
