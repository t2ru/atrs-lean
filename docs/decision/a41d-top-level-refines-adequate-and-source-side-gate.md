---
type: Architecture Decision Record
title: "実装済みの範囲のトップレベルの Refines・Adequate と、移植元側の段階導入"
description: "Abstraction.lean のトップレベルに、機能を並置した Spec.machine と SourceModel.machine の Machine.Refines・Machine.Adequate を置き、R 課題ごとの義務の束から組み立てる。追跡の検査の段階導入を側ごとにし、運賃計算・マスタの移植元側を失敗扱いにする。移植元の項目の機能への振り直しと、ドメインモデルのアクセサ・DDL の制約・シード・設定の Bean の追跡の仕方を決める。"
tags: [adr, abstraction, refinement, traceability]
id: "a41db4fd-9066-4269-8b32-b3e7b818bf70"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:30:00+09:00
---

# 実装済みの範囲のトップレベルの Refines・Adequate と、移植元側の段階導入

## Context and Problem Statement

実装済みの範囲は、マスタ・設定・コードリストの読み込み（ABS-026）と運賃計算（ABS-001・002・004）である。R 課題とその W 課題は証明済みだが、次の問題があった。

- 何がどこにあるか分からない。主定理は `Abstraction.MasterData`・`Abstraction.Fare` の下に散らばり、`Abstraction.lean` にはモジュールの一覧しか無かった。
- 空虚化を防ぐ義務の一部（入口でない R 課題の `TotalUnder`・`EnvWitness`）が課されず、義務が束として示されていなかった。
- 追跡の検査の段階導入が、機能の作業項目のすべて（Rust の ddb4・eff6・4b0e を含む）の完了を待っていた。main の CI では、運賃計算・マスタについて TR-S1 が 310 件、TR-P が 1 件の警告として残っていた。以後の機能の取り込みで実装済みの範囲が壊れても、CI は失敗しない。

オーナーの依頼: 「現状の実装範囲内の抽象化検証を記述・証明してほしい。以後の機能の取り込みは、それが通ることを保つようにしたい」「Refine と Adequacy を使った証明を Abstraction 内に書いてほしい」「トップレベルの証明課題は、トップレベルに書け。Abstraction.lean には Machine.Refines A B と Machine.Adequate A B が存在するはず。Refinement.lean も同じ」。

## Decision Drivers

* 基本原則 1〜3（[ADR c336](c336-foundational-principles.md)）: 移植元の項目の網羅とリファインメントの証明を、実装済みの範囲について欠けなく示すこと
* トップレベルの主張を、`Abstraction.lean` の冒頭で読めること
* 以後の機能の取り込みで、実装済みの移植元側が壊れたら CI が失敗すること
* 移植先側（Rust）の作業を待たないこと

## Considered Options

* トップレベルの主張
  * 機能を並置した `Spec.machine`・`SourceModel.machine` について、`Machine.Refines`・`Machine.Adequate` を `Abstraction.lean` に置く（スキルの `Machine.Sum` で R 課題から組み立てる）
  * R 課題ごとの定理の一覧（連言）を置く
* ゲート
  * 側ごとの段階導入（[スキルの ADR ab9e](../../.agents/skills/port-lang/references/docs/decision/ab9e-adequate-bundle-sum-and-side-staging.md)）
  * 現在の警告の集合を固定するラチェット
* 移植元の項目のうち、実装済みの機能の glob に入っていた他の機能の項目
  * 機能の対応表の glob を細かくして、使う機能へ移す
  * 今の機能で `@[source]` を付ける

## Decision Outcome

Chosen option: "機能を並置したトップレベルの `Refines`・`Adequate` を `Abstraction.lean` に置き、側ごとの段階導入で運賃計算・マスタの移植元側を失敗扱いにする。他の機能の項目は対応表で移す", because トップレベルの主張が 1 か所で読め、R 課題ごとの束と検査（GA・OB-A・TR-*）で形を保ったまま、以後の取り込みでの退行を CI が止めるため。
連言はトップレベルの機械を持たず、機能をまたぐ振る舞い（複数歩の模倣）を述べられない。
ラチェットは、作業中に正当に増える警告と区別できない。
他の機能の項目に今 `@[source]` を付けると、その機能のモデルが無いまま網羅を主張することになる。

### トップレベルの主張

- `Spec.machine`（`Spec.lean`）・`SourceModel.machine`（`SourceModel.lean`）は、ABS-026・001・002・004 の機械を、この順に並置したもの。
- `Abstraction.lean` のトップレベル:
  - `Abstraction.refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue`
  - `Abstraction.adequate : Machine.Adequate (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env`
- R 課題ごとの束 `queryAdequate`・`basicFareAdequate`・`fareAdequate`・`totalFareAdequate`（`Abstraction.Adequacy`）に、R 課題と同じ課題 ID の `@[obligation]` を付ける。
  - 環境の前提 `envMQ`・`envBF`・`envF`・`envTF` は、`Spec.masterConfigOk` と入力の値域・差異の前提を、抽象側の入力の成分だけで書いた述語とする。入口の機械ではないので `@[env_pre]` を付けない。
  - `EnvWitness` の証人は、上流の設定 `SourceModel.Config.upstreamConfig` と小さな DB（`dbTF`・`db29` の変形）である。
  - あわせて、1 歩の可換式 `queryCommutes` などを示す。
