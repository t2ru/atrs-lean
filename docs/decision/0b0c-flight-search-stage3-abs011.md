---
type: Architecture Decision Record
title: "空席照会の第 3 段: R 課題 ABS-011 の証明の構成、PRE の改め、D-014・D-032 の具体側の入力、D-033 の登録、トップレベルへの統合"
description: "backlog 0be7 の第 3 段の設計を決める。R 課題 ABS-011（空席照会）を Machine.Refines の形で証明し、束 Machine.Preserves とトップレベルの主定理に加える。PRE の World.RefMaster を入力だけの条件に改め、空白の便名の便マスタを PRE の外（D-033）とする。D-032 の区切り文字と、D-014 の Clock の読み出しを具体側の入力に置き、W 課題 ABS-132・ABS-114 で必要性を示す。"
tags: [adr, spec, source-model, abstraction, flight-search, refinement, gap]
id: "0b0c414e-3d5f-4b8c-9f66-9fa2ee53cf5b"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー（計画の承認）。D-033 の登録と D-014 の写しの細分は、計画の後に作業の中で決めた（プロジェクトオーナーの確認待ち。More Information）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# 空席照会の第 3 段: R 課題 ABS-011 の証明の構成、PRE の改め、D-014・D-032 の具体側の入力、D-033 の登録、トップレベルへの統合

## Context and Problem Statement

[backlog 0be7](../backlog/0be7-flight-search-usecase.md) の第 3 段では、第 2 段（[ADR cdb6](cdb6-flight-search-stage2-machines-seed-sql.md)）の機械の上で、次のことを行う。

* R 課題 ABS-011（`Machine.Refines`）とその束 `Machine.Preserves` を証明する。
* L 課題 ABS-010、差異の述語と W 課題を置く。
* トップレベルの主定理（`Abstraction.refines`・`preserves`・`abstracts`）に加える。

着手にあたって、また証明の途中で、次の問題があった。

1. 束の成分 `total`（`TotalUnder`）は、入力だけの環境の前提から PRE が出ることを求める。第 2 段の PRE は、状態とマスタの組の述語 `World.RefMaster` を含んでいた。
2. D-032（区切り文字のロケール）は、[Source] のモデルが `,` を固定していたので、述語を書く入力が無かった。
3. [Source] は、照会の結果の各フライトの便名で `FlightMasterProvider.getFlightMaster` を呼ぶ。そこには `Assert.hasText` がある。マスタの不変条件 MD-1〜MD-8 は便マスタの便名が空白でないことを課さないので、[Source] だけが例外を投げる入力が PRE の中に残っていた。
4. [Source] は 1 回の照会で Clock を 3 回読む。読む場所は、`TicketSharedServiceImpl.validateDepatureDate` の今日、その中の `getSearchLimitDate` の今日、`TicketSearchServiceImpl.searchFlight` の今日である。モデルはこれを 1 つの値 `today` で受けていたので、D-014 の前提がモデルの形に隠れていた。計画では「D-014 には Lean の述語を置かない」としていた。しかし基本原則 3（[ADR c336](c336-foundational-principles.md)）と、機能の完了で失敗になる検査 TR-D に反する。
5. 検査 G4 は、具体側の基底が [Spec] の関数を参照することを禁じる。`bind`（束縛する値）と `addFareTypeVacantInfo`（キー）が `Spec.Model.*.toCode` を使っていた。
6. 機能の対応表 `trace/features.json` の FlightSearch には、0be7 の対象外（HTTP の層、予約が使う Repository の文と DateTimeUtil・FareTypeUtil のメソッド）のロケータが入っていた。0be7 を完了すると、それらが失敗になる。

## Decision Drivers

* 基本原則 1〜3（[ADR c336](c336-foundational-principles.md)）。差異は、定理の名前付きの仮定（`@[deviation]`）と登録簿の両方に置く。
* 主定理は合成だけにし、結合・整列・Provider・畳み込みの性質は補題のモジュールに分ける（計画の「危険と代わりの手」）。
* アプリに依存しない補題はスキルに置く（[ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md)）。

## Considered Options

* PRE: (a) `World.RefMaster` を外し、入力だけの「照会の搭乗クラスがマスタにある」を課す、(b) `RefMaster` を INV に移す
* 空白の便名: (a) PRE `FlightNamesHaveText` と、PRE の外の差異 D-033、(b) [Spec] にシステムエラーを足す、(c) MD-8 を強める
* D-014: (a) [Source] の写しで Clock の読み出しを分け（`sharedClock`）、具体側の入力の述語 `dev_D014S` と W 課題 ABS-114 を置く、(b) 述語を置かず登録簿を未証明のままにする（計画の案）
* 適用可能性の証人: (a) 整列キーの比較で `mergeSort` した並べ方 `mergeSortRows`、(b) 標準の安定整列 `standardSort`（挿入ソート）の正しさを示す

