---
type: Specification
title: "抽象化証明課題（Abstraction）"
description: "移植元モデル SourceModel から抽象モデル Spec への抽象化関数、既知差異 D-NNN、証明課題 ABS-NNN の一覧。"
tags: [spec, abstraction, proof]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:52:11+09:00
---

# 抽象化証明課題（Abstraction）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。既知差異の説明と証明課題の一覧を置く。証明そのものは Lean の `Abstraction` が正である。

[Source]（`SourceModel`）と [Spec]（`Spec`）の関係を定める（[ADR 0004](../decision/0004-two-layer-model-java-faithful-and-abstract.md), [ADR 0018](../decision/0018-language-neutral-top-level-namespaces.md)）。
Lean では名前空間 `Abstraction` に、課題 ID を docstring に持つ定理として証明する。

## 抽象化関数 α

| [Source] の値 | α | 備考 |
| --- | --- | --- |
| `int`（`LangSemantics.Java` の int32） | 数学的整数（`toInt`） | 値域内では非負なら `Nat` |
| `double`（`JDouble`） | 有理数（有限値のみ） | NaN・∞ は α 未定義 |
| `String`（UTF-16） | Unicode スカラ値の列 | 不対サロゲートを含む文字列は α 未定義 |
| `LocalDate` | `Date` | |
| `null` を含みうる参照 | `Option` | |
| 例外 | `AtrsError`（[errors-and-messages.md](errors-and-messages.md)） | `IllegalArgumentException`/`NullPointerException` は `PreconditionViolation` |
| SQL 照会結果（`LangSemantics.Sql` のバッグ・許される順列の集合） | 列 | 許される順列がすべて同じ α 値に写るときに限り定義 |
| 入力検証エラー（`BindingResult`。単項目の違反は順序不定） | エラーの多重集合 | [Spec] の列とは順序を無視して比較する（[ADR 0027](../decision/0027-validation-error-ordering.md)） |

一致定理は一般に次の形をとる。

```
前提 P(x) の下で  ∀ y ∈ Source(x).  α(y) = Spec(α(x))
```

（[Source] は SQL の未規定順序により非決定的でありうるため、結果を集合として扱う。）

## 既知差異

[Spec] と [Source] の定義が異なる箇所。

