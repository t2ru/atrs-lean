---
type: Specification
title: "抽象化証明課題（Abstraction）"
description: "移植元モデル SourceModel が抽象モデル Spec を B メソッドの意味でリファインすることの証明課題 ABS-NNN、貼り合わせ関係と抽象化関数、既知差異 D-NNN の一覧。"
tags: [spec, abstraction, refinement, proof]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:00:00+09:00
---

# 抽象化証明課題（Abstraction）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。既知差異の説明と証明課題の一覧を置く。証明そのものは Lean の `Abstraction` が正である。

[Source]（`SourceModel`）と [Spec]（`Spec`）の関係を定める。関係は B メソッドのリファインメントである。具体機械 `SourceModel` が、抽象機械 `Spec` をリファインする（[ADR c336](../decision/c336-foundational-principles.md), [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md)）。
Lean では、名前空間 `Abstraction` に、課題 ID を `@[obligation]` に持つ定理として証明する。

## トップレベルの主定理

`lean/Abstraction.lean` のトップレベルに、実装済みの範囲の [Source] と [Spec] の関係を置く（[ADR 91be](../decision/91be-top-level-preserves-refines-abstracts.md)）。

```lean
theorem Abstraction.refines :
    Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
theorem Abstraction.preserves :
    Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
theorem Abstraction.abstracts :
    Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
```

- `Spec.machine`・`SourceModel.machine` は、実装済みの範囲の機能の機械を同じ並びで並置したもの（`Machine.sum`）。
- `dev`・`devC`・`glue`・`env` は、R 課題ごとの前提型の差異・貼り合わせ・環境の前提を並置したもの。
- `Machine.Refines`（[Source] refines [Spec]）は、B メソッドのリファインメントである。B に無い義務は含めない。
- `Machine.Preserves`（[Spec] preserves [Source]）は、R 課題の空虚化を防ぐ意味的な義務のすべての束で、`Refines` を含まない。
  - 成分: `Sound`・`InitIs`・`InitSurj`・`TotalUnder`・`EnvWitness`、環境の前提を置かないかその必要性。基底が `Machine.ofChoice` なら `Pinned`・`NoFaultReachable`・`FreeFrame`、「出力のみ」の差異ごとに `StateSafe`（現行の R 課題には当たらない）。
- `Machine.Abstracts`（[Spec] abstracts [Source]）は、`Preserves ∧ Refines` である。
  - 系: 初期状態からの複数歩の模倣（`run_init`）、[Source] の正常終了が実在すること（`exists_ok`）。
- `refines` は R 課題の主定理を、`preserves` は R 課題ごとの束（下の表）を並置して示す。互いを使わない。機能を取り込んだら、その R 課題の主定理と束を並置に加える。主定理が `lake build` で通り続けることが、取り込みの条件である。

| R 課題 | 機能 | 束（`Machine.Preserves`。同じ課題 ID の `@[obligation]`） | 環境の前提 |
| --- | --- | --- | --- |
| ABS-026 | マスタ・設定・コードリストの読み込み | `Abstraction.MasterData.queryPreserves` | `envMQ`: `masterConfigOk` と問い合わせの値域 |
| ABS-001 | 基本運賃 | `Abstraction.Fare.basicFarePreserves` | `envBF`: `masterConfigOk`、`routeBasicFare + extraCharge` の値域、`dev_D001` |
| ABS-002 | 運賃 | `Abstraction.Fare.farePreserves` | `envF`: 基本運賃と割引率の値域、`dev_D002` |
| ABS-004 | 合計金額 | `Abstraction.Fare.totalFarePreserves` | `envTF`: `masterConfigOk`、入力の値域、`dev_D001T`・`dev_D002T`・`dev_D012` |
| ABS-011 | 空席照会 | `Abstraction.FlightSearch.searchPreserves` | `envFS`: `masterConfigOk`、照会の搭乗クラスがマスタにあること、空港コードと照会の区間の便マスタの便名が空白でないこと、`dev_D001S`・`dev_D002S` |

束の並置 `Preserves.sum` は全 R 課題に共通の 6 成分を並べる。基底が `ofChoice` の R 課題（ABS-011）の条件付きの成分（`pinned`・`noFault`・`freeFrame`・`stateSafeC`）は、機能の束に置き、トップレベルでは忘れた束（`Preserves.core`）を並置する。

あわせて、R 課題ごとの 1 歩の可換式（`queryRefines_commutes`・`basicFareRefines_commutes`・`fareRefines_commutes`・`totalFareRefines_commutes`・`searchRefines_commutes`）を示す。
内容は、環境の前提の下で [Source] のどの結果も正常終了で、出力の像が [Spec] の出力に等しい、というものである。

## リファインメントの形

機能ごとに、次を与える。

- 貼り合わせ不変条件 `J`（[Spec] の状態 `World` と [Source] の状態の関係）
- 入力の対応 `αᵢ`（全域でなければならない）
- 出力の対応 `αₒ`

そのうえで、`Machine.Refines` の 4 つの証明義務を示す。

| 証明義務 | 内容 |
| --- | --- |
| INIT | [Source] の初期状態（fixture の投入後）が、`J` で [Spec] の初期状態と結ばれる |
| 入力の全域性 | [Source] の任意の入力に `αᵢ` の像がある。像を持たない入力は、前提型の差異（具体側の入力の述語）で名前を付けて除外しなければならない |
| 適用可能性 | `INV ∧ J ∧ PRE`（と差異の前提）の下で、[Source] の操作は次のどれにも到達しない。<br>- 前提違反（`PreconditionViolation`）<br>- NaN<br>- 不対サロゲート<br>- α の未定義<br>業務エラー（例外として投げられ、α で `AtrsError` に写るもの）は正常な結果である。int32 の折り返しは、正しさの義務で結果の不一致として現れる |
| 正しさ | 同じ仮定の下で、[Source] の **許されるすべての結果**（SQL の未規定順序による非決定性を含む）が、[Spec] の結果で模倣される（状態は `J` を保ち、出力は `αₒ` で対応する） |

主定理は閉じた命題とし、次の形で書く（TR-G で検査する。[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)）。

```lean
Machine.Refines (Spec.<機能>.machine.restrict dev_DNNN …)
                (SourceModel.<機能>.machine.restrict dev_DMMM …)
                (Machine.Glue.ofStd β Ic aᵢ aₒ obs_J obs_O)
```

R 課題ごとに、主定理と同じ機械・貼り合わせについて束 `Machine.Preserves` を、同じ課題 ID の `@[obligation]` で示す（obligation-check の G6・GP、`check_obligations.py` の OB-P）。下表の空虚化を防ぐ義務のうち意味的なものは、この束の成分として示す。

主定理が前提として持ってよいのは、次の 3 つだけである（TR-D・TR-G で検査する）。前提型の差異の述語は、∀ の仮定ではなく `restrict` で機械の中に置く。

