---
type: Architecture Decision Record
title: "予約の第 3 段: 全表の α と共有の初期状態、具体側の不変条件、予約の R 課題"
description: "backlog aedf の第 3 段の設計を決める。状態の α worldOfDb を全表（会員・予約・シーケンス）に広げて Abstraction.World.Alpha に置き、空席照会と予約で共有する。予約の表は、子の行が親の順に並ぶときに限って写す。主キーの一意性に使う具体側の不変条件 IcW（使用済みの番号が採番の次の値より小さい）を、両方の貼り合わせに置く。空席照会の初期状態を、シードを投入した後の World・状態の表に揃える。第 3 段を小段 3a〜3d に分ける。"
tags: [adr, abstraction, reservation, machine, alpha]
id: "ab9318bc-ec06-4d90-8080-42395aadcfaa"
status: stable
decision_status: accepted
date: 2026-11-02
decision-makers: プロジェクトオーナー（3 段の進め方と、確認待ちで登録して続けること）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T12:00:00+09:00
---

# 予約の第 3 段: 全表の α と共有の初期状態、具体側の不変条件、予約の R 課題

## Context and Problem Statement

[ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md) で、[backlog aedf](../backlog/aedf-reservation-usecase.md) を 3 段に分けた。第 1・2 段では、予約の関数・ベクタ・機械・初期状態・SQL の差分実行を置いた（[ADR ca17](ca17-reservation-stage2-machines-seed-nondet-advance.md)）。

第 3 段では、予約の R 課題を証明し、トップレベルの主定理に統合する。予約と空席照会は同じ状態 `World` を共有し、合成子 `Machine.alt` で並置する（[スキルの ADR a303](../../.agents/skills/spec-pivot/references/docs/decision/a303-shared-state-machine-alt-and-transaction.md)）。`Refines.alt`・`Preserves.alt` は、次を仮定する。

* 2 つの貼り合わせの `J` が等しい
* 初期状態が同じ 1 点である
* INV が等しい

第 2 段までの空席照会の α `worldOfDb` には、次の制限があった。

* 予約・会員の表とシーケンスが使われていない状態に限っていた
* 初期状態は、FLIGHT 表だけのシード（`Spec.Seed.Flight.world`・`seedFlightDb`）だった

予約の主キーの一意性を示すには、使用済みの番号と採番の関係も要る。

## Decision Drivers

* 原則 B: 予約と空席照会を、トップレベルの主定理で並置する。
* α は、定義域の上で単射な部分写像で、核の義務 ABS-048（obligation-check の G7）を満たす。
* 既存の ABS-011 の証明を、状態の型を合わせるだけで使い続ける。

## Considered Options

* α の置き場所
  * (a) 空席照会と予約が共有するモジュール `Abstraction.World.Alpha` に置く
  * (b) 空席照会のモジュールに置いたまま広げる
* 予約の表の写し方
  * (a) 予約の行ごとに、予約番号の同じ予約フライトの行（と、予約フライト番号の同じ搭乗者の行）を表の順に集め、子の表が親ごとの子の列をつないだものに等しいときに限って写す
  * (b) 子の表を予約番号・予約フライト番号で並べ替えて集める
* 主キーの一意性の不変条件
  * (a) 具体側の不変条件 `Ic`（`Glue.ofStd` の成分）に置く
  * (b) [Spec] の `World.Inv` に置く

## Decision Outcome

Chosen option: "α の置き場所 (a)・予約の表 (a)・不変条件 (a)"。理由は次のとおりである。

* 置き場所 (a): 2 つの機能の貼り合わせの `J` が、同じ定義になる。
* 予約の表 (a): 登録は親・子の順に表の末尾に足すので、[Source] の到達する状態はこの形である。写しが単射なので、核は `undefOrEq` のままになる。(b) は登録順（[Spec] の予約の列の順）を失う。
* 不変条件 (a): [ADR ca17](ca17-reservation-stage2-machines-seed-nondet-advance.md) の方針どおり。[Spec] の INV を変えずに済み、予約の SPEC 課題の証明を作り直さない。

### 第 3 段の小段