- `Refinement.lean` も同じ形とし、`TargetModel` ができた時点（[backlog eff6](../backlog/eff6-target-model-fare-and-refinement.md)）で主定理を置く。それまでは `sorry` や公理で置かない。

### 段階導入とゲート

- `trace/features.json` の作業項目を側に分けた。
  - Fare: 移植元側 25f7・bbcc・76a6、移植先側 ddb4・eff6
  - MasterData: 移植元側 25f7・76a6、移植先側 4b0e
  - Http は、a89e が両側（`SourceModel.Http` と Rust）を持つので、両側に置いた。
- トップレベルの定義（`Abstraction.refines` など）は、機能「Top」に置く。
- backlog 76a6 を完了すると、運賃計算・マスタの移植元側の TR-S1・TR-P・TR-D・TR-K が失敗扱いになる。TR-PE は入口（HTTP・レポート）の作業項目を待つ。

### 移植元の項目の扱い

- 他の機能へ移した項目
  - FlightSearch: `TicketSharedService{,Impl}#isAvailableFareType`・`getSearchLimitDate`、`FareTypeUtil`、`DateTimeUtil`（最初に使う空席照会）、`FlightType`、表 `FLIGHT` とその制約・シード
  - Reserve: `b0` の残り（`existsFlight`・`validate*`・`InvalidFlightException`）、`Reservation`・`ReserveFlight`・`Passenger`、予約の表と制約・シーケンス、`annotationDrivenTransactionManager`、`jdbcClient`
  - Member: `Member`・`MemberLogin`・`Gender`・`CreditType`、会員の表と制約・シーケンス・シード、パスワードエンコーダの Bean
  - Report: JMS の Bean
  - Http: 例外の解決・ログ・メッセージの Bean、`resultMessagesLogging*`（ログは範囲外だが、ファイル単位の対象外にできないため、ログを扱う機能に置く）
- 対象外: `commons-logging.properties`（[ADR 84bf](84bf-porting-scope.md#decision-outcome) のログ）
- `@[source]` を付けた項目
  - ドメインモデルのアクセサ・`toString`・`serialVersionUID` は、そのクラスを写した `SourceModel.Model` の構造体に付ける。構造体のフィールドは、クラスのフィールドとアクセサの組を写す。`toString`・`serialVersionUID` は観測されない（応答に現れない）ので、構造体が覆うとみなす。
  - 列挙 `BoardingClassCd`・`FareTypeCd` の定数と `getCode` は、`Enum.valueOf` を写した `SourceModel.Repository.Mapping.boardingClassCd`・`fareTypeCd` に付ける。
  - DDL の制約（主キー・一意・外部キー・索引）は、表の行の構造体（`SourceModel.Repository.Schema`）に付ける。制約の効果（DB の状態が満たすこと）は、[Spec] の不変条件 MD-1〜MD-3 と既知差異 D-027 の前提で扱う。照合は PostgreSQL での差分実行（`pg-master-sql`）が DDL を実行して行う。
  - シードのマスタの文は、生成器 `tools/conformance/seed_lean.py` が `Spec.Seed` の各表に付ける。シードから [Spec] の値への変換は、この生成器の決定論的な変換である。`trace/checks.json` に検査 `seed-lean` を足した。
  - 設定・MyBatis の Bean: `propertySourcesPlaceholderConfigurer` は `upstreamConfig`、`jdbcTemplateForCodeList` は `jdbcCodeList`、`AirportCodeList` の setter・`afterPropertiesSet` は `airportCodeList`、`MybatisConfig#configuration`・`sqlSessionFactory` は `Mapping.route`（列名とプロパティの対応）、`FareUtil.CEIL_FARE_SCALE` は `ceilFare`、`MULTIPLICATION_RATIO_IN_NORMAL_TIME` は `calculateBasicFare` に付ける。

### Consequences

* Good, because `Abstraction.lean` の冒頭で、実装済みの範囲の [Source] と [Spec] の関係（`Refines`・`Adequate`）が読める
* Good, because 運賃計算・マスタの移植元側の退行は、以後の機能の取り込みで CI を失敗させる
* Good, because 入口でない R 課題にも `TotalUnder`・`EnvWitness` が課され、R 課題の具体側の正常終了が実在することが示される
* Bad, because 機能を取り込むたびに、`Spec.machine`・`SourceModel.machine`・`dev`・`devC`・`glue`・`env` に並置を足す。足し忘れると、その機能はトップレベルの主張に入らない。R 課題ごとの束（OB-A）と TR-P は検査されるので、R 課題の欠けは検出される
* Bad, because 対象外にできないログの Bean（`resultMessagesLogging*`）を Http に置いた。Http の移植元側の完了時に、範囲外として扱いを決める

### Confirmation

* `tools/ci/lean.sh` が全段通る。`trace check` で、Fare・MasterData の TR-S1・TR-P・TR-D・TR-K が 0 件。
* backlog 76a6 を完了した状態で `@[source]` を 1 つ外すと、`trace check` が失敗する。

## More Information

* [スキルの ADR ab9e](../../.agents/skills/port-lang/references/docs/decision/ab9e-adequate-bundle-sum-and-side-staging.md)
* [ADR 70eb](70eb-refinement-non-vacuity-obligations.md)、[ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md)
* [backlog 76a6](../backlog/76a6-source-side-adequacy-gate.md)