## Decision Outcome

Chosen option: "PRE (a)・空白の便名 (a)・D-014 (a)・証人 (a)", because 次の理由による。

* PRE (a) は、入力検証（`ExistInCodeList`）に当たり、入力だけで書ける。フライトがマスタに無い便名・運賃種別を指しても、両方の側でその行は除かれる。
* 空白の便名 (a) は、PRE の外の振る舞いの既存の扱い（D-003〜D-005・D-015）に合わせられる。
* D-014 (a) は、隠れた前提を名前付きの仮定にできる。
* 証人 (a) は、挿入ソートの正しさの証明を要さない。

### 決定

| 項目 | 決定 |
| --- | --- |
| PRE | `SearchInput.Pre` は次の連言とする。<br>- 設定とマスタの不変条件<br>- 照会の搭乗クラスがマスタにある<br>- 空港コードが空白でない<br>- `FlightNamesHaveText`（照会の区間の便マスタの便名が空白でない）<br>`World.RefMaster` は PRE に入れない。`searchFlight_isSome` は、搭乗クラスの条件で示す |
| D-033（新規） | 空白の便名の便マスタが結果に現れると、[Source] は `IllegalArgumentException` を投げる。<br>- 種類は「PRE の外」で、証拠は `excludedBy [FlightNamesHaveText]`。<br>- [Source] の箇所は `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight`、[Spec] の箇所は `Spec.FlightSearch.FlightNamesHaveText`（`@[gap "D-033"]`） |
| D-032 | 具体側の入力 `SearchInput.formatSymbols` に、配備の環境の書式の記号を置く。記号は、区切り文字・数字の 0・負の記号の文字列（スキルの `LangSemantics.Java.DecimalFormat.Symbols`）である。<br>- `createFlightVacantInfoList` はそれを `DecimalFormat` に渡す。<br>- 述語は `dev_D032 ic := ic.formatSymbols = Symbols.ascii`（`,`・`0`・`-`）。<br>- スキルの書式のモデルは、JVM の 6 つのロケール（ja-JP・de-DE・fr-FR・th-TH-u-nu-thai・ar-EG・fa-IR）と突き合わせた。<br>- W 課題 ABS-132 `need_D032`: `.` で、運賃 100,000 円の表示が `100.000` と `100,000` に分かれる。<br>- 影響は「出力のみ」なので、束の `outsC` に層を置き、`stateSafeC` を示す |
| D-014 | 具体側の入力 `SearchInput.sharedClock`（`validateDepatureDate` の今日、`getSearchLimitDate` の今日）を置く。`validateDepatureDate` は 2 つの今日を受ける。<br>- 述語は `dev_D014S ic := ic.sharedClock = (ic.today, ic.today)`。<br>- W 課題 ABS-114 `need_D014`: 照会の途中で日付をまたぐと（共有サービスが 1970-01-01 を読んだ後、`searchFlight` が 1970-01-02 を読む。Clock は進むだけ）、[Source] は `e.ar.b1.2003`、[Spec] は `e.ar.b1.2001` を返す |
| D-001・D-002・D-027 | `dev_D001S`・`dev_D002S`（抽象側）と `dev_D027S`（具体側。`aiS` が定義される）。<br>- D-001・D-002 は、搭乗日が照会可能期間の内で区間があるとき（基本運賃を計算する経路）に限って課す。<br>- D-001 は、照会の区間・搭乗クラス・搭乗日の基本運賃に課す。<br>- D-002 は、照会の片道・往復の運賃種別（`fareTypesFor`）の割引率に課す。候補に現れない運賃種別にも課す十分条件である。<br>- 必要性は、既存の W 課題 ABS-101・102・127 による |
| 貼り合わせ | `glueFS := Glue.ofStd worldOfDb (fun _ => True) aiS aoS`。<br>- 入力の α `aiS` は、設定・マスタ（ABS-026 の α）・今日・照会条件を写す。配備の環境は写さない。<br>- 出力の α `aoS` は、空席情報の DTO の文字列を写し、業務例外はコードで写す |
| 主定理 | `searchRefines : Refines ((searchMachine.restrict dev_D001S).restrict dev_D002S) (((searchConcrete.restrict dev_D027S).restrict dev_D014S).restrict dev_D032) glueFS`。<br>`correct`・`applicable` は 1 歩の補題 `Run.run_spec` の合成である |
| 束 | `searchPreserves`。<br>- 基底が `ofChoice` なので `ch = some chFS`（環境・自由な選択とも `Unit`、`@[std_abs]` の `ceFS`）。<br>- `Spec.FlightSearch.searchMachine` の 1 歩の関数を `searchStep` として名前を付けた（G6 の照合のため）。<br>- 環境の前提は `envFS` |
| 証明の構成 | `Abstraction.FlightSearch` の下位モジュールに分ける。<br>- `Join`: 文の結合と、`find?` による行ごとの評価<br>- `Candidates`: 行ごとの対応 `rowAt_rel` と列の写し `rows_cands`<br>- `Order`: `ORDER BY` と `mergeSort candidateLe`<br>- `Providers`: キャッシュの答え<br>- `Group`: `LinkedHashMap` の畳み込みと `group`<br>- `Run`: 1 歩<br>- `Witness`: W 課題の証人<br>- `Preserves`: 束の部品 |
| 整列 | 同順位が無いこと `noTie_cands` を示す。根拠は、MD-1（運賃種別の表示順の一意性）、MD-5（同じ区間の出発時刻の一意性）、`World.Inv`（主キーの一意性）である。<br>- `HHmm` の文字列の順序は、分数の順序に等しい（`hm_le_iff`）。<br>- したがって、許される並びの写しは `mergeSort candidateLe` にただ 1 つ定まる（`sorted_cands`） |
| 適用可能性の証人 | 整列キーの比較で `mergeSort` した並べ方 `Order.mergeSortRows` を使い、`SortAllowed` を示す。標準の `standardSort`（テストで使う安定整列）の正しさは示さない |
| G4 | [Source] の側に、enum の名前の関数を置く。<br>- `SourceModel.Domain.Model.FareTypeCd.getCode`（`FareTypeCd#getCode()`）<br>- `boardingClassCdName`（`Enum.name()`）<br>`bind` と `addFareTypeVacantInfo` はそれを使う。証明では `toCode` との一致の補題で結ぶ |
| トップレベル | 状態を `Unit × Unit × Unit × Unit × Port.World` にする。<br>- `Spec.init` に `Seed.Flight.world` を足す。<br>- Input・Output・`machine`・`dev`・`devC`・`glue`・`env` に、空席照会を 5 番目の成分として並置する。<br>- 束は `searchPreserves.core` を並置する。並置 `Preserves.sum` は 6 成分の束を並べるので、条件付きの成分（`pinned`・`noFault`・`freeFrame`・`stateSafeC`）はトップレベルに現れず、機能の束 `searchPreserves` にある（`Abstraction.lean`・[spec/abstraction.md](../spec/abstraction.md) に明記した） |
| 機能の対応表 | `trace/features.json` の FlightSearch のロケータを、0be7 の範囲に絞る（`searchFlight`・照会可能期間・空席照会の文・書式・シード・FLIGHT の DDL）。<br>- `app.b1.*`・`api.flight.*` は Http（backlog a89e。0be7 の対象外）へ移す。<br>- `FlightRepository#{exists,findOneForUpdate,update}`、`DateTimeUtil#{toLocalDate(LocalDateTime),toLocalDateTime*,toLocalTime*}`、`FareTypeUtil#{isOneWay,isRoundTrip}` は、Reserve へ移す。`DateTimeUtil#toLocalDate(String)`（会員の検査が使う）は Member へ移す。<br>- `TicketSharedService{,Impl}#isAvailableFareType` と、その写し `SourceModel.Domain.Service.B0.TicketSharedServiceImpl.isAvailableFareType` は Reserve へ移す（Java のロケータと Lean の名前空間の両方）。予約（`TicketReserveServiceImpl`）が呼び、空席照会は呼ばない（同じ条件を SQL の `BETWEEN` で書く）。0be7 の範囲の「運賃種別の予約可能判定」は、[Spec] と [Source] の写しを置き、L 課題 ABS-010 で日数の形との同値を示したことで満たす。R 課題に現れること（TR-P）は、予約の R 課題で確かめる。<br>- R 課題の列に ABS-114・ABS-132 を足す |
| スキル | 汎用の補題を足した（スキルの版 0.17。スキルの `log.md`）。<br>- SQL: 結合・`IN`・日付の等号・符号位置の照合<br>- `mapM`: 並べ替え・整列<br>- `JHashMap` の `get`・`put` と項目ごとの写しの可換性<br>- `for` の模倣 |