| 小段 | 内容 |
| --- | --- |
| 3a | 全表の α、具体側の不変条件、空席照会の初期状態の変更（本 ADR の決定） |
| 3b | ポートの R 課題 ABS-021・ABS-023、差異の述語（D-009・D-014・D-031）、W 課題 ABS-109・ABS-131 |
| 3c | 予約の R 課題 ABS-041 と L 課題 ABS-020・ABS-022 |
| 3d | 束 `Preserves` と課題の属性、トップレベルへの統合（`searchMachine.alt reserveMachine`）、記録 |

### 3a の決定

| 項目 | 決定 |
| --- | --- |
| 状態の α | `Abstraction.World.Alpha.worldOfDb`（葉。核 `worldOfDb_kernel`）。<br>- FLIGHT: 行ごとに `flightOfRow`<br>- MEMBER・MEMBER_LOGIN: 同じ位置の行を組にする（会員番号が違えば定義しない）。ログイン日時は 0:00 のときだけ暦日に写す（`dateOfTimestamp`）<br>- 予約の表: 上の (a)<br>- シーケンス: 次に返す値（未使用なら 1、最後に返した値 `v ≥ 1` なら `v + 1`）<br>補助の写像（複数の行を組にするもの）には `@[std_abs]` を付けない（G7 は 1 引数の葉か、許可した合成を求める） |
| 具体側の不変条件 | `IcW t`: α の像で、使用済みの予約番号は次の予約番号より小さい番号の書式、予約フライト番号・搭乗者番号は次の値より小さい（`KeysBelow`） |
| 空席照会 | 貼り合わせ `glueFS` の `Ic` を `IcW` にする。`searchMachine` の初期状態を `Spec.Seed.World.world`、`searchConcrete` の初期状態を `SourceModel.Db.Seed.seedDb` にする。照会は状態を変えないので、`IcW` は保たれる |
| 初期状態の対応 | `Abstraction.World.Init.worldOfDb_seed`（FLIGHT は生成の形の上で合成、会員はカーネルで照合）と `icW_seed`。旧 `Abstraction.FlightSearch.Init` を移した |
| 予約・会員を含む状態の空席照会 | 暫定の制限（[assurance.md](../spec/assurance.md) の行）を外した。上流のシードの会員を投入した状態も α の定義域に入る |

### 3b の決定

| 項目 | 決定 |
| --- | --- |
| [Spec] の予約の PRE | 次を足す（[Spec] の修正）。<br>- `Request.Valid`: 入力検証の単項目制約のうち長さと桁、相関 1 の電話番号の長さの上限、選択フライトの便名が空白でないこと。原典の列の長さ（`VARCHAR(n)`）と `int` に収まることに使う<br>- `World.RefMaster`: フライトの便名・搭乗クラス・運賃種別がマスタにある。原典は存在の確認で搭乗クラス・運賃種別のコードを束縛するので、マスタに無いと `NULL` になり、[Spec] と結果が分かれる<br>- `World.MemberRefMaster`: 会員のカード種別がマスタにある。原典の会員の取得はカード種別の表と結合する |
| 具体側の不変条件 | `IcW` の `KeysOk` に、会員番号の一意性（PK_MEMBER）を足す。会員の取得の文の結果を高々 1 行にするのに使う |
| ABS-021・ABS-023 の種類 | R 課題から、ABS-041 の補題（L 課題）に改める（プロジェクトオーナーの決定）。ポートの実装は、予約の具体機械の中で使われ、単独の機械として外に出ない。R 課題にすると、ポートごとの機械と束 `Preserves` が要る。ABS-023 は `Abstraction.Reserve.Port`・`Member` の補題に付けた。ABS-021 は採番の補題を置くとき（3c）に付ける。ABS-024・ABS-025 の種類は、それぞれの機能の backlog で決める |
| 予約の入出力の α | `aiR`（設定・マスタ・Clock の最初の読み出し・選択フライト・予約フォーム・操作の種類）と `aoR`（核 `undefOrEq`）。不正要求の詳細は空文字に写し、[Spec] の詳細は自由な選択 N-004 で置き換える |
| [Source] の計算の検証 | 3c の前に検証の道具を整える（プロジェクトオーナーの決定）。Hoare 三つ組と、状態を与えた形に簡約するタクティク `java_estate_simp` をスキルの assets に置いた（[スキルの ADR cd90](../../.agents/skills/spec-pivot/references/docs/decision/cd90-estate-hoare-and-simp-tactics.md)。スキルの版 0.26）。文の実行の規則と障害の例外 `IsFault` は ATRS の `Abstraction.Reserve.Tx` に置く。試しとして、選択フライトの検証の全経路（1 便・往復、便マスタの有無、障害）の三つ組と [Spec] の対応を `Abstraction.Reserve.ValidateFlights` で示した |