| ID | 箇所 | 差異 | 一致する前提 | 課題 |
| --- | --- | --- | --- | --- |
| D-001 | [基本運賃](fare-calculation.md#基本運賃) | [Source] は `(ratio * 0.01)` を double で掛けて切捨て。[Spec] は `floorDiv(x * ratio, 100)` | `x = routeBasicFare + extra` が 0〜200,000 かつ ratio ∈ {100, 110, 120, 125, 130, 140, 150} の全探索で差異 0 件。全値域での一致は未証明 | ABS-001 |
| D-002 | [運賃](fare-calculation.md#運賃) | [Source] は `1 - rate*0.01` の丸め誤差により、厳密値が整数 `k*100 + 1` 付近のとき 100 円少なくなる（例 1430 円・30% で [Source] 1000、[Spec] 1100） | 基本運賃がシード由来（路線運賃が 100 円単位、比率 100/125/140、加算料金 0/5000）かつ割引率がシードの値（0/5/10/20/30） | ABS-002, ABS-003 |
| D-003 | [合計金額](fare-calculation.md#合計金額) | `discountRate > childFareRate` のとき小児分が負。[Source] は 0 方向切捨て、[Spec] は前提で排除 | MD-7（`discountRate ≤ childFareRate`） | ABS-004 |
| D-004 | [ピーク時期](master-data.md#参照関数) | 期間が重なる場合、[Source] は取得順（未規定）で最初の一致 | MD-4（期間が重ならない） | ABS-006 |
| D-005 | [空席照会の集約](flight-search.md#searchflight) | 同一区間に同じ出発時刻の便があると、[Source] は 1 グループに統合し運賃種別ごとに後勝ち。整列の同順位も未規定 | MD-5（同一区間の出発時刻が一意） | ABS-011 |
| D-006 | [文字列長](input-validation.md#文字クラス)、[ログインの事前検査](authentication.md#ログインlogin)、[レポート要求の長さ](reservation-history-report.md#要求の受信onreportrequested) | [Source] は UTF-16 単位、[Spec] はスカラ値単位 | 入力が補助文字（U+10000 以上）を含まない | ABS-030 |
| D-007 | [REST 予約 API](http-contract.md#post-apiv1ticket) | [Source] は相関検証を適用しない（原典の不具合）。[Spec] は適用し、さらに搭乗者リストの要素数を 1〜6 に制限する（[input-validation.md](input-validation.md#予約入力b2)） | 入力が相関検証を満たし、搭乗者が 1〜6 名 | ABS-031 |
| D-008 | [表示名](errors-and-messages.md#項目の表示名) | [Source] の表示名「登場クラスコード」は誤記。[Spec] は「搭乗クラスコード」 | — | — |
| D-009 | [採番](ports.md#idgenerator) | [Source] は最大値の後に循環して衝突しうる。[Spec] は常に未使用 | 採番空間を使い切らない | ABS-021 |
| D-010 | [更新件数](reservation.md#予約確定reserve) | [Source] は更新件数 ≠ 1 で `System("e.ar.a0.L9002")`。[Spec] は到達不能 | リポジトリ契約（キーが存在） | ABS-022 |
| D-011 | [Email](input-validation.md#email) | [Source] はドメイン部を `IDN.toASCII` で変換し、失敗すれば不合格、変換後の長さで 255 を判定する。[Spec] は変換しない（[ADR 0026](../decision/0026-email-validation-rule.md)） | ドメイン部が ASCII だけからなる | ABS-032 |
| D-012 | [合計金額](fare-calculation.md#合計金額) | [Source] の小児分の途中計算 `j32mul(b, childFareRate − r)` は、`b × (childFareRate − r) > 2,147,483,647` のとき int32 で折り返す（値域の上限 `b = 100,000,000` では最大 約 1e10）。[Spec] は任意精度 | 各フライトで `b × (childFareRate − r) ≤ 2,147,483,647` | ABS-005 |
| D-013 | [会員情報変更](member.md#会員情報変更update) | [Source] は現在パスワードの照合と更新を別トランザクションで行う。[Spec] は 1 トランザクション（[ADR 0030](../decision/0030-member-update-in-single-transaction.md)） | 照合から更新までの間に、同じ会員のパスワードを他のトランザクションが変更しない | ABS-034 |
| D-014 | [Clock](ports.md#clock) | [Source] は `today()` を呼ぶたびに現在日付を読むので、日付をまたいで実行されたユースケースの中で今日が変わりうる。[Spec] は 1 ユースケースの中で一定 | ユースケースの実行中に日付が変わらない | ABS-040 |
| D-015 | [マスタの不変条件](master-data.md#不変条件spec) | MD-1〜MD-3 が破れた場合、[Source] は後勝ちの上書きまたは `null` による前提違反になる。[Spec] は MD-1〜MD-3 を前提とし定義しない | MD-1〜MD-3 | ABS-040 |
| D-016 | [セッション](http-contract.md#セッション) | [Source] はログイン時にセッション ID を変えない（セッション固定化の対策が無い）。[Spec] は新しい ID に変える | 攻撃者がセッション ID を事前に与えていない（振る舞いの比較ではセッション ID を観測しない） | — |
| D-017 | [ログイン成功時の遷移先](http-contract.md#認証と権限) | [Source] は `redirectTo` の絶対 URL（外部サイト）へもリダイレクトする。[Spec] はアプリ内のパスだけを受け付ける | `redirectTo` が無いか、`/` で始まり `//` で始まらない | — |
| D-018 | [Min/Max](input-validation.md#文字クラス)・[creditTerm](domain-model.md#member) | [Source] は文字列の `Min`・`Max` を `BigDecimal` として判定し（`"1.5"`, `"+1"`, `"1e1"` も数になる）、`creditTerm` が 6 文字以上なら DB の `VARCHAR(5)` 違反でシステムエラー。[Spec] は十進整数だけを数とし、長さの上限を持たない | `creditMonth`・`creditYear` が `[0-9]+` で、`creditTerm` が 5 文字以下 | ABS-040 |
| D-019 | [支払期限の表示](domain-model.md#書式) | [Source] は曜日を要求のロケールで表示する。[Spec] は常に日本語 | `Accept-Language` が日本語 | — |
| D-020 | [予約入力画面の表示](http-contract.md#b2-予約) | `GET /ticket/reserve?form` で便マスタに無い便名などを渡すと、[Source] は `NullPointerException`・`Assert` で 500。[Spec] は `InvalidRequest` で 400 | 選択フライトが便マスタで解決できる | — |
| D-021 | [日付の解析](input-validation.md#日付の解析) | [Source] は符号付きの 5 桁以上の年（`+10000/01/01`）と 0 以下の年も受け付ける。[Spec] は 4 桁の年 1〜9999 だけ | 年が符号無し 4 桁で 1 以上 | ABS-040 |

## 証明課題

| ID | 種類 | 内容 | 関連 |
| --- | --- | --- | --- |
| ABS-001 | 一致 | 値域内のすべての入力で `α(basicFare_Source) = basicFare_Spec`。成り立たない入力があれば反例を D-001 に記録し、一致する前提を確定する | D-001 |
| ABS-002 | 一致 | シード由来の前提の下で `α(fare_Source) = fare_Spec` | D-002 |
| ABS-003 | 差異の特徴付け | 値域内で `fare_Spec − 100 ≤ α(fare_Source) ≤ fare_Spec`（[Source] は [Spec] 以下で、差は高々 100 円） | D-002 |
| ABS-004 | 一致 | MD-7 の下で `α(totalFare_Source) = totalFare_Spec`（`fare` は ABS-002 の前提を含む） | D-002, D-003 |
| ABS-005 | 安全性 | 値域内で、D-012 の前提（各フライトで `b × (childFareRate − r) ≤ 2,147,483,647`）の下では [Source] の運賃・合計金額の計算に int32 オーバーフローが起きない。前提が破れる入力では小児分の途中計算だけが折り返すことを示す | [domain-model.md](domain-model.md#値域), D-012 |
| ABS-006 | 一致 | MD-4 の下で `peakTimeOn` の [Source] の結果（取得順のすべての順列）が一意で [Spec] と一致 | D-004 |
| ABS-010 | 同値 | `isAvailableFareType` と SQL 条件 `beforeDayNum BETWEEN end AND start` の同値 | [flight-search.md](flight-search.md#運賃種別の予約可能判定) |
| ABS-011 | 一致 | MD-5 の下で、`searchFlight` の [Source]（`LangSemantics.Sql` の照会＋Java の集約）の許されるすべての結果が [Spec] と一致 | D-005 |
| ABS-020 | 不変条件 | [Source] の予約確定の前後で全フライトの `vacantNum ≥ 0`、失敗時は `sequences` を除いて状態不変 | [reservation.md](reservation.md#予約確定reserve) |
| ABS-021 | 一致 | 採番空間を使い切らない前提で、[Source] の採番は未使用値を返す | D-009 |
| ABS-022 | 到達不能 | リポジトリ契約の下で [Source] の `e.ar.a0.L9002` は発生しない | D-010 |
| ABS-030 | 一致 | 補助文字を含まない文字列で `utf16Len = scalarLen`、したがって入力検証の結果が一致 | D-006 |
| ABS-031 | 包含 | 相関検証を満たす入力について、REST 予約 API の [Source] と [Spec] の結果が一致 | D-007 |
| ABS-032 | 一致 | ドメイン部が ASCII だけからなる文字列で、[Source] と [Spec] の Email 判定が一致 | D-011 |
| ABS-033 | 一致 | 入力検証の [Source] の結果（多重集合）と [Spec] の結果（列）が、順序を無視して一致 | [ADR 0027](../decision/0027-validation-error-ordering.md) |
| ABS-034 | 一致 | D-013 の前提の下で、会員情報変更の [Source] と [Spec] の結果・状態遷移が一致 | D-013 |
| ABS-040 | 一致 | 予約・会員・認証・レポートの各ユースケースについて、上記前提（D-014・D-015 を含む）の下で [Source] と [Spec] の結果・状態遷移が α で一致 | 全体 |

課題の進め方は [backlog 0005](../backlog/0005-fare-abstraction-proofs.md) ほか各機能の backlog 項目。
