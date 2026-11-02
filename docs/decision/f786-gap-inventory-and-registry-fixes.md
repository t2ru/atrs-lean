---
type: Architecture Decision Record
title: "SourceModel と Spec の差異の棚卸し: 登録簿の修正、D-034〜D-041 の登録、既存の差異の拡大"
description: "実装済み（マスタ・運賃・空席照会）と未着手（予約・会員・認証・レポート・HTTP）の全範囲で、上流の Java と Lean のモデル・仕様文書を登録簿 Abstraction.Gap と突き合わせた。誤記・古い記述・印の不足を直し、PRE の外の振る舞い D-034〜D-036、モデル外 D-037、前提型 D-038〜D-041 を登録し、D-006・D-009・D-020・D-030・D-033 と rTasks を広げた。REST の予約の応答の empty の欄は Spec を原典に合わせた。ADR 0b0c の保留 2 件を承認した。"
tags: [adr, abstraction, gap, source-model, spec, inventory]
id: "f786152a-22f7-43ba-b91b-a536c441a2fb"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー（各件の判断）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# SourceModel と Spec の差異の棚卸し: 登録簿の修正、D-034〜D-041 の登録、既存の差異の拡大

## Context and Problem Statement

[Spec] と [Source] の差異の正は、Lean の登録簿 `Abstraction.Gap`（`@[gap_entry]`。棚卸しの前は D-001〜D-033）である。[abstraction.md](../spec/abstraction.md#既知差異) の表は `trace manifest` がそこから生成する。
機能を取り込むたびに項目を足してきたので、登録簿が実装（`Spec`・`SourceModel`・`Abstraction`）と上流の原典の両方に合っているかを、全範囲で一度確かめる必要があった。範囲は、実装済みの機能（マスタ・設定・コードリストの読み込み、運賃計算、空席照会）と、未着手の機能（予約・会員・認証・予約履歴レポート・HTTP）の両方である。
規約は、差異の追加・拡大と PRE の強化をオーナーの判断事項とする（[atrs-porting.md](../rules/atrs-porting.md#進め方の適用atrs)）。そこで、誤記・古い記述・印の不足は直し、追加・拡大は一件ずつオーナーに判断を求めた。

## Decision Drivers

* 基本原則 3: [Spec] と [Source] の一致しない点を、証明と文書のすべてに明示する（[ADR c336](c336-foundational-principles.md)）
* 証明の範囲を変えないこと。PRE の外の振る舞いの登録は定理を変えない。未着手の機能の前提型の差異は `pending` とし、述語と W 課題は各機能の backlog で作る
* 登録の根拠を、上流のコード（固定 commit）か Java の原典実行の採取に置くこと。ライブラリの内部の挙動に拠る候補は、原典実行で確かめてから判断する

## Considered Options

* 棚卸しの結果を登録簿に反映する（誤記は直し、追加・拡大は一件ずつ判断する）
* 報告だけを残し、登録簿は各機能の着手時に直す
* 候補をすべて未確定（`undetermined`）として登録する

## Decision Outcome

Chosen option: "棚卸しの結果を登録簿に反映する（誤記は直し、追加・拡大は一件ずつ判断する）", because 漏れ・誤りを見つけた時点で登録簿と定理の仮定に出さないと、表と証明が実態を表さないからである。報告だけでは、後の機能の取り込みで同じ誤り（例: D-031 の R 課題）を写し続ける。未確定として一括で登録すると、コードで確定できる差異まで「形式化していない」になり、W 課題の予定が立たない。

### 方法

* 3 つの観点で突き合わせた。(1) 実装済みの範囲の `Spec` の PRE の各成分・`@[deviation]`・環境の前提と、登録簿の対応、`@[gap]` の印。(2) 未着手の機能の上流の Java（コントローラ・フォーム・サービス・Mapper・設定・メッセージ）と `docs/spec` の定義。(3) 登録簿の欄（R 課題・site・前提）と、課題表・仕様文書の記述の一致。
* 手順は、スキル spec-pivot の [ADR cb1f](../../.agents/skills/spec-pivot/references/docs/decision/cb1f-gap-inventory-procedure.md) で、方法の文書（棚卸しの手順）にした。

### 修正（判断を要しないもの）

* D-031 の R 課題が `ABS-021`（採番ポート）になっていた誤りを、往復の便の検査を通る ABS-031・ABS-041・ABS-045 に直し、site を `reservation.md#validateflightlist` にした（予約の第 1 段の [ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md) も、同じ修正を確認待ちとして入れていた。ここで承認とする）。課題表の差異列にも D-031 を足した。
* D-032 の説明・前提が、存在しない欄 `groupingSeparator` を指していた。実際の前提 `dev_D032` は `formatSymbols = Symbols.ascii`（区切り文字・零の数字・負号）で、種類は具体側の環境である。
* D-030 の証拠が数の定数を指していた。PRE の述語（`MD8`・`FareInput.Pre`）に直し、`MD8` などに印を付けた。割引率 > 100 では折り返しでなく `Assert` になることを書いた。
* `Spec.Fare` と [fare-calculation.md](../spec/fare-calculation.md) が、搭乗クラス・運賃種別の存在を「PRE: MD-3」としていた。MD-3 は区間の空港と便マスタの区間だけを課すので、各操作の PRE と書き直した（PRE の外の振る舞いは D-035）。
* 前提の文のモジュール名（`Abstraction.Fare.Alpha` など）、D-029 の前提の文、D-007 の影響、D-010・D-019・D-022 の site、D-006・D-018 の説明を直した。
* 欠けていた `@[gap]` の印を足した（`getFlightMaster` に D-033、`jdbcCodeList` に D-015、`CL_AIRPORT` に D-029、`MasterDb`・`AtrsConfig` に D-027、`calculateFare`・`calculateTotalFare`・`Range.maxBasicFare` に D-030）。
* 仕様文書の D 番号の引用の不足（D-009・D-010・D-014・D-022・D-023・D-031）、[assurance.md](../spec/assurance.md) の被覆の例（D-012 は偽を証明済みで、被覆の例は現在無い）、[errors-and-messages.md](../spec/errors-and-messages.md) の表の中の段落を直した。

### オーナーの判断

| 件 | 判断 | 内容 |
| --- | --- | --- |
| D-034 | 登録（PRE の外） | マスタの問い合わせの引数が `Query.Valid` の外のとき、`Assert.hasText` の例外か、`-` を含む空港コードでの `RouteProvider.makeCacheKey` のキーの衝突 |
| D-035 | 登録（PRE の外） | 運賃計算の入力が `BasicFareInput.Pre`・`TotalFareInput.Pre` の外のとき、`NullPointerException`・`Assert`（これまでどの D 番号にも属していなかった） |
| D-033 | 拡大・承認 | `SearchInput.Pre` の照会の搭乗クラスの存在と空港コードの空白も含める。[ADR 0b0c](0b0c-flight-search-stage3-abs011.md) で確認待ちだった「D-033 の登録」と「D-014 の写しを Clock の読み出しごとに分けたこと」を承認する |
| D-036 | 登録（PRE の外） | マスタの空港コードが `WellFormed` でないとき、`RouteProvider.load` のキーの衝突と後勝ちの上書き |
| D-030 | 拡大 | 証拠に設定の不変条件 `Config.Valid`（`childFareRate ≤ 100`）を足す |
| R 課題 | 拡大 | D-032 に ABS-045、D-027 に ABS-031・ABS-041・ABS-045 |
| D-037 | 登録（モデル外） | 予約確定で、`validateReservation` と `registerReservation` が別のトランザクションになる（D-013 と同じ形） |
| D-038 | 登録（前提型・具体側の入力・中断） | 画面の予約で `passengerFormList[6]` 以降の欄を送ると、7 名以上の予約を登録する |
| D-039 | 登録（前提型・出力のみ） | 選択フライトの便名が Unicode の空白だけのとき、[Source] は `Assert.hasText` で 500、[Spec] は `InvalidRequest` |
| D-040 | 登録（前提型・出力のみ） | `GET /api/member/available` で U+3000 だけの値に、[Source] は 200、[Spec] は 404 |
| D-041 | 登録（前提型・具体側の入力・中断） | REST の JSON の `Integer` の欄に数字の文字列を渡しても、[Source] は受け付ける（原典実行の `tools/origin-run/http/postTicket.json`） |
| REST の 201 の `"empty": false` | [Spec] を原典に合わせる | 外部の利用者が観測する API の形なので、差異にせず [http-contract.md](../spec/http-contract.md#post-apiv1ticket) の応答に加えた |
| D-006 | 拡大 | 予約履歴レポートの一覧の並び（[Source] は UTF-16 の符号単位の順）も含め、前提にレポートの領域のファイル名を加える |
| D-009 | 拡大 | 予約フライト番号・搭乗者番号は `INT` 列と `resultType="Integer"` なので、2,147,483,648 から失敗する。前提に「次の値が 2,147,483,647 以下」を加える（[ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md) が確認待ちで入れた同じ拡大を、ここで承認とする） |
| D-020 | 拡大 | `?redo`・`?confirm` の再表示・`?backToSearch`（送られた `flightType` を使う）を含める |

新しい前提型の差異の W 課題は ABS-138〜ABS-141 とし、課題表に行を足した。

### 保留（原典実行で確かめてから判断する）

ライブラリ（Spring・Jackson・Hibernate Validator）の内部の挙動に拠る次の候補は、[backlog ceb8](../backlog/ceb8-origin-run-checks-for-gap-candidates.md) で HTTP レベルの原典実行にかけてから判断する。

* 10 文字の空白（U+3000 など）のログイン ID で、ログインの失敗でなく 500 になる
* 予約履歴レポートの取得で、空の `reportName` が 400 になる
* 画面の整数の欄の緩い解析（空白の除去・16 進・全角数字）
* REST の JSON の小数・日付の別の形の受理（D-021・D-041 の拡大の候補）
* `Digits` のメッセージの引数の順、REST の `NotNull` のメッセージキーが当たらないこと
* JVM の既定のロケールに依存するメッセージの解決
* 変換に失敗した欄だけを持つ搭乗者の行が「空」とみなされること
* 変換の失敗で `?redo` などが 400 になること、`GET /api/v1/ticket/check` の `details` の有無
* レポートの公開の移動の原子性（[assurance.md](../spec/assurance.md#移植元ソース--sourcemodel)）

### Consequences

* Good, because 実装済みの範囲で、`Spec` の PRE の各成分がどれかの D 番号（差異か PRE の外）に結びついた
* Good, because 未着手の機能の着手時に、仮定に置くべき差異が登録簿と課題表にそろっている
* Bad, because 登録の数が増え（D-041 まで）、未着手の機能の `pending` の指摘（TR-K・TR-D の段階導入）が増える
* 生成表と `trace/manifest.json` は、作業の途中で Lean を使えなかったため生成器の規則を写して書いた。その後 Lean 4.35.0 を導入し、本物の `trace manifest --check` が一致を確かめた

### Confirmation

* CI の `lean:build`・`lean:obligations`（GK・TR-G）・`trace:check`（TR-K・TR-D）・`trace:manifest --check`・`docs:okf`・`docs:ids` が通る。
* 登録簿の R 課題と課題表の差異列の一致は、いまは検査が無い。スキルの [backlog 937d](../../.agents/skills/spec-pivot/references/docs/backlog/937d-rtasks-task-table-consistency-check.md) で検査を足す。

## More Information

* 登録簿: `lean/Abstraction/Gap.lean`。表: [abstraction.md](../spec/abstraction.md#既知差異)。
* 上流: `upstream/atrs` の固定 commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`（`JavaConfig-Thymeleaf/`）。