| 差異の述語 | `Abstraction.Reserve.Alpha` に置き、それぞれに非自明性の定理を `Abstraction.Reserve.Witness` に置いた（G8）。<br>- 具体側: `dev_D027R`（`aiR` が定義され、業務例外の引数に使う運賃種別名が改行を含まない。SourceModel の業務例外のメッセージがコードと引数を改行でつないだものなので）、`dev_D014R`（Clock のどの読み出しも最初と同じ日付）<br>- 抽象側: `dev_D009`（状態と入力。予約確定で使う番号がシーケンスの最大値と `int` の上限を超えない）、`dev_D031`（往復の往路便の到着時刻が 24:00 より前）、`dev_D001R`・`dev_D002R`・`dev_D012R`（合計金額の入力 `tfOf` に `dev_D001T` などを課す）<br>ABS-041 の機械は `reserveMachine` に `restrictState dev_D009` と抽象側の `restrict` の層、`reserveConcrete` に `dev_D027R`・`dev_D014R` の `restrict` の層をかけたものとする（層の並びは 3c で W 課題の否定の定理と合わせて固める） |
| W 課題の証人 | D-031 の証人の材料（往路便 NTT523 の到着時刻 `2415` のマスタ `db2415`・FLIGHT 表 `fd2415`・往復の予約確認 `ic2415`）を置いた。[Source] の計算が `DateTimeParseException` で終わることは `#eval` で確かめた。カーネルでの評価（`decide +kernel`）は途中で簡約できずに止まるので、評価の定理と否定の定理 `need_D031`・`need_D009` は 3c で ABS-041 と同時に置く |

置いた補題（すべて `sorry` なし）:

* `Abstraction.Reserve.Port`: FLIGHT の主キーの条件・`exists`・`findOneForUpdate`・`update` の行
* `Abstraction.Reserve.Member`: `MemberRepository.findOne` の文の結果と `World.findMember`、`member-map` と会員の照合
* `Abstraction.Reserve.Providers`: 便マスタの Provider の答え（区間の空港コード、無い場合の `null`）、予約が使う読み込みの性質 `load_res`
* `Abstraction.Reserve.Flights`: 到着・出発時刻の解釈、搭乗間隔の検査（D-031 の前提）、運賃種別・逆区間の検査の対応 `AgreeV`
* `Abstraction.Reserve.Select`: `toFlightList` が作るフライト情報の性質（便マスタの有無、存在の確認の文の結果、運賃種別のコード）
* `Abstraction.Reserve.ValidateFlights`: 選択フライトの検証の Hoare 三つ組と、[Spec] の `validateFlightList` の対応

### 3c の決定