### Consequences

* Good, because 空席照会の [Source] が、PRE と 5 つの差異（D-001・D-002・D-014・D-027・D-032）の下で [Spec] をリファインすることが証明される。差異は、どれも定理の名前付きの仮定で、必要性も証明されている（W 課題）。
* Good, because トップレベルの主定理に、状態を持つ最初の機能が加わる。
* Good, because 隠れていた D-014 の前提が、名前付きの仮定になる。
* Bad, because D-001・D-002 の前提は、候補に現れない運賃種別にも課す十分条件である（述語が単純になる代わりに、主張の範囲が少し狭い）。
* Bad, because 証人の評価は、`String.any` を `toList` の形に書き換えてから `decide +kernel` で行う。カーネルは `String.any` を簡約できない。

### Confirmation

* `lake build` で、主定理と W 課題がすべて `sorry`・公理なしで通る。主定理は `searchRefines`・`searchPreserves`、W 課題は `need_D014`・`need_D032`、トップレベルは `Abstraction.refines`・`preserves`・`abstracts` である（axiom-check）。
* `obligation-check` が OK である（R 課題 5 件。G0〜G9）。
* `trace check` が、0be7 を完了とした状態で OK である。
* `lake test` が合格する（ベクタ・SQL の差分実行）。

## More Information