- [Spec] の PRE。入力の値域（[domain-model.md](domain-model.md#値域)）と、不変の入力であるマスタ・設定の制約 MD-1〜MD-8（[master-data.md](master-data.md#不変条件spec)）を含む
- INV（`World` の不変条件。例: `vacantNum ≥ 0`）
- 下表の前提型の差異の述語（`@[deviation "D-NNN"]`）

ポートの契約は、仮定に置かない。[Source] のポート実装が契約をリファインすることを、R 課題 ABS-021・ABS-023〜ABS-025 で証明する。ユースケースの主定理は、ポート実装を含む具体機械について述べる。

前提型の差異の述語は、次の 2 つの形をとる（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#差異)）。

- 抽象側の入力・状態の述語。抽象側の PRE を強める（例: `dev_D002`）。
- 具体側だけにある入力・環境の述語。具体機械を制限する（例: `dev_D019` の `Accept-Language`）。

ある R 課題が、他の R 課題の操作を含むことがある（例: 空席照会は運賃計算を含む）。その場合、含まれる R 課題の仮定・成分をすべて引き継ぐ。引き継いだ差異も、下表の R 課題の欄に挙げる。

### 空虚化を防ぐ義務

`Machine.Refines` だけでは、[Spec] が緩い場合・PRE が強すぎる場合・貼り合わせが粗い場合にも空虚に成り立つ。そこで、R 課題ごとに次を課す（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)、スキル spec-pivot の [architecture.md](../../.agents/skills/spec-pivot/references/docs/spec/architecture.md#空虚化を防ぐ義務)）。

| 義務 | 内容 |
| --- | --- |
| 貼り合わせの形 | `Glue.ofStd` で作る。β・aᵢ・aₒ は下の表の標準の抽象化を部分写像（`Option` を返す関数）として書き、`@[std_abs]` を付けた定数そのものを渡す。aₒ には核の定理（`KernelIs`）を課す。OJ・OO は観測型の差異の成分（`obs_DNNN`）で、無ければ省く |
| `InitSurj` | [Spec] の初期状態（fixture の 1 点。SPEC-007）に、`J` で結ばれる [Source] の初期状態がある |
| `Sound`・`InitIs` | [Spec] の基底の機械が `Sound`（SPEC-002・003）で、初期状態が 1 点である（SPEC-007）。INV が空にならない |
| `Pinned` | [Source] の正常終了は、環境の選択を [Source] の入力の環境 `ce` に固定した [Spec] の結果で模倣される。`ce` は `@[std_abs]` を付けた標準の抽象化（下の表の「環境」の行）とする |
| `NoFaultReachable` | [Spec] の各入力は、障害の無い環境（`ce` が標準の環境を返す）の [Source] の入力でも実現される。障害の無い環境では、[Source] は `Conflict`・I/O 失敗の結果（N-001・N-002）を返せない |
| `StateSafe` | 「出力のみ」の前提型の差異（[前提型の差異の影響](#前提型の差異の影響)）ごとに、前提を破る 1 歩の後も状態が `J` を保つ |
| 入口の全域性 | [入口の R 課題](#入口の-r-課題) の [Spec] の機械は、INV と環境の前提（`@[env_pre]`）の下で PRE が成り立つ（`TotalUnder`。SPEC-006）。環境の前提は、マスタ・設定の妥当性（MD-1〜MD-8）と入力の値域（[domain-model.md](domain-model.md#値域)）を入力の成分だけで書いたものとする。R 課題には、環境の前提を満たす像を持つ [Source] の入力があること（`EnvWitness`）も課す |
| 成分の必要性 | R 課題で使う前提型・観測型の差異の ID ごとに、その差異を外した R 課題の命題が偽であることを示す（[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)。検査は TR-G の G9）。<br>- 前提型: `restrict` の層を外す<br>- 観測型: 成分を `never` に替える（重なる観測型の差異は `Machine.Preserves.anyOf` で並べ、葉ごとに替える）<br>- 否定する命題: `Refines`。基底が `Machine.ofChoice` なら `Refines ∧ Pinned` でもよい<br>少なくとも 1 つの R 課題について示せばよく、W 課題に含める。他の必要な差異に覆われる差異（例: D-012 は D-001・D-002 に覆われる）は、同じ R 課題で `Covers` を示す。`@[deviation]` の定数には ID を 1 つだけ付ける |

- [Source] の各操作は、マスタ・設定と環境（衝突が起きるか、どのポート操作が I/O で失敗するか、配備の設定）を入力の成分として受ける。原典がマスタを DB から読む場合も、マスタは不変なので状態に含めず入力とする。
  - aᵢ は環境を落とす。
  - 環境を [Spec] の環境の選択へ写す関数を `ce` とする。
- 前提型の差異の述語の置き方は 3 つである。
  - 抽象側の入力: `restrict`
  - 抽象側の状態と入力: `restrictState`
  - 具体側だけにある入力: `Concrete.restrict`
- 具体側の状態の述語（例: D-009 のシーケンスの上限）は、`J` で対応する抽象側の状態の述語に書き直して `restrictState` で置く（`World.sequences` は [Source] のシーケンスと `J` で一致する）。
- 具体側の不変条件 `Ic` は仮定ではない。初期化（`InitSurj`）で成り立ち、正しさの義務で `J` とともに保たれることを示すので、到達可能な状態についての証明済みの不変条件である。

## 抽象化関数 α

`J`・`αᵢ`・`αₒ` は、次の表の標準の抽象化と、観測型の差異の名前付き成分だけで組み立てる。各行は Lean では `@[std_abs]` を付けた部分写像（葉）とし、「同一視するもの（核）」を L 課題 `KernelIs` で示す。定義域の上で単射な部分写像の核は、汎用の核 `Machine.Kernel.undefOrEq`（スキルの `Machine.Kernel`）（どちらも定義されないか、等しい）をその葉に適用して書く（[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）。核に当たる値の違いは、リファインメントでは観測されない。

| [Source] の値 | α | 同一視するもの（核） | 備考 |
| --- | --- | --- | --- |
| `int`（`LangSemantics.Java` の int32） | 数学的整数（`toInt`） | なし（単射） | 値域内では非負なら `Nat` |
| `double`（`JDouble`） | 有理数（有限値のみ） | +0 と −0 | NaN・∞ には α を定義しない。到達しないことを適用可能性で示す |
| `String`（UTF-16） | Unicode スカラ値の列 | なし（単射） | 不対サロゲートを含む文字列には α を定義しない。扱いは NaN と同じ |
| `LocalDate` | `Date` | なし（単射） | |
| `null` を含みうる参照 | `Option` | なし（単射） | |
| 例外 | `AtrsError`（[errors-and-messages.md](errors-and-messages.md)） | 同じコード・引数を持つ例外のクラスの違い | `IllegalArgumentException`/`NullPointerException`（`PreconditionViolation`）は α を定義しない。PRE の下で到達しないことを示す |
| SQL 照会結果（`LangSemantics.Sql` のバッグ・許される順列の集合） | 列（順列ごとに写す関係） | なし（各順列を単射に写す） | 正しさの義務は、許される順列のすべてについて示す |
| 要求（HTTP の要求文字列・JSON） | `Spec.Http` の要求 | [Spec] の要求が持たない部分（ヘッダの順序・名前の大小など） | 全域。不対サロゲートのエスケープを含む JSON は、D-026 の前提で除外する |
| 環境（衝突が起きるか・どのポート操作が I/O で失敗するか・配備の設定） | [Spec] の環境の選択（N-001〜N-003）。`ce` として書く | なし（単射） | 障害の無い環境は、標準の環境に写す |
| 応答（HTTP の状態・遷移先・画面の値・JSON） | `Spec.Http` の応答 | [http-contract.md](http-contract.md) が定めない部分（HTML の構造など。[ADR 84bf](../decision/84bf-porting-scope.md) で範囲外） | 画面の値は、[http-contract.md](http-contract.md) が定める項目だけを写す |
| マスタの表の行（`INT`・`DATE`・`VARCHAR`。ABS-026） | `Spec.MasterData` の各要素（`Abstraction.MasterData.Alpha.airportOfRow` ほか。値の葉は `natOfInt4`・`dateOfPg`・`hmOfStr`・`bcCdOf`・`ftCdOf`） | 区間の `FLIGHT_TIME`（`routeRowKer`）。ほかは定義域の上で単射（`undefOrEq`） | 負の数、1〜9999 年の外の日付、`HHmm` でない時刻、未知のコード、`NULL` の搭乗クラス名には定義しない（D-027） |
| 注入された設定（`AtrsConfig`） | `Spec.Config`（`configOf`。生年月日の下限は `dateOfSlash`） | なし（定義域の上で単射） | 負の数・`yyyy/MM/dd` でない日付には定義しない（D-027） |
| マスタの参照の問い合わせ・答え（ABS-026） | `Spec.MasterQuery.Query`・`Answer`（`queryOf?`・`answerOf?`） | 問い合わせはなし（`undefOrEq`）。答えは、区間の空港名・空港の表示順、便マスタの区間の運賃・空港、機材の座席数（`answerKer`。[Spec] が観測しない成分） | 範囲外の `LocalDate` には定義しない（D-027） |
| 運賃計算の入力・出力（ABS-001・ABS-002・ABS-004） | `Spec.Fare.BasicFareInput`・`FareInput`・`TotalFareInput`、出力は `Nat`（`aiBF`・`aiF`・`aiTF`・`natOfJ32`。選択フライト情報は `keyOfForm`、搭乗者は年齢 `ageOfPassenger`） | なし（`natOfJ32` は `undefOrEq`）。合計金額は、搭乗者の年齢以外の成分を観測しない | 引数の `null` と負の値には定義しない（D-027）。マスタ・設定は ABS-026 の `masterDataOf`・`configOf` で写す |

## 既知差異

[Spec] と [Source] が一致しない点である。種類は [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#差異) による。

登録簿の正は Lean の `Abstraction.Gap`（ID ごとの `@[gap_entry]` の宣言。[ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)）である。本節と次の 3 つの小節の表は、`trace manifest` がそこから生成する。行を足す・直すときは、`lean/Abstraction/Gap.lean` を書き換えて表を再生成する。ギャップが生じる `Spec`・`SourceModel` の定義には、箇所の印 `@[gap "D-NNN"]` を付ける（検査 TR-K。上流の版上げでは、印の付いた定義の変化から見直すギャップを `trace impact` が出す）。

- **前提型**: 主定理の名前付きの仮定（Lean 名は `Abstraction.<機能>.dev_DNNN`）
- **観測型**: `J`/`αₒ` の名前付きの成分（Lean 名は `Abstraction.<機能>.obs_DNNN`）。前提型・観測型には、R 課題と W 課題（`ABS-1NN` が `D-0NN` の証拠）が必須である
- W 課題は両向きの例と、差異の必要性を示す（[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）。
  - 両向きの例（Lean では `Nontrivial`・`Nontrivial₂`）
    - 前提型: 前提を満たす例と、前提を破る例
    - 観測型: 成分が関係づける例（標準の抽象化では関係しない出力）と、関係づけない例
  - 必要性: 差異を外した R 課題の命題が偽である（[空虚化を防ぐ義務](#空虚化を防ぐ義務) の「成分の必要性」）。前提型では、前提を破り、R 課題の他の差異の前提を満たし、[Source] と [Spec] が一致しない入力が、その証人になる。他の差異に覆われる差異では、必要性の代わりに被覆（`Covers`）を示す
- **モデル外**: Lean のどのモデルにも現れない差異。[Spec] の外の規範節と原典の違いがこれに当たる。証明には現れないので、[assurance.md](assurance.md) に限界として載せる
- **証明の状態**: ギャップは、リファインメントの証明の中で証明できない部分である。公理や `sorry` で仮定せず、登録簿の `evidence` に状態を書き、状態を裏付ける宣言に `@[gap "D-NNN"]` を付ける（[ADR 6ab4](../decision/6ab4-gap-evidence-states-without-axioms.md)）。表の「証明の状態」の列はこれを示す。
  - 偽を証明済み（`refuted`）: 差異を外した R 課題の否定の定理（W 課題）がある
  - 被覆（`covered`）: 必要な差異がこの差異を覆う定理（`Covers`）がある
  - 未証明（`pending`）: 前提で制限したが、必要性も一致もまだ示していない。Lean に述語がまだ無い差異もこれに当たる（段階導入。登録の backlog が完了したら誤り）
  - 形式化していない（`unformalized`）: 命題として書けない。主張は証明も公理も持たない `opaque` の命題（`Abstraction.Gap.claim_DNNN`）で、どの定理からも参照しない
  - PRE の外（`excludedBy`）: 差異ではない。前提の述語（`Spec.MasterData.MD7` など）に印がある

<!-- BEGIN GENERATED: gaps-known -->
`trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。

| ID | 種類 | 箇所 | 差異 | 前提（前提型）／成分（観測型） | R 課題 | W 課題 | 証明の状態 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D-001 | 前提型 | [基本運賃](fare-calculation.md#基本運賃) | [Source] は `(ratio * 0.01)` を double で掛けて切り捨てる。[Spec] は `floorDiv(x * ratio, 100)`。[Source] は [Spec] に等しいか 1 小さい。1 小さいのは、`x·ratio` が 100 で割り切れ（厳密値が整数）、積算比率の因子 `fl(ratio × fl(0.01))` が `ratio/100` を `2^-54` 以上下回る（安全でない）ときに限る（`Abstraction.Fare.Factors.basicFare_src`）。安全でない積算比率は 1〜1000 のうち 49 個（29, 58, 116, 117, 141, 205, …。`basicFactor_unsafe`）で、シードの比率（100・110・120・125・130・140・150）は安全である。条件は十分条件で、安全でない比率でも差異が起きるとは限らない（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） | `dev_D001`（`Abstraction.Fare`。抽象側の入力の述語）: `x = routeBasicFare + extraCharge`・`ratio` = 出発日の積算比率について、`x·ratio` が 100 で割り切れないか、`ratio` が安全でない積算比率の一覧 `unsafeBasicRatios` に無い（`basicFare_src_eq'`）。合計金額では、各フライトに同じ条件を課す（`dev_D001T`）。空席照会では、搭乗日が照会可能期間の内で区間があるとき、照会の区間・搭乗クラス・搭乗日に課す（`dev_D001S`） | ABS-001, ABS-004, ABS-011, ABS-031, ABS-041, ABS-045 | ABS-101 | 偽を証明済み（`need_D001`） |
| D-002 | 前提型 | [運賃](fare-calculation.md#運賃) | [Source] は `1 - rate*0.01` の丸め誤差により、厳密値が整数 `k` で `k ≡ 1 (mod 100)` のとき、切り捨てた値が `k − 1` になって 100 円少なくなる（例: 1430 円・30% で [Source] 1000、[Spec] 1100）。[Source] は [Spec] に等しいか 100 円少なく、少ないのは `b·(100−r) ≡ 100 (mod 10000)` で、割引率の因子 `fl(1 − fl(r × fl(0.01)))` が安全でないときに限る（`Abstraction.Fare.Factors.fare_src`）。安全でない割引率は 0〜99 のうち 33 個（6, 7, 30〜35, 53〜57, 65〜70, 77〜83, 89〜95。`fareFactor_unsafe`）で、シードの割引率 0・5・10・20 は安全、30 は安全でない（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） | `dev_D002`（`Abstraction.Fare`。抽象側の入力の述語）: `b·(100−r) mod 10000 ≠ 100` か、`r` が安全でない割引率の一覧 `unsafeDiscountRates` に無い（`fare_src_eq'`）。合計金額では、各フライトに同じ条件を課す（`dev_D002T`）。空席照会では、搭乗日が照会可能期間の内で区間があるとき、照会の基本運賃と、照会の片道・往復の運賃種別のすべての割引率に課す（`dev_D002S`。候補に現れない運賃種別にも課す十分条件） | ABS-002, ABS-004, ABS-011, ABS-031, ABS-041, ABS-045 | ABS-102 | 偽を証明済み（`need_D002`） |
| D-006 | 前提型 | [文字列長](input-validation.md#文字クラス)・[ログインの事前検査](authentication.md#ログインlogin)・[レポート要求の長さ](reservation-history-report.md#要求の受信onreportrequested) | [Source] は UTF-16 単位、[Spec] はスカラ値単位で長さを数える | `dev_D006`: 入力が補助文字（U+10000 以上）を含まない | ABS-031, ABS-034, ABS-042, ABS-043, ABS-044, ABS-045, ABS-046 | ABS-106 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-007 | 前提型 | [REST 予約 API](http-contract.md#post-apiv1ticket) | [Source] は相関検証を適用しない（原典の不具合）。[Spec] は相関検証を適用し、さらに搭乗者リストの要素数を 1〜6 に制限する（[input-validation.md](input-validation.md#予約入力b2)） | `dev_D007`: 入力が相関検証を満たし、搭乗者が 1〜6 名 | ABS-031 | ABS-107 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-008 | 観測型 | [表示名](errors-and-messages.md#項目の表示名) | [Source] の表示名「登場クラスコード」は誤記。[Spec] は「搭乗クラスコード」 | `obs_D008`: エラーメッセージの表示名の対応で、[Source] の「登場クラスコード」を [Spec] の「搭乗クラスコード」に対応させる | ABS-031, ABS-045, ABS-046 | ABS-108 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-009 | 前提型（具体側の状態） | [採番](ports.md#idgenerator) | [Source] のシーケンスは最大値の後に 1 へ循環し、使用済みの値を返しうる。[Spec] は常に未使用の値を返す | `dev_D009`: [Source] の各シーケンスが最大値に達していない | ABS-021, ABS-031, ABS-041, ABS-042, ABS-045 | ABS-109 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-011 | 前提型 | [Email](input-validation.md#email) | [Source] はドメイン部を `IDN.toASCII` で変換し、失敗すれば不合格とし、変換後の長さで 255 を判定する。[Spec] は変換しない（[ADR ac33](../decision/ac33-email-validation-rule.md)） | `dev_D011`: ドメイン部が ASCII だけからなる | ABS-031, ABS-034, ABS-042, ABS-045, ABS-046 | ABS-111 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-012 | 前提型 | [合計金額](fare-calculation.md#合計金額) | [Source] の小児分の途中計算 `j32mul(b, childFareRate − r)` は、`b × (childFareRate − r) > 2,147,483,647` のとき int32 で折り返す（値域の上限 `b = 100,000,000` では最大 約 1e10）。[Spec] は任意精度 | `dev_D012`（`Abstraction.Fare`。抽象側の入力の述語）: 各フライトで、基本運賃 `b`・割引率 `r` について `b × (childFareRate − r) ≤ 2,147,483,647`（小児がいなくても課す十分条件） | ABS-004, ABS-031, ABS-041, ABS-045 | ABS-112 | 偽を証明済み（`need_D012`） |
| D-013 | モデル外 | [会員情報変更](member.md#会員情報変更update)・[トランザクション](ports.md#トランザクション)（規範節） | [Source] は、現在パスワードの照合と更新を別のトランザクションで行う。[Spec] は 1 トランザクションで行う（[ADR 578b](../decision/578b-member-update-in-single-transaction.md)）。違いが観測できるのは並行実行のときだけである。各モデルは各ユースケースを 1 つの原子的な操作として扱うので、[Source] の具体機械でも 1 つの操作として写す | — モデル外（並行実行はモデルに現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)） | — | — | 形式化していない（`claim_D013`） |
| D-014 | 前提型（具体側の環境） | [Clock](ports.md#clock) | [Source] は `today()` を呼ぶたびに現在日付を読む。そのため、日付をまたいで実行されたユースケースの中で今日が変わりうる。[Spec] はユースケースの初めに 1 回だけ読む | 1 つのユースケースの中で、[Source] の Clock の各呼び出しが同じ日付を返す（機能ごとの具体側の環境の述語）。空席照会では `dev_D014S`（`Abstraction.FlightSearch.Alpha`）: `TicketSharedServiceImpl` の `validateDepatureDate`・`getSearchLimitDate` が読む今日の日付が、`searchFlight` の今日の日付と同じ | ABS-011, ABS-031, ABS-041, ABS-044, ABS-045 | ABS-114 | 偽を証明済み（`need_D014`） |
| D-016 | モデル外 | [セッション](http-contract.md#セッション)（規範節） | [Source] はログイン時にセッション ID を変えない（セッション固定化の対策が無い）。[Spec] は新しい ID に変える | — モデル外（セッション ID は [Spec] の外の規範節で定め、どのモデルにも現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)） | — | — | 形式化していない（`claim_D016`） |
| D-017 | 前提型 | [ログイン成功時の遷移先](http-contract.md#認証と権限) | [Source] は `redirectTo` の絶対 URL（外部サイト）へもリダイレクトする。[Spec] はアプリ内のパスだけを受け付ける | `dev_D017`: `redirectTo` が無いか、`/` で始まり `//` で始まらない | ABS-045 | ABS-117 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-018 | 前提型 | [Min/Max](input-validation.md#文字クラス)・[creditTerm](domain-model.md#member) | [Source] は文字列の `Min`・`Max` を `BigDecimal` として判定する（`"1.5"`, `"+1"`, `"1e1"` も数になる）。`creditTerm` が 6 文字以上なら、DB の `VARCHAR(5)` 違反でシステムエラーになる（会員登録・会員情報変更）。[Spec] は十進整数だけを数とし、長さの上限を持たない | `dev_D018`: `creditMonth`・`creditYear` が `[0-9]+` で、`creditTerm` が 5 文字以下 | ABS-031, ABS-034, ABS-042, ABS-045, ABS-046 | ABS-118 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-019 | 前提型（具体側の入力） | [支払期限の表示](domain-model.md#書式) | [Source] は曜日を要求のロケールで表示する（テンプレート `tmpl:` の書式処理）。[Spec] は常に日本語で表示する | `dev_D019`: `Accept-Language` が日本語 | ABS-045 | ABS-119 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-020 | 前提型 | [予約入力画面の表示](http-contract.md#b2-予約) | `GET /ticket/reserve?form` で、便名・搭乗日・搭乗クラス・運賃種別の欠落や、マスタに無い値を渡すと、[Source] は `NullPointerException`・`Assert` で 500 を返す。[Spec] は `InvalidRequest` で 400 を返す（[Spec] が振る舞いを定める入力なので PRE の内） | `dev_D020`: 選択フライトの全項目（便名・搭乗日・搭乗クラス・運賃種別）が与えられ、それぞれマスタで解決できる | ABS-045 | ABS-120 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-021 | 前提型 | [日付の解析](input-validation.md#日付の解析) | [Source] は、符号付きの 5 桁以上の年（`+10000/01/01`）と 0 以下の年も受け付ける。[Spec] は 4 桁の年 1〜9999 だけを受け付ける | `dev_D021`: 年が符号無しの 4 桁で 1 以上 | ABS-031, ABS-045, ABS-046 | ABS-121 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-022 | 観測型 | [入力検証エラーの並び](input-validation.md)・[ADR e24e](../decision/e24e-validation-error-ordering.md) | [Source] の単項目の検証エラーは順序不定（Bean Validation の `HashSet`）。[Spec] は定順の列。[Source] のほうが非決定性が大きいので、エラーの列を多重集合として比べる成分を、名前付きで置く | `obs_D022`: 検証エラーの列を多重集合として対応させる | ABS-031, ABS-045, ABS-046 | ABS-122 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-023 | モデル外 | [Clock](ports.md#clock)・[ADR 9ee4](../decision/9ee4-clock-timezone-and-fixture-base-date.md) | [Spec] の本番の Clock は Asia/Tokyo で今日を決める。[Source] は JVM の既定のタイムゾーンで決める | — モデル外（各モデルは「今日」を入力として受け取る。オラクルは JST で実行する。[assurance.md](assurance.md#移植元ソース--sourcemodel)） | — | — | 形式化していない（`claim_D023`） |
| D-024 | モデル外 | [セッションの Cookie 属性](http-contract.md#セッション)（規範節） | [Spec] は `HttpOnly` を付け、`Secure`・`SameSite` は配備環境で決める。[Source] は `HttpOnly` だけを付ける | — モデル外（[assurance.md](assurance.md#移植元ソース--sourcemodel)） | — | — | 形式化していない（`claim_D024`） |
| D-025 | モデル外 | [トランザクション](ports.md#トランザクション)（規範節）・[ADR 97f9](../decision/97f9-persistence-and-transaction-semantics.md) | [Spec] は状態変更の直列化可能性を要求する。[Source] は PostgreSQL の READ COMMITTED で動き、一般には直列化可能でない（会員情報変更の事例は D-013 としてモデルに写す） | — モデル外（モデルでは操作は原子的である。[assurance.md](assurance.md#移植元ソース--sourcemodel)） | — | — | 形式化していない（`claim_D025`） |
| D-026 | 前提型（具体側の入力） | [REST API](http-contract.md#rest-apiapiv1) | [Source]（Jackson）は、JSON の文字列にある不対サロゲートのエスケープ（例 `"\ud800"`）を受け付け、不対サロゲートを含む文字列として処理する。[Spec] の文字列はスカラ値の列なので、その要求を `InvalidRequest` とする | `dev_D026`: 要求の JSON の文字列に、不対サロゲートのエスケープを含まない | ABS-031, ABS-045 | ABS-126 | 未証明（Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手） |
| D-027 | 前提型（具体側の入力） | [マスタ](master-data.md)・[設定](configuration.md)・[空席照会の状態（FLIGHT 表）](ports.md#world抽象状態) | [Source] は、DB のマスタと注入された設定を起動時に読み込み、問い合わせの引数（`LocalDate` など）を受ける。値が [Spec] の型で表せないとき、[Source] は例外で起動しないか（未知の搭乗クラス・運賃種別のコード）、そのまま読み込む（`BOARDING_CLASS_NAME` の `NULL`、負の値・値域を超える値、`HHmm` で表せない時刻（到着時刻は翌日の 23:59 を超えるもの。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）、範囲外の日付、`yyyy/MM/dd` でない生年月日の下限など）。[Spec] はそれらを入力に取らない。列の型は処理系の範囲（`Int4`・`PgDate`・`Varchar n`）で写すので、範囲の違いもこの差異の前提で扱う（[ADR c108](../decision/c108-master-data-source-model-and-spec-fixes.md)） | `dev_D027`（`Abstraction.MasterData`）: 具体側の入力（DB のマスタの各行・設定・問い合わせの引数）が、[Spec] の型で表せる（`aiMQ` が定義される）。問い合わせの日付が [Spec] の暦日（1〜9999 年）を超える場合を含む（[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）。運賃計算では、`dev_D027BF`（基本運賃。DB のマスタ・設定・`calculateBasicFare` の引数。`aiBF` が定義される。`null` と負の値を含まない）・`dev_D027F`（運賃。`calculateFare` の引数が負でない）・`dev_D027TF`（合計金額。DB のマスタ・設定・選択フライト情報・搭乗者。`aiTF` が定義される）（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)）。空席照会では、状態の表 FLIGHT の各行も [Spec] の型で表せる（`Abstraction.FlightSearch.Alpha.worldOfDb` が定義される。負の空席数・未知のコード・暦日の外の日付を含まない）。照会は状態を変えないので、初期状態（シードの FLIGHT 表）が前提を満たせば、到達する状態も満たす。初期状態が満たすこと（`Abstraction.FlightSearch.Init.worldOfDb_seed`）は backlog 0be7 の第 3 段で示した。空席照会の入力の述語は `dev_D027S`（`aiS` が定義される）。種類は「具体側の入力」のままとし、状態の部分は貼り合わせの部分写像（α が定義されない状態は `World` と結ばれない）で表す（[ADR cdb6](../decision/cdb6-flight-search-stage2-machines-seed-sql.md)） | ABS-001, ABS-002, ABS-004, ABS-011, ABS-026 | ABS-127 | 偽を証明済み（`need_D027`） |
| D-031 | 前提型 | [往復の便の検査](reservation.md)・[便マスタの到着時刻](master-data.md) | [Source] の往復の予約の検査（`validateFlightDepartureDateForRoundTripFlight`）は、往路便の到着時刻を `DateTimeFormatter("HHmm")`（SMART）で読むので、到着時刻が 24:00 より後（翌日着。シードの NTT523・NTT528 の `2415`）の便では `DateTimeParseException` を投げる。`2400` は例外にならず、翌日 0:00 でなく当日 0:00 と読まれる（往路便の到着日時が 1 日早くなる）。[Spec] は到着時刻を出発日 0:00 からの時分で表し、往路便の到着日時を求められる （[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。空席照会は到着時刻を文字列として整形するだけなので、 この差異は起きない | `dev_D031`（抽象側の入力の述語）: 往復の予約で、往路便の便マスタの到着時刻が 24:00 より前である | ABS-021, ABS-041 | ABS-131 | 未証明（Lean に述語がまだ無い。予約の `SourceModel` と R 課題が未着手） |
| D-032 | 前提型（具体側の環境） | [空席照会の運賃の書式](flight-search.md#出力-flightvacantinfo) | [Source] の空席照会は、運賃を `new DecimalFormat("###,###")` で書式化する。区切り文字は JVM の既定の書式ロケール （`Locale.getDefault(Locale.Category.FORMAT)`）で決まる（例: ドイツ語では `20.600`）。[Spec] は常に `,` で区切る（`fmtYen`）。 モデル `SourceModel.FlightSearch.createFlightVacantInfoList` は、区切り文字を配備の環境 `groupingSeparator` として受ける | `dev_D032`（`Abstraction.FlightSearch.Alpha`。具体側の入力の述語）: [Source] の JVM の既定の書式ロケールの 3 桁区切りの文字（`SearchInput.groupingSeparator`）が `,` である（日本語・英語のロケール） | ABS-011 | ABS-132 | 偽を証明済み（`need_D032`） |
<!-- END GENERATED: gaps-known -->

### 前提型の差異の影響

前提型の差異の前提を破る 1 歩の後で、状態が `J` を保つかどうかによる分類である（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)）。分類は人の判断であり、迷う場合は「中断」とする（[assurance.md](assurance.md#モデル間の保証の限界)）。backlog の列は、その差異の W 課題を完了させる項目である（段階導入。[traceability.md](../../.agents/skills/spec-pivot/references/docs/spec/traceability.md#検査)）。

- **出力のみ**: 前提を破っても、変わるのは出力だけである。R 課題に `StateSafe` を課す。
- **中断**: 前提を破ると、[Source] の状態が [Spec] から離れうる。その後の軌跡は保証されない（[assurance.md](assurance.md#モデル間の保証の限界)）。

<!-- BEGIN GENERATED: gaps-impact -->
`trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。

| ID | 影響 | 理由 | backlog |
| --- | --- | --- | --- |
| D-001 | 中断 | 予約確定で、差のある運賃が合計金額として保存される | bbcce088-c475-4378-9cc6-e3d821acc0f5 |
| D-002 | 中断 | 同上 | bbcce088-c475-4378-9cc6-e3d821acc0f5 |
| D-006 | 中断 | 入力検証の合否が変わり、会員登録・会員情報変更・レポート要求の成否が変わる | 4e0e3dd1-d282-46e2-aa98-719853bc9fd2 |
| D-007 | 中断 | [Source] は [Spec] が拒む予約を登録する | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| D-009 | 中断 | 使用済みの番号による挿入の失敗、または既存の行との衝突 | aedfeffc-3e82-46b1-b497-3d8b7808d068 |
| D-011 | 中断 | 入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる | 4e0e3dd1-d282-46e2-aa98-719853bc9fd2 |
| D-012 | 中断 | 折り返した合計金額が保存される | bbcce088-c475-4378-9cc6-e3d821acc0f5 |
| D-014 | 中断 | 日付をまたぐと、予約・レポートに記録される日付が変わりうる | aedfeffc-3e82-46b1-b497-3d8b7808d068, 0be7c5d4-01d9-43f4-a50d-227f174830f0 |
| D-017 | 出力のみ | ログインの成否と状態更新は同じで、遷移先だけが異なる | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| D-018 | 中断 | 入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる | 4e0e3dd1-d282-46e2-aa98-719853bc9fd2 |
| D-019 | 出力のみ | 曜日の表示だけが異なる | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| D-020 | 出力のみ | 予約入力画面の表示（状態を変えない `GET`）の応答だけが異なる | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| D-021 | 中断 | 入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる | 4e0e3dd1-d282-46e2-aa98-719853bc9fd2 |
| D-026 | 中断 | [Source] は [Spec] が拒む要求を処理し、状態を変えうる | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| D-027 | 中断 | [Source] は起動しないか、[Spec] の型で表せないマスタ・設定で動き続ける | 25f7ef96-f77d-4ed8-973d-8cecc2a0f227, bbcce088-c475-4378-9cc6-e3d821acc0f5 |
| D-031 | 中断 | 翌日着の便を往路とする往復の予約が、500 システムエラーになる（`2400` なら往路便の到着日時を 1 日早く検査する） | 0be7c5d4-01d9-43f4-a50d-227f174830f0, aedfeffc-3e82-46b1-b497-3d8b7808d068 |
| D-032 | 出力のみ | 空席照会の運賃の表示だけが異なる | 0be7c5d4-01d9-43f4-a50d-227f174830f0 |
<!-- END GENERATED: gaps-impact -->

### [Spec] の前提の外での [Source] の振る舞い（差異ではない）

次は、[Spec] の PRE・INV の外での [Source] の振る舞いである。B メソッドのリファインメントでは、PRE の外の振る舞いに義務は無い。したがって差異ではない（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#リファインメント具体機械が抽象機械をリファインする)）。ID は過去に既知差異として付けたものを保つ。ID の無かった行には D-029・D-030 を割り当てた（[ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)）。主定理は、これらに差異の仮定を置かない。登録簿では種類「PRE の外」とし、箇所の印を付ける。

<!-- BEGIN GENERATED: gaps-outside-pre -->
`trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。

| ID | 箇所 | [Source] の振る舞い | [Spec] の前提 |
| --- | --- | --- | --- |
| D-003 | [合計金額](fare-calculation.md#合計金額) | `discountRate > childFareRate` のとき小児分が負になり、0 方向に切り捨てる | PRE MD-7 |
| D-004 | [ピーク時期](master-data.md#参照関数) | 期間が重なる場合、取得順（未規定）で最初に一致したものを使う | PRE MD-4 |
| D-005 | [空席照会の集約](flight-search.md#searchflight) | 同一区間に同じ出発時刻の便があると、1 グループに統合し、運賃種別ごとに後勝ちになる | PRE MD-5 |
| D-010 | [更新件数](reservation.md#予約確定reserve)・[ログイン](authentication.md#ログインlogin)・[会員登録](member.md) | 登録・更新の件数 ≠ 1 で `System("e.ar.a0.L9002")` になる | `J` と INV（キーが存在する）。到達しないことは ABS-022 で示す |
| D-015 | [マスタの不変条件](master-data.md#不変条件spec) | MD-1〜MD-3 が破れると、後勝ちの上書きか、`null` による前提違反になる | PRE MD-1〜MD-3 |
| D-029 | [空港コードリスト](master-data.md#空港コードリスト画面用) | コードが区切り行と同じ `NOP` の空港があると、`LinkedHashMap` の同じキーへの `put` で、区切り行の表示がその空港の名前に置き換わり、空港の行は現れない | PRE（MD-8: 空港のコードは `NOP` でない。[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)） |
| D-030 | [値域](domain-model.md#値域) | マスタ・入力が値域の外のとき、int32 で折り返す | PRE（入力の値域・MD-8） |
| D-033 | [空席照会の便マスタの参照](flight-search.md#事前条件) | 空白の便名の便マスタが空席照会の結果に現れると、[Source] は `getFlightMaster` の `Assert.hasText` で `IllegalArgumentException` を投げる。[Spec] は PRE で除く（照会の区間の便マスタに限る） | PRE `FlightNamesHaveText`（照会の区間の便マスタの便名が空白でない） |
<!-- END GENERATED: gaps-outside-pre -->

[Spec] が型で除外している入力での [Source] の前提違反（`Assert`・`NullPointerException`）も、同じ扱いとする（例: [fare-calculation.md](fare-calculation.md)、[reservation.md](reservation.md)、[flight-search.md](flight-search.md)、[member.md](member.md) の [Source] の前提違反）。ただし、これは HTTP の要求から到達できない入力に限る。`Spec.Http` はすべての要求文字列に応答を定めるので、HTTP から到達できる前提違反は PRE の内である。その場合は、前提型の差異として登録する（例: D-020）か、L 課題 ABS-047 で到達しないことを示す。

### 未確定の差異

<!-- BEGIN GENERATED: gaps-undetermined -->
`trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。

| ID | 対象 | 状況 | 確定させる作業 | 証明の状態 |
| --- | --- | --- | --- | --- |
| D-028 | [ログイン時の状態更新](authentication.md#ログインlogin)（`loginDateTime`・`loginFlg`） | [Source] で更新されない可能性がある（認証イベントが発行されない構成）。オラクルで確かめた結果に応じて、D-0NN（前提型または観測型）として登録するか、差異が無いことを本表から消す | [backlog 44f8](../backlog/44f8-authentication-usecases.md) の完了条件 | 形式化していない（`claim_D028`） |
<!-- END GENERATED: gaps-undetermined -->

## 証明課題

種類は次の 4 つである（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#証明課題の種類)）。

- R: リファインメントの主定理（`Machine.Refines`）と、束（`Machine.Preserves`。`InitSurj`、基底が `Machine.ofChoice` なら `Pinned`、出力のみの差異の `StateSafe` などを成分に持つ）。束は同じ課題 ID に含める
- W: 差異の証拠（両向きの例と、差異の必要性）
- C: 差異の特徴付け
- L: 補題

| ID | 種類 | 内容 | 差異 |
| --- | --- | --- | --- |
| ABS-001 | R | 基本運賃の計算: `dev_D001`・`dev_D027BF` の下で、[Source]（起動時の読み込みと `calculateBasicFare`。`SourceModel.FareQuery.basicFareConcrete`）が `Spec.Fare.basicFareMachine` をリファインする。Mapper の結果のどの許される並びでも成り立つ。Lean: `Abstraction.Fare.basicFareRefines` | D-001, D-027 |
| ABS-002 | R | 運賃の計算: `dev_D002`・`dev_D027F` の下で、[Source]（`calculateFare`。`SourceModel.FareQuery.fareConcrete`）が `Spec.Fare.fareMachine` をリファインする。Lean: `Abstraction.Fare.fareRefines` | D-002, D-027 |
| ABS-003 | C | 値域内で `fare_Spec − 100 ≤ α(fare_Source) ≤ fare_Spec`（[Source] は [Spec] に等しいか 100 円少ない）。Lean: `Abstraction.Fare.fare_diff` | D-002 |
| ABS-004 | R | 合計金額の計算: `dev_D001T`・`dev_D002T`・`dev_D012`・`dev_D027TF` の下で、[Source]（起動時の読み込み・`TicketHelper.toFlightList`・`calculateTotalFare`。`SourceModel.FareQuery.totalFareConcrete`）が `Spec.Fare.totalFareMachine` をリファインする。Mapper の結果のどの許される並びでも成り立つ。Lean: `Abstraction.Fare.totalFareRefines` | D-001, D-002, D-012, D-027 |
| ABS-005 | L | 値域内で、`dev_D001T`・`dev_D002T`・`dev_D012` の下では、[Source] の合計金額の計算は例外も int32 の溢れも無く、[Spec] の合計金額を返す（ABS-004 の適用可能性と正しさに使う）。前提 `dev_D012` が破れる入力では、小児分の途中計算だけが折り返す（ABS-112）。Lean: `Abstraction.Fare.TotalFareRun.runTotalFare_eq` | D-012 |
| ABS-006 | — | 取り消し。ピーク時期の参照 `peakTimeOn` の一致は ABS-026 に含めた（ID は再利用しない。[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） | — |
| ABS-007 | L | 値域内で、[Source] の基本運賃は [Spec] に等しいか 1 小さく、1 小さいのは `x·ratio` が 100 で割り切れ、積算比率の因子が安全でないときに限る。値域全体での一致は成り立たない（反例は ABS-101。[ADR e9bc](../decision/e9bc-fare-double-analysis.md)）。Lean: `Abstraction.Fare.BasicFareRun.runBasicFare_spec`（`calculateBasicFare` について。中身は `basicFare_src`） | D-001 |
| ABS-010 | L | `isAvailableFareType` と SQL 条件 `beforeDayNum BETWEEN end AND start` の同値。Lean: `Abstraction.FlightSearch.Period.isAvailableFareType_between` | — |
| ABS-011 | R | 空席照会 `searchFlight`: PRE（MD-5）と、運賃計算から引き継ぐ `dev_D001`・`dev_D002` の下で、[Source]（`LangSemantics.Sql` の照会＋Java の集約）の許されるすべての結果についてリファインする。具体側の入力は、マスタ・設定・照会の引数が [Spec] の型で表せること（D-027）を引き継ぐ。[Source] は 1 回の照会で Clock を 3 回読むので、D-014 の前提（同じ日付を返す。`dev_D014S`）を課す。区切り文字の前提 `dev_D032` も課す。Lean: `Abstraction.FlightSearch.searchRefines`（[ADR 0b0c](../decision/0b0c-flight-search-stage3-abs011.md)） | D-001, D-002, D-014, D-027, D-032 |
| ABS-020 | L | [Source] の予約確定の前後で、全フライトの `vacantNum ≥ 0`。失敗時は `sequences` を除いて状態が変わらない（ABS-041 の正しさに使う） | — |
| ABS-021 | R | 採番ポートの [Source] 実装（シーケンス）が、`dev_D009` の下で、[Spec] の採番の契約をリファインする | D-009 |
| ABS-022 | L | `J` と INV の下で、[Source] の `e.ar.a0.L9002` に到達しない（各ユースケースの適用可能性に使う） | — |
| ABS-023 | R | 予約・空席照会のリポジトリの [Source] 実装（`LangSemantics.Sql` で写した SQL）が、[ports.md](ports.md) の契約をリファインする | — |
| ABS-024 | R | 会員のリポジトリと `PasswordHasher` の [Source] 実装が、[ports.md](ports.md) の契約をリファインする。`SourceModel` は原典の `PasswordEncoder` を、raw について単射な符号化として写す。PBKDF2 の衝突を写さないことは、移植元ソース ⇔ `SourceModel` の限界である（[assurance.md](assurance.md)） | — |
| ABS-025 | R | `ReportStore`・`ReportQueue` の [Source] 実装が、[ports.md](ports.md) の契約をリファインする | — |
| ABS-026 | R | マスタ・設定・コードリストの読み込み（`SourceModel.MasterData`・`CodeList`・`Config` と、マスタの Mapper の SQL）が、[Spec] の `MasterData`・設定をリファインする（`dev_D027` の下で、読み込んだ値が MD-1〜MD-8 を満たすときに一致する。抽象側は `Spec.MasterQuery.queryMachine`、具体側は `SourceModel.MasterQuery.queryConcrete`。Mapper の文の結果のどの許される順列でも成り立つ）。書式（`SourceModel.Format`）は、それを使う R 課題（ABS-044・ABS-045・ABS-046）が覆うLean: `Abstraction.MasterData.queryRefines`。 | D-027 |
| ABS-030 | L | 補助文字を含まない文字列で `utf16Len = scalarLen` | D-006 |
| ABS-031 | R | REST 予約 API: `dev_D007`・`dev_D026` と、運賃計算・採番・Clock・入力検証から引き継ぐ仮定・成分の下でリファインする | D-001, D-002, D-006, D-007, D-008, D-009, D-011, D-012, D-014, D-018, D-021, D-022, D-026 |
| ABS-032 | L | ドメイン部が ASCII だけからなる文字列で、[Source] と [Spec] の Email 判定が一致する | D-011 |
| ABS-033 | L | 入力検証の [Source] の結果（多重集合）と [Spec] の結果（列）が、`obs_D022` で対応する | D-022 |
| ABS-034 | R | 会員情報変更: `dev_D006`・`dev_D011`・`dev_D018` の下でリファインする（[Source] の照合と更新は、1 つの原子的な操作として写す。D-013 はモデル外） | D-006, D-011, D-018 |
| ABS-040 | — | 廃止。ABS-041〜046 に分割した（ID は再利用しない） | — |
| ABS-041 | R | 予約のユースケース（予約確定・予約照会）: `dev_D009`・`dev_D014` と、運賃計算から引き継ぐ `dev_D001`・`dev_D002`・`dev_D012` の下でリファインする。`Conflict` と実行環境の失敗の結果を含む（[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)） | D-001, D-002, D-009, D-012, D-014 |
| ABS-042 | R | 会員のユースケース（会員登録・会員情報照会。会員情報変更は ABS-034）: `dev_D009`・`dev_D006`・`dev_D011`・`dev_D018` の下でリファインする | D-006, D-009, D-011, D-018 |
| ABS-043 | R | 認証のユースケース（ログイン・ログアウト）: `dev_D006` の下でリファインする | D-006 |
| ABS-044 | R | 予約履歴レポート（要求の受信・生成）: `dev_D006`・`dev_D014` の下でリファインする | D-006, D-014 |
| ABS-045 | R | HTTP の画面・API（`Spec.Http`。REST 予約 API は ABS-031）: `dev_D017`・`dev_D019`・`dev_D020`・`dev_D026` と、運賃計算・採番・Clock・入力検証から引き継ぐ仮定・成分の下でリファインする | D-001, D-002, D-006, D-008, D-009, D-011, D-012, D-014, D-017, D-018, D-019, D-020, D-021, D-022, D-026 |
| ABS-046 | R | 入力検証とエラーメッセージ: `dev_D006`・`dev_D011`・`dev_D018`・`dev_D021` の下で、`obs_D008`・`obs_D022` を含む `αₒ` でリファインする | D-006, D-008, D-011, D-018, D-021, D-022 |
| ABS-047 | L | HTTP の要求（画面と REST）から到達できる [Source] の前提違反（`Assert`・`NullPointerException`）に、各 R 課題の差異の前提の下では到達しないこと（ABS-031 は `dev_D026` の下、ABS-045 は `dev_D020`・`dev_D026` の下。適用可能性に使う） | D-020, D-026 |
| ABS-048 | L | 抽象化関数 α の表の各行（`@[std_abs]` の葉）について、核が表の「同一視するもの」と一致する（`KernelIs`） | — |
| ABS-101 | W | D-001 の証拠と必要性: 区間の運賃 100 円・加算料金 0・積算比率 29% で、[Source] 28、[Spec] 29。`dev_D001` を外すと ABS-001 は成り立たない（`Abstraction.Fare.need_D001`。式は `basicFare_witness`） | D-001 |
| ABS-102 | W | D-002 の証拠と必要性: 基本運賃 1430 円・割引率 30% で、[Source] 1000、[Spec] 1100。`dev_D002` を外すと ABS-002 は成り立たない（`Abstraction.Fare.need_D002`） | D-002 |
| ABS-106 | W | D-006 の証拠: 補助文字を含み、UTF-16 長とスカラ値長で検証の結果が異なる入力 | D-006 |
| ABS-107 | W | D-007 の証拠: 相関検証に違反する REST 予約の要求で、[Source] は受け付け、[Spec] は拒む | D-007 |
| ABS-108 | W | D-008 の証拠: 搭乗クラスコードの検証エラーで、標準の抽象化では表示名が一致せず、`obs_D008` で対応する | D-008 |
| ABS-109 | W | D-009 の証拠: シーケンスが最大値に達した状態で、[Source] が使用済みの値を返す | D-009 |
| ABS-111 | W | D-011 の証拠: 非 ASCII のドメイン部で、[Source] と [Spec] の判定が異なる入力 | D-011 |
| ABS-112 | W | D-012 の証拠と必要性: 基本運賃 1 億円（区間の運賃 1,000 万円・積算比率 1000%）・割引率 0・小児 1 名で、[Source] 17,050,400 円、[Spec] 60,000,000 円。`dev_D012` を外すと ABS-004 は成り立たない（`Abstraction.Fare.need_D012`） | D-012 |
| ABS-114 | W | D-014 の証拠: Clock の呼び出しごとに異なる日付を返す実行で、[Source] と [Spec] の結果が異なる。空席照会で、共有サービスが 1970-01-01 を読んだ後に `searchFlight` が 1970-01-02 を読む（照会の途中で日付をまたぐ）と、[Source] は `e.ar.b1.2003`、[Spec] は `e.ar.b1.2001` を返す。`dev_D014S` を外すと ABS-011 は成り立たない（`Abstraction.FlightSearch.need_D014`） | D-014 |
| ABS-117 | W | D-017 の証拠: `redirectTo = "https://example.com/"` で、遷移先が異なる | D-017 |
| ABS-118 | W | D-018 の証拠: `creditMonth = "1e1"`、または 6 文字の `creditTerm` で、結果が異なる | D-018 |
| ABS-119 | W | D-019 の証拠: `Accept-Language: en` で、曜日の表示が異なる | D-019 |
| ABS-120 | W | D-020 の証拠: 便マスタに無い便名で、[Source] は前提違反（500）、[Spec] は `InvalidRequest`（400） | D-020 |
| ABS-121 | W | D-021 の証拠: `+10000/01/01`、`0000/01/01` で、解析結果が異なる | D-021 |
| ABS-122 | W | D-022 の証拠: 単項目の違反が 2 件以上ある入力で、[Source] の許される順序の 1 つが [Spec] の列と異なり、`obs_D022` で対応する | D-022 |
| ABS-126 | W | D-026 の証拠: `"\ud800"` を含む REST の要求で、[Source] は処理を続け、[Spec] は `InvalidRequest` を返す | D-026 |
| ABS-127 | W | D-027 の証拠: 未知の搭乗クラスコード `X` の行を持つ DB で、[Source] は起動時に `IllegalArgumentException` を投げる（[Spec] にはその入力が無い）。前提を満たす例はシードの DB。Lean: `Abstraction.MasterData.need_D027`（前提を外すと入力の全域性が破れる）と `unknownBoardingClass_throws` | D-027 |
| ABS-131 | W | D-031 の証拠: 往路便を NTT523（到着時刻 `2415`）とする往復の予約で、[Source] は `DateTimeParseException`（500）、[Spec] は往路便の到着日時を翌日 0:15 として検査を続ける。`2400` では [Source] は例外を出さず当日 0:00 と読む（backlog aedf） | D-031 |
| ABS-132 | W | D-032 の証拠: 既定の書式ロケールの区切り文字が `.`（ドイツ語など）の [Source] で、空席照会の運賃 100,000 円は `100.000`、[Spec] は `100,000`。`dev_D032` を外すと ABS-011 は成り立たない（`Abstraction.FlightSearch.need_D032`） | D-032 |

ABS-113 は廃止した（D-013 をモデル外に改めたため。ID は再利用しない）。

課題の進め方は、[backlog bbcc](../backlog/bbcc-fare-abstraction-proofs.md) ほか各機能の backlog 項目による。W 課題は、その差異を最初に仮定する R 課題の backlog 項目で完了させる。後続の項目は、その項目に依存する。

### 入口の R 課題

外部からの入力を受ける入口の機械の R 課題である。[Source] の公開操作の網羅（TR-P）は、これらの R 課題の具体機械で数える。入口でない R 課題（ポート実装・内部の計算・ユースケース単体）は、入口の R 課題の証明に使う補題として扱う。入口の機械の [Spec] には、SPEC-006（入口の全域性）を課す。

| ID | 入口 | backlog |
| --- | --- | --- |
| ABS-031 | REST 予約 API（`Spec.Http` の REST） | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| ABS-044 | 予約履歴レポートの要求の受信と生成（キューからの配信） | ac713033-9b94-4e5a-bfc4-d27bdee7ee2e |
| ABS-045 | HTTP の画面（`Spec.Http` の画面） | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |

## Spec 自身の証明課題（SPEC-NNN）

抽象機械 `Spec` が満たすべき性質である（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#抽象機械)）。R 課題が INV を仮定してよいのは、これらが証明されているからである。

| ID | 内容 |
| --- | --- |
| SPEC-001 | 各操作で、PRE の下の標準の選択 `run` の結果が、関係 `step` に含まれる |
| SPEC-002 | 初期化（fixture の投入後の `World`）が INV を満たす |
| SPEC-003 | PRE の下の各操作（`Conflict` と実行環境の失敗の結果を含む）が INV を保つ |
| SPEC-004 | `Conflict` と実行環境の失敗の結果では、採番以外の状態が変わらない（[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)） |
| SPEC-005 | 各機能の基底の機械は、`Machine.ofChoice`（選択の像）か `Machine.pure`（決定的な純粋計算）で作る。選択の型の葉は、[Spec の非決定性](#spec-の非決定性n-nnn) に登録した `@[nondet]` の型だけとし、環境の選択には種類「環境」の行の型を、自由な選択には種類「自由」の行の型を使う。自由な選択には、その選択が変えうる部分を核で示した射影についての `FreeFrame` を示す（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)。形は TR-G で検査する） |
| SPEC-006 | [入口の R 課題](#入口の-r-課題) の機械は、INV と環境の前提（`@[env_pre]`。MD-1〜MD-8 と入力の値域）の下で PRE が成り立つ（`Machine.TotalUnder`）。環境の前提には両向きの例（`Nontrivial`）と、前提を外すと PRE が成り立たない入力があること（`¬ TotalUnder A always`。[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）を示す。PRE が INV の下で全域な機械は、環境の前提を置かず `TotalUnder A always` を示す |
| SPEC-007 | 各機能の初期状態は fixture の投入後の `World` の 1 点である（`Machine.InitIs`） |
| SPEC-008 | 標準の環境の下では、`f` は環境の非決定性に固有の結果（N-001 の `Conflict`、N-002 の `System("e.ar.fw.9999")`）を返さない |

各機能の `Spec` を作る backlog 項目で、その機能の SPEC 課題を完了させる。

## Spec の非決定性（N-NNN）

[Spec] が許す非決定性の一覧である（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)）。[Spec] の非決定性は、ここにあるものだけとする（SPEC-005）。
Lean では、`Machine.ofChoice` の選択の型の葉に `@[nondet "N-NNN"]` を付ける。登録簿と属性の 1 対 1 は TR-N で検査する。

- **環境**: 実行環境が決める選択である。[Source]・[Target] では入力の環境の成分として表し、`Pinned` で固定する。標準の環境（障害の無い環境・参照の配備の設定）では、標準の値を選ぶ。
- **自由**: 実装が決めてよい選択である。[Source]・[Target] はどれを選んでもよい。標準の選択 `run` は参照の値を選び、ベクタは参照の値で生成する。自由な選択が変えうる部分は、`FreeFrame` の射影の核として示す（SPEC-005）。
- backlog の列は、選択の型を Lean に定義する項目である（段階導入）。

| ID | 種類 | 内容 | 標準の選択 | 出典 | backlog |
| --- | --- | --- | --- | --- | --- |
| N-001 | 環境 | 排他制御の失敗 `Conflict`。採番以外の状態を変えない（SPEC-004）。Lean: `Spec.Nondet.ConflictChoice` | 起きない | [ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)、[ports.md](ports.md#トランザクション) | 0fdf5090-3432-4a6e-9064-40f53e4231a9 |
| N-002 | 環境 | ポートの I/O の失敗 `System("e.ar.fw.9999")`。採番以外の状態を変えない（SPEC-004）。Lean: `Spec.Nondet.IoFailureChoice` | 起きない | [ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)、[ports.md](ports.md#トランザクション) | 0fdf5090-3432-4a6e-9064-40f53e4231a9 |
| N-003 | 環境 | レポート要求の再配信の上限（1 以上。配備の設定）、重複配信、配信の順序。Lean: `Spec.Nondet.ReportDeliveryChoice` | 上限は参考値の 10、重複なし、送信順 | [ports.md](ports.md#reportqueue)、[ADR 90f5](../decision/90f5-report-queue-at-least-once-delivery.md) | 0fdf5090-3432-4a6e-9064-40f53e4231a9 |
| N-004 | 自由 | `InvalidRequest` のメッセージの詳細（任意の文字列）。変えうるのは詳細の文字列だけ。Lean: `Spec.Nondet.InvalidRequestDetail` | `Spec` の定義で定める（適合テストでは比較しない） | [http-contract.md](http-contract.md) | 0fdf5090-3432-4a6e-9064-40f53e4231a9 |
| N-005 | 自由 | `PasswordHasher.hash` の値（`matches` の契約を満たす任意の値）。変えうるのは保存するハッシュ値だけ。Lean: `Spec.Nondet.PasswordHashChoice` | 参照の実装の符号化 | [ports.md](ports.md#passwordhasher)、[ADR 2d1f](../decision/2d1f-password-hashing-port.md) | 0fdf5090-3432-4a6e-9064-40f53e4231a9 |

採番（`IdGenerator`）は非決定性ではない。[Spec] の状態 `World.sequences` が次の値を決める（[ports.md](ports.md#idgenerator)）。