| 項目 | 決定 |
| --- | --- |
| 業務例外の対応 | 検査の結果の対応 `AgreeB`（どちらも成功するか、[Source] の業務例外と [Spec] の `Business` のコードと引数が同じ）を置く。状態を伴う検査の事後条件は `PostB`・`PostBE`（障害 `IsFault` か、同じコードと引数の業務例外）とし、検査の逐次は `seqB`、純粋な検査の持ち上げは `lift_agreeB` でつなぐ |
| 予約フライトごとの繰り返し | 原典は、運賃種別の利用条件と搭乗者の会員照合を予約フライトごとに繰り返す。[Spec] は、運賃種別の利用条件を便ごとの検査の最初の失敗（`firstErr`）、搭乗者の会員照合を 1 回とする。後者は、すべての予約フライトが同じ搭乗者列を持つので、最初の繰り返しが [Spec] と同じ結果になり、2 回目以降は成功か障害である（`forIn_same`） |
| トランザクションの取消 | 状態の表を変えない計算（`validateReservation`）では、取消は状態を変えない（`transactional_hoare`。`FlightDb.rollback fd fd = fd`） |
| 選択フライトの検証（前段） | [Spec] の選択フライトの検証の失敗は、すべて改竄に写るエラー（`InvalidRequest` か `Business`）である（`validateFlightList_req`）。原典の `BadRequestException` は、出力の α で `InvalidRequest` に写り、詳細は自由な選択 N-004 で合わせる。往復の搭乗間隔の検査には D-031 の前提（往路便の到着時刻が 24:00 より前）を使う（`vf_two`）。逆区間・運賃種別の検査の三つ組 `two_some` の運賃種別の仮定は、両便の存在の確認の後に限った |
| 業務例外のメッセージの分解 | 具体機械の `catchReserve` は、業務例外のメッセージを 1 文字の区切り（改行）の `String.split` で分ける（従来の `String.splitOn "\n"` と同じ結果）。core に、区切りを含まない文字列の列を `intercalate` したものとの往復の補題（`String.toList_split_intercalate`）があるので、コードと引数が改行を含まなければ、元のコードと引数に戻る（`Abstraction.Reserve.Catch.catch_business`） |
| 実行環境の障害 | 障害の例外 `IsFault env e` は実行環境を持ち、排他の失敗は `env` が排他の失敗の位置を持つときに限る。予約確認の具体機械の定義域（排他の失敗の位置が無い）では、障害は I/O の失敗だけになり、[Spec] の予約確認が `Conflict` を返さないことと合う（`catch_fault_none`） |
| 業務例外の引数 | 予約内容の検証の業務例外のコードと引数は改行を含まない（`Abstraction.Reserve.NoNL.validate_nl`）。引数は設定の整数・位置（自然数の文字列）とマスタの運賃種別名で、運賃種別名は D-027 の前提（`dev_D027R`）で改行を含まない |
| 合計金額 | 予約の合計金額の計算は、合計金額の L 課題 ABS-005（`runTotalFare_eq`）から [Spec] の `totalFareOfKeys` の値になる（`Abstraction.Reserve.TotalFare.calc_eq`）。会員の表を差し替えたサービスでも同じ |
| 予約確定の 1 歩の選択 | 障害で終わった予約確定は、I/O の失敗なら N-002、排他の失敗なら N-001 を選び、その採番の前進は、失敗するまでに進んだ数（取消の後の α が `advance w a` になる `a`）とする（`Abstraction.Reserve.ReserveRun.fault_out`）。登録の後の具体側の不変条件 `IcW` は、新しい予約の番号が採番の次の値から振られることから保たれる（`KeysPres`） |
| ABS-041 の課題の属性 | 主定理 `reserveRefines` と、W 課題 ABS-109・ABS-131 の否定の定理（`need_D009`・`need_D031`）には、まだ課題の属性を付けない（W 課題の定理は、課題の属性を付けた R 課題に対してだけ必要性の定理と認められる。G9・GK）。obligation-check は、課題の属性を付けた R 課題に、束 `Machine.Preserves`（G6）・自由な選択の射影の核（G3）・具体機械の基底の `Dom` を既定にすること（G4）を課す。束と具体機械の定義域（予約確認では排他の失敗を起こさない）の扱いは 3d で決める。束の成分 `pinned`（環境の選択を具体側の入力の環境 `ce i_c` に固定する）は、選択の型が採番の前進 `SeqAdvance`（実行に依存する）を持つため、`ce` の形と合わせてプロジェクトオーナーの判断が要る |

置いた補題（すべて `sorry` なし）:

* `Abstraction.Reserve.Validate`: 代表者の年齢・運賃種別の利用条件の検査の対応（`repAge`・`fareTypes`）
* `Abstraction.Reserve.MemberCheck`: 会員の取得の三つ組 `findOne_hoare`、代表者・搭乗者の会員照合の三つ組（`repMember_hoare`・`passengerMember_hoare`）
* `Abstraction.Reserve.ValidateReservation`: 予約内容の検証の三つ組と、[Spec] の `validateReservation` の対応（`validate_hoare`）
* `Abstraction.Reserve.TotalFare`: 予約の合計金額（`calc_eq`）
* `Abstraction.Reserve.Selects`: 選択フライトの検証の失敗が改竄に写ること、1 便・往復の三つ組（`vf_one`・`vf_two`）、`BadRequestException` に包む前段（`helper_vf`）
* `Abstraction.Reserve.Catch`: 出力の値とする例外の像（業務例外・不正要求・障害）
* `Abstraction.Reserve.Draft`: 予約情報の組み立てと `buildDraft` の対応（空の搭乗者欄の判定、欄を詰める処理、搭乗者の会員番号・氏名・性別）
* `Abstraction.Reserve.SpecFacts`: 選択フライトの検証が成功したときの、フライトの存在と運賃種別、予約確認の操作の値の分解
* `Abstraction.Reserve.Input`: 入力の α `aiR` の像の分解
* `Abstraction.Reserve.NoNL`: 業務例外のコードと引数が改行を含まないこと
* `Abstraction.Reserve.Vacancy`: 空席の確保の三つ組（1 便 `vacancy_hoare`、予約フライトの列 `vacancies_hoare`）と [Spec] の `secureSeats` の対応。排他でのフライトの取得の行の写像、空席数の更新の文の α（`World.updateVacantNum`）、運賃種別の予約可能判定（D-014 の前提で Clock の読み出しは同じ日付）。例外で終われば採番は変わっていない
* `Abstraction.Reserve.Register`: 採番の文と予約番号の書式（L 課題 ABS-021 を付けた）、予約の表の末尾に新しい予約・予約フライト・搭乗者の行を足したときの α（`reservationsOf_append`）
* `Abstraction.Reserve.Insert`: 予約・予約フライト・搭乗者の行の挿入の文（型変換・NOT NULL・主キー・外部キー）が値域内で成功し、行が末尾に足され、その α が [Spec] の記録であること（`insertRow_ok`・`insertReserveFlightRow_ok`・`insertPassengerRow_ok`）
* `Abstraction.Reserve.Rollback`: トランザクションの取消の後の α（開始時の `World` の採番を進めたもの `advance w a`）、採番が進んだことを表す `SeqGe`、取消を含むトランザクションの三つ組の規則（`transactional_hoare'`）
* `Abstraction.Reserve.Keys`: 予約番号の書式の単射性（`reserveNoOf_inj`）と、主キーの性質 `KeysOk` から既存の予約・予約フライト・搭乗者の行の番号が採番の次の値より小さいこと（`rows_lt`）
* `Abstraction.Reserve.RegSpec`: [Spec] の `register` の採番の分解（搭乗者・予約フライトの記録は、採番の次の値から順に番号を振ったもの）
* `Abstraction.Reserve.RegisterRun`: 予約・予約フライト・搭乗者 1 件ずつの挿入（採番の文・整数の読み出し・挿入の文）の三つ組と、搭乗者の列・予約フライトの列の挿入の三つ組（`passengers_hoare`・`flights_hoare`。挿入の途中は予約の表の α の定義域に入らないので、表の生の形と採番を不変条件にする）。例外で終われば障害で、状態の表は採番だけ進んでいる
* `Abstraction.Reserve.FlightFacts`: 主キーで取れるフライトの行の存在と便名の長さ、`findMember` で見つかる会員の行の存在と会員番号の長さ、選択フライト情報から作ったフライト情報の搭乗クラス・運賃種別のコード
* `Abstraction.Reserve.Registration`: 予約の登録（`registerReservation`）の三つ組（`registerReservation_hoare`）。正常に終われば、空席の確保の [Spec] の値が `w1` で、状態の表の α は `w1` に新しい予約を足し採番を進めたもの（`regWorld`）。例外で終われば、障害で α は `advance w a`、空席の確保の業務例外で α は `w`
* `Abstraction.Reserve.ReserveFacts`: [Spec] の予約内容の検証が成功すれば代表者・搭乗者の会員番号の会員があること（`validate_members`）、搭乗者欄を詰めても組み立てと原典の予約情報が変わらないこと（`buildDraft_compact`・`create_reset`）、要求の長さと桁の制約から搭乗者欄の条件が分かること（`passConds`）、[Spec] の予約確定の操作の値の分解（`reserveOp_cases`）と登録の結果の形（`register_eq`）
* `Abstraction.Reserve.ReserveHelper`: 予約確定（`TicketReserveHelper.reserve`）の三つ組（`helperReserve_hoare`）。予約内容の検証・Clock の読み出し（D-014）・合計金額・予約の登録をつなぎ、正常なら状態の表の α は [Spec] の `register` の結果、例外なら障害（採番の前進だけ変わる）か予約内容の検証・空席の確保の業務例外（α は変わらない）
* `Abstraction.Reserve.KeysPres`: 予約確定の後も具体側の不変条件 `KeysOk` が保たれる（採番の前進 `keysOk_advance`、予約の登録 `keysOk_regWorld`）
* `Abstraction.Reserve.Witness`（追加）: W 課題の否定の定理 `need_D031`（往路便の到着時刻が 24:15 の往復の予約確認で、[Source] は `DateTimeParseException` で終わる）と `need_D009`（搭乗者の採番の次の値が `int` の最大値を超える状態の予約確定で、[Source] は `MyBatisSystemException` で終わる）。どちらも [Spec] の PRE と他の差異の前提は成り立ち、具体側の適用可能性が破れる。[Source] の計算は、`hasText`（`String.any`。整礎再帰でカーネルの評価が止まる）を文字の列の形に書き換えてから `decide +kernel` で評価する
* `Abstraction.Reserve.ReserveRun`: 予約確定の 1 歩の対応（`reserve_run`）と、予約確認・予約確定をまとめた 1 歩（`run_any`）、R 課題 ABS-041 の主定理 `reserveRefines` と付帯の義務 `reserveRefines_initSurj`（課題の属性を付ける 3d で、機能のモジュール `Abstraction.Reserve` へ移す）。具体機械の予約確定の 1 歩は、どの許される並び・障害の位置でも出力の値で終わり、実行後の状態は `IcW` を満たし、その α と出力の像は [Spec] の予約の 1 歩（成功・業務例外は標準の選択、I/O の失敗は N-002、排他の失敗は N-001 の選択と、失敗までに進んだ採番、前段の改竄は N-004 の詳細の置き換え）の結果である
* `Abstraction.Reserve.ConfirmRun`: 予約確認の 1 歩の対応（`confirm_run`）。具体機械の予約確認の 1 歩は、どの許される並び・障害の位置でも、状態を変えずに出力の値で終わり、その像は [Spec] の予約確認の 1 歩（成功・業務例外は標準の選択、I/O の失敗は N-002 の失敗と採番の前進 0、前段の改竄は N-004 の詳細の置き換え）の出力である
* `Abstraction.Reserve.Confirm`: 予約確認の後段（組み立て・検証・合計金額）の三つ組と、予約確認の流れ全体（`confirm_core`）