* プロジェクトオーナーの確認待ちの項目:
  * D-033 の登録（新しい差異の登録はオーナーの決定を要する。計画に無かった）。代わりの案は、MD-8 に「便マスタの便名が空白でない」を足すこと。その場合、ABS-026 の束の PRE も変わる。
  * D-014 の写しを、Clock の読み出しごとに分けたこと（計画の「D-014 には Lean の述語を置かない」を改めた）。
  * 補足: 上の 2 件は、[ADR f786](f786-gap-inventory-and-registry-fixes.md) でプロジェクトオーナーが承認した。
* 敵対的レビュー（完了前。独立したエージェント）の指摘と対応:
  * 中: `isAvailableFareType` の Java のロケータと Lean の名前空間が別の機能に属していた → 両方とも Reserve へ移し、理由を決定の表に書いた。
  * 中: トップレベルの束が `searchPreserves.core` で、条件付きの成分を含まないことが文書から読めなかった → `Abstraction.lean` の `preserves`・[spec/abstraction.md](../spec/abstraction.md) に明記した。
  * 中: ABS-114 の証人が、時間の逆行する Clock（共有サービスの今日が後の今日より未来）だった → 単調な証人に替えた（[Source] 2003、[Spec] 2001）。
  * 中: `dev_D001S`・`dev_D002S` が、基本運賃を計算しない経路（2001・2002・2003）と、照会に関係の無い運賃種別にまで課していた → 期間内で区間があるときに限り、D-002 は `fareTypesFor` の運賃種別に絞った。
  * 中: D-032 の環境が区切り文字だけで、`DecimalFormatSymbols` の数字の 0・負の記号の文字列が写されていなかった（タイ数字・アラビア数字のロケールで [Source] の写しが原典と一致しない） → スキルの書式のモデルを記号の組 `Symbols` にし、JVM の 6 つのロケールと突き合わせた。`dev_D032` は記号の組が `Symbols.ascii` であることとした。
  * 軽微: `FlightNamesHaveText` が全便マスタに課していた → 照会の区間の便マスタに絞った。PRE の説明の「入力検証を通過していれば満たされる」を、照会条件の条件に限った。
  * 軽微: `bind` が `getCode()` の写しを使っていた → `Enum.name()` の写し `fareTypeCdName` を分けた（`EnumTypeHandler` の出典は `bind` にある）。
  * 軽微: D-014 の [Spec] の箇所の印が無く、premise が存在しない名前を挙げていた → `Spec.FlightSearch.searchFlight` に `@[gap "D-014"]` を付け、premise を改めた。D-001・D-002 の premise に `dev_D001S`・`dev_D002S` を書いた。
  * 軽微: `DateTimeUtil#toLocalDate(String)` は会員の検査が使う → Member へ移した。
  * 軽微（対応しない）: 整列の照合順序（`sortCfg`）は符号位置を前提とし、PostgreSQL の既定の照合はクラスタのロケールによる。整列キーの出発時刻は 4 桁の数字列で、どの照合でも順序は変わらないので、差異として登録しない（[backlog c7e8](../backlog/c7e8-lang-semantics-sql.md) の突き合わせは照合 C）。
  * 確かめて正しかったもの: Clock の 3 回の読み出しの対応、同順位の無さ、`null` の照会条件の扱い、`need_D032` の証人、スキルの補題の命題。
* [ADR cdb6](cdb6-flight-search-stage2-machines-seed-sql.md)（第 2 段）、[ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md)（第 1 段）、[ADR f353](f353-abs-026-proof-structure-nop-and-d027-scope.md)（空白の便名と `Query.Valid`）
* [backlog 0be7](../backlog/0be7-flight-search-usecase.md)、[spec/abstraction.md](../spec/abstraction.md#既知差異)、[spec/flight-search.md](../spec/flight-search.md#事前条件)