### 3d の決定

3c の主定理に課題の属性を付けると、束 `Preserves` を予約に当てはめる必要がある。そのとき出た 3 つの判断を、
プロジェクトオーナーが決めた（判断 1〜3 とも案 A）。

| 項目 | 決定 |
| --- | --- |
| 判断 1: 環境の固定 | スキルの規則を広げる（スキルの ADR 61e6、版 0.27）。束の `pinned` を、具体側の環境の記述 `ce ic` が許す選択の関係 `adm` にする。障害の指定の無い記述は標準の選択だけを許す（`noFaultStd`）。障害の位置は実行環境が持つが、障害が実際に起きるかと採番の進んだ数は実行で決まるため |
| 判断 2: 予約確認のロックの失敗 | SourceModel を直す。排他の失敗（ロック待ちのタイムアウト・デッドロック）は、行ロックを取る文でだけ起こす。<br>- 読むだけの文 `SourceModel.Db.Tx.query` は、I/O の失敗だけを起こす。<br>- 行ロック付きの読み出し `lockQuery`（`findOneForUpdate`）と、更新・挿入・採番の `sql` は両方を起こす。<br>これで `reserveConcrete` の定義域を既定（すべての入力）に戻した（3c の「実行環境の障害」の行の定義域の扱いを置き換える）。証明では、読むだけの文の障害を `IsIoFault`、`IsFault` の I/O の失敗を「実行環境が I/O の失敗の位置を持つとき」に限る形にした |
| 判断 3: 状態とマスタの対応 | スキルの規則を広げる（スキルの ADR 61e6）。環境の前提を状態と入力の述語にし、証人は初期状態で示す。予約の PRE の `World.RefMaster`・`World.MemberRefMaster`（外部キーに当たる）と D-009 の前提を、環境の前提に書けるようにするため |
| ABS-041 の束 | `Abstraction.Reserve.reservePreserves`（機能のモジュール。`@[obligation "ABS-041"]`）。<br>- 選択の像の材料 `chR`: 環境の記述 `Abstraction.Reserve.Alpha.ceR`（障害の位置の組。`@[std_abs]`、核は ABS-048）と、[Spec] の許す選択 `Spec.Nondet.admits`（位置の無い障害は選ばない）。<br>- 自由な選択 N-004 の枠の射影 `eraseDetailR`（`InvalidRequest` の詳細を消す。核 `sameUpToDetail`）。<br>- 環境の前提 `envR`: マスタ・設定の妥当性、`Request.Valid`、`RefMaster`・`MemberRefMaster`、操作の結果が定まること、差異の前提。<br>- 差異はすべて中断の差異なので、「出力のみ」の層は無い。<br>- `pinned` は、予約の 1 歩の対応（`run_any`）が、選んだ環境の選択が `admits (ceR ic)` を満たすことも返すことで示す |
| 初期状態での証人 | シードのマスタの具体側の DB `SourceModel.Db.MasterSeed.masterDb` を、共有入力から生成器 `tools/conformance/master_seed.py` で作る（`conformance:check` で一致を確かめる）。その α がシードのマスタであることを、カーネルでの評価で示す（`Abstraction.MasterData.SeedAlpha.masterDataOf_seed`）。証人はシードの最初のフライト（2026-11-01・NTT001・N・OW）を選ぶ予約確認で、操作の結果が定まることはカーネルで評価する（シードのフライトの列の先頭で探索が止まる） |
| 課題の属性 | `reserveRefines`・`reserveRefines_initSurj`・`reservePreserves` を機能のモジュール `Abstraction.Reserve` に置き、W 課題 `need_D009`（ABS-109）・`need_D031`（ABS-131）を同じモジュールに移して `@[obligation]`・`@[gap]` を付けた。登録簿の D-009・D-031 の証明の状態を「偽を証明済み」にした |
| L 課題 ABS-020・ABS-022 | 予約の 1 歩の対応 `reserve_run`（ABS-020・ABS-022）と `confirm_run`（ABS-022）に課題の属性を付けた。障害で終われば状態の α は `advance w a`、業務例外なら `w` で、どの結果も出力の値で終わる（L9002 に到達しない）。ABS-022 の他のユースケースの分は、その R 課題とともに示す |
| トップレベルへの統合 | `Spec.machine`・`SourceModel.machine` の空席照会の成分を、同じ状態の上の並置 `Machine.alt`（空席照会と予約）にした。`Abstraction.refines` は `searchRefines.alt reserveRefines`、`Abstraction.preserves` は `searchPreserves.core.alt reservePreserves.core` を並置に加えて示す。<br>- 抽象側の差異の述語 `dev` は状態と入力の述語にし、`restrictState` で課す（D-009 が状態を見る）。<br>- 環境の前提 `env` は、`Machine.Sum.altEnv` で予約の `envR` を並べる。<br>- obligation-check の G3'（`Spec` の層の機械の形）が `Machine.alt` を受けるようにした（スキル） |
| 予約確定の原典採取 | 予約確認の採取（76 件）と同じ入力で、予約確定の結果と実行後の状態を原典から採取した（`conformance/source-model/reservation/origin-run-reserve.json`。正常終了 44 件・業務例外 32 件）。`lake test` が `SourceModel` と照合する |

### Consequences

* Good, because 空席照会と予約の貼り合わせの `J` が同じ定義になり、`Refines.alt`・`Preserves.alt` の仮定を満たせる
* Good, because 会員を投入した上流のシードの状態で、空席照会のリファインメントが成り立つ
* Bad, because 予約の表の α は子の行の並びを定義域に課す。登録以外の書き込み（予約の取消など。backlog ac71・4e0e）を写すときは、その操作がこの形を保つことを示す

### Confirmation

* `lake build`・`lake test`・axiom-check・layout-check・obligation-check・`trace check` が通る。
* ABS-011（`searchRefines`・`searchPreserves`）とトップレベルの主定理が、新しい貼り合わせで通る。
* ABS-041 の主定理 `reserveRefines` と束 `reservePreserves` が課題の属性つきで通り、トップレベルの主定理の並置に入っている。

## More Information

* [backlog aedf](../backlog/aedf-reservation-usecase.md)、[ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md)、[ADR ca17](ca17-reservation-stage2-machines-seed-nondet-advance.md)
* [spec/abstraction.md](../spec/abstraction.md#抽象化関数-α)
