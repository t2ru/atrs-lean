import Trace
import Abstraction.MasterData
import Abstraction.Fare
import Abstraction.FlightSearch
import Abstraction.Reserve.Alpha
import Abstraction.Reserve

/-!
# Abstraction.Gap

[Spec] と [Source] のギャップの登録簿（正）。既知差異（前提型・観測型・モデル外）、[Spec] の PRE の外での [Source] の振る舞い、
未確定の差異を、ID ごとに 1 つの宣言として置く（ADR cc24・spec-pivot の `references/docs/lang/lean/trace-attributes.md`）。

- 説明（`docs/spec/abstraction.md` の表の「差異」「振る舞い」「状況」の列）は docstring に書く。
- `docs/spec/abstraction.md` の 4 つの表は、`trace manifest`（spec-pivot の `scripts/trace`）がここから生成する。表を手で直してはならない。
- 前提型・観測型の述語・成分（`dev_DNNN`・`obs_DNNN`）は、各機能の `Abstraction.<機能>` に `@[deviation]` を付けて置く。
- ギャップが生じる `Spec`・`SourceModel` の定義には、`@[gap "D-NNN"]` を付ける（検査 TR-K）。
-/

namespace Abstraction.Gap
open Trace.Attr

open Trace Trace.Gap

/-- [Source] は `(ratio * 0.01)` を double で掛けて切り捨てる。[Spec] は `floorDiv(x * ratio, 100)`。[Source] は [Spec] に等しいか 1 小さい。1 小さいのは、`x·ratio` が 100 で割り切れ（厳密値が整数）、積算比率の因子 `fl(ratio × fl(0.01))` が `ratio/100` を `2^-54` 以上下回る（安全でない）ときに限る（`Abstraction.Fare.Factors.basicFare_src`）。安全でない積算比率は 1〜1000 のうち 49 個（29, 58, 116, 117, 141, 205, …。`basicFactor_unsafe`）で、シードの比率（100・110・120・125・130・140・150）は安全である。条件は十分条件で、安全でない比率でも差異が起きるとは限らない（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） -/
@[gap_entry]
def D001 : Gap where
  id := gid!"D-001"
  sites := ne![⟨ne!"基本運賃", ne!"docs/spec/fare-calculation.md#基本運賃", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D001`（`Abstraction.Fare.Alpha`。抽象側の入力の述語）: `x = routeBasicFare + extraCharge`・`ratio` = 出発日の積算比率について、`x·ratio` が 100 で割り切れないか、`ratio` が安全でない積算比率の一覧 `unsafeBasicRatios` に無い（`basicFare_src_eq'`）。合計金額では、各フライトに同じ条件を課す（`dev_D001T`）。空席照会では、搭乗日が照会可能期間の内で区間があるとき、照会の区間・搭乗クラス・搭乗日に課す（`dev_D001S`）。予約では、合計金額の入力 `tfOf` に `dev_D001T` を課す（`dev_D001R`）"
    evidence := .refuted ne![``Abstraction.Fare.Alpha.dev_D001, ``Abstraction.Fare.TotalAlpha.dev_D001T, ``Abstraction.FlightSearch.Alpha.dev_D001S, ``Abstraction.Reserve.Alpha.dev_D001R] ne![``Abstraction.Fare.need_D001]
    rTasks := ne![oid!"ABS-001", oid!"ABS-004", oid!"ABS-011", oid!"ABS-031", oid!"ABS-041", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"予約確定で、差のある運賃が合計金額として保存される"
    backlog := ne![bid!"bbcce088-c475-4378-9cc6-e3d821acc0f5"] }

/-- [Source] は `1 - rate*0.01` の丸め誤差により、厳密値が整数 `k` で `k ≡ 1 (mod 100)` のとき、切り捨てた値が `k − 1` になって 100 円少なくなる（例: 1430 円・30% で [Source] 1000、[Spec] 1100）。[Source] は [Spec] に等しいか 100 円少なく、少ないのは `b·(100−r) ≡ 100 (mod 10000)` で、割引率の因子 `fl(1 − fl(r × fl(0.01)))` が安全でないときに限る（`Abstraction.Fare.Factors.fare_src`）。安全でない割引率は 0〜99 のうち 33 個（6, 7, 30〜35, 53〜57, 65〜70, 77〜83, 89〜95。`fareFactor_unsafe`）で、シードの割引率 0・5・10・20 は安全、30 は安全でない（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） -/
@[gap_entry]
def D002 : Gap where
  id := gid!"D-002"
  sites := ne![⟨ne!"運賃", ne!"docs/spec/fare-calculation.md#運賃", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D002`（`Abstraction.Fare.Alpha`。抽象側の入力の述語）: `b·(100−r) mod 10000 ≠ 100` か、`r` が安全でない割引率の一覧 `unsafeDiscountRates` に無い（`fare_src_eq'`）。合計金額では、各フライトに同じ条件を課す（`dev_D002T`）。空席照会では、搭乗日が照会可能期間の内で区間があるとき、照会の基本運賃と、照会の片道・往復の運賃種別のすべての割引率に課す（`dev_D002S`。候補に現れない運賃種別にも課す十分条件）。予約では、合計金額の入力 `tfOf` に `dev_D002T` を課す（`dev_D002R`）"
    evidence := .refuted ne![``Abstraction.Fare.Alpha.dev_D002, ``Abstraction.Fare.TotalAlpha.dev_D002T, ``Abstraction.FlightSearch.Alpha.dev_D002S, ``Abstraction.Reserve.Alpha.dev_D002R] ne![``Abstraction.Fare.need_D002]
    rTasks := ne![oid!"ABS-002", oid!"ABS-004", oid!"ABS-011", oid!"ABS-031", oid!"ABS-041", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"同上"
    backlog := ne![bid!"bbcce088-c475-4378-9cc6-e3d821acc0f5"] }

/-- `discountRate > childFareRate` のとき小児分が負になり、0 方向に切り捨てる -/
@[gap_entry]
def D003 : Gap where
  id := gid!"D-003"
  sites := ne![⟨ne!"合計金額", ne!"docs/spec/fare-calculation.md#合計金額", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE MD-7"
    pre := [``Spec.MasterData.MD7]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- 期間が重なる場合、取得順（未規定）で最初に一致したものを使う -/
@[gap_entry]
def D004 : Gap where
  id := gid!"D-004"
  sites := ne![⟨ne!"ピーク時期", ne!"docs/spec/master-data.md#参照関数", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE MD-4"
    pre := [``Spec.MasterData.MD4]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- 同一区間に同じ出発時刻の便があると、1 グループに統合し、運賃種別ごとに後勝ちになる -/
@[gap_entry]
def D005 : Gap where
  id := gid!"D-005"
  sites := ne![⟨ne!"空席照会の集約", ne!"docs/spec/flight-search.md#searchflight", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE MD-5"
    pre := [``Spec.MasterData.MD5]
    backlog := [bid!"0be7c5d4-01d9-43f4-a50d-227f174830f0"] }

/-- [Source] は UTF-16 単位、[Spec] はスカラ値単位で長さを数える。予約履歴レポートの一覧の並び（`List.sort(Collections.reverseOrder())`）も、[Source] は UTF-16 の符号単位の順、[Spec] はスカラ値の順で、補助文字と U+E000〜U+FFFF の文字を含むファイル名で異なる -/
@[gap_entry]
def D006 : Gap where
  id := gid!"D-006"
  sites := ne![⟨ne!"文字列長", ne!"docs/spec/input-validation.md#文字クラス", ""⟩, ⟨ne!"ログインの事前検査", ne!"docs/spec/authentication.md#ログインlogin", ""⟩, ⟨ne!"レポート要求の長さ", ne!"docs/spec/reservation-history-report.md#要求の受信onreportrequested", ""⟩, ⟨ne!"レポートの一覧の並び", ne!"docs/spec/reservation-history-report.md#一覧listreports", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D006`: 入力が補助文字（U+10000 以上）を含まない。予約履歴レポートでは、会員の領域のファイル名も補助文字を含まない"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-106")
    rTasks := ne![oid!"ABS-031", oid!"ABS-034", oid!"ABS-042", oid!"ABS-043", oid!"ABS-044", oid!"ABS-045", oid!"ABS-046"]
    impact := .abort
    impactReason := ne!"入力検証・ログインの事前検査の合否が変わり、会員登録・会員情報変更・予約・ログイン・レポート要求の成否が変わる"
    backlog := ne![bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2", bid!"ac713033-9b94-4e5a-bfc4-d27bdee7ee2e"] }

/-- [Source] は相関検証を適用しない（原典の不具合）。[Spec] は相関検証を適用し、さらに搭乗者リストの要素数を 1〜6 に制限する（[input-validation.md](input-validation.md#予約入力b2)） -/
@[gap_entry]
def D007 : Gap where
  id := gid!"D-007"
  sites := ne![⟨ne!"REST 予約 API", ne!"docs/spec/http-contract.md#post-apiv1ticket", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D007`: 入力が相関検証を満たし、搭乗者が 1〜6 名"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-107")
    rTasks := ne![oid!"ABS-031"]
    impact := .abort
    impactReason := ne!"[Source] は [Spec] が拒む予約を登録するか、DB の列の制約（`REP_TEL VARCHAR(13)` など）・前提違反で 500 になる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- [Source] の表示名「登場クラスコード」は誤記。[Spec] は「搭乗クラスコード」 -/
@[gap_entry]
def D008 : Gap where
  id := gid!"D-008"
  sites := ne![⟨ne!"表示名", ne!"docs/spec/errors-and-messages.md#項目の表示名", ""⟩]
  body := .observational {
    component := ne!"`obs_D008`: エラーメッセージの表示名の対応で、[Source] の「登場クラスコード」を [Spec] の「搭乗クラスコード」に対応させる"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-108")
    rTasks := ne![oid!"ABS-031", oid!"ABS-045", oid!"ABS-046"]
    backlog := [bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2"] }

/-- [Source] のシーケンスは最大値の後に 1 へ循環し、使用済みの値を返しうる。[Spec] は常に未使用の値を返す。
さらに、予約フライト番号・搭乗者番号の列（`RESERVE_FLIGHT_NO`・`PASSENGER_NO`）は `INT` で、`selectKey` は
`resultType="Integer"` なので、シーケンスの値が 2,147,483,647 を超えると（シーケンスの最大値 999,999,999,999・
9,999,999,999,999 より前に）JDBC の読み出しが失敗する（backlog aedf で範囲を広げ、ADR f786 でプロジェクトオーナーが承認した） -/
@[gap_entry]
def D009 : Gap where
  id := gid!"D-009"
  sites := ne![⟨ne!"採番", ne!"docs/spec/ports.md#idgenerator", ""⟩, ⟨ne!"予約の登録", ne!"docs/spec/reservation.md#予約確定reserve", "予約フライト番号・搭乗者番号の INT"⟩]
  body := .pre {
    side := .concreteState
    premise := ne!"`dev_D009`（`Abstraction.Reserve.Alpha`。抽象側の状態と入力の述語）: 予約確定では、採番の次の値から 1 回の予約確定が使う番号（予約番号 1、予約フライト番号 2 まで、搭乗者番号 12 まで）が、予約番号ではシーケンスの最大値 9,999,999,999 以下、予約フライト番号・搭乗者番号では INT の最大値 2,147,483,647 以下。会員番号（会員登録）は backlog 4e0e で課す"
    evidence := .refuted ne![``Abstraction.Reserve.Alpha.dev_D009] ne![``Abstraction.Reserve.need_D009]
    rTasks := ne![oid!"ABS-031", oid!"ABS-041", oid!"ABS-042", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"使用済みの番号による挿入の失敗、既存の行との衝突、または int32 を超える番号での採番・挿入の失敗"
    backlog := ne![bid!"aedfeffc-3e82-46b1-b497-3d8b7808d068"] }

/-- 登録・更新の件数 ≠ 1 で `System("e.ar.a0.L9002")` になる -/
@[gap_entry]
def D010 : Gap where
  id := gid!"D-010"
  sites := ne![⟨ne!"更新件数", ne!"docs/spec/reservation.md#予約確定reserve", ""⟩, ⟨ne!"ログイン", ne!"docs/spec/authentication.md#ログインlogin", ""⟩, ⟨ne!"ログアウト", ne!"docs/spec/authentication.md#ログアウトlogout", ""⟩, ⟨ne!"会員登録", ne!"docs/spec/member.md#会員登録register", ""⟩, ⟨ne!"会員情報変更", ne!"docs/spec/member.md#会員情報変更update", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"`J` と INV（キーが存在する）。到達しないことは ABS-022 で示す"
    pre := []
    backlog := [bid!"aedfeffc-3e82-46b1-b497-3d8b7808d068", bid!"44f89eb1-e59a-4573-8129-7b0c1d4699bb", bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2"] }

/-- [Source] はドメイン部を `IDN.toASCII` で変換し、失敗すれば不合格とし、変換後の長さで 255 を判定する。[Spec] は変換しない（[ADR ac33](../decision/ac33-email-validation-rule.md)） -/
@[gap_entry]
def D011 : Gap where
  id := gid!"D-011"
  sites := ne![⟨ne!"Email", ne!"docs/spec/input-validation.md#email", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D011`: ドメイン部が ASCII だけからなる"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-111")
    rTasks := ne![oid!"ABS-031", oid!"ABS-034", oid!"ABS-042", oid!"ABS-045", oid!"ABS-046"]
    impact := .abort
    impactReason := ne!"入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる"
    backlog := ne![bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2"] }

/-- [Source] の小児分の途中計算 `j32mul(b, childFareRate − r)` は、`b × (childFareRate − r) > 2,147,483,647` のとき int32 で折り返す（値域の上限 `b = 100,000,000` では最大 約 1e10）。[Spec] は任意精度 -/
@[gap_entry]
def D012 : Gap where
  id := gid!"D-012"
  sites := ne![⟨ne!"合計金額", ne!"docs/spec/fare-calculation.md#合計金額", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D012`（`Abstraction.Fare.TotalAlpha`。抽象側の入力の述語）: 各フライトで、基本運賃 `b`・割引率 `r` について `b × (childFareRate − r) ≤ 2,147,483,647`（小児がいなくても課す十分条件）。予約では、合計金額の入力 `tfOf` に課す（`dev_D012R`）"
    evidence := .refuted ne![``Abstraction.Fare.TotalAlpha.dev_D012, ``Abstraction.Reserve.Alpha.dev_D012R] ne![``Abstraction.Fare.need_D012]
    rTasks := ne![oid!"ABS-004", oid!"ABS-031", oid!"ABS-041", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"折り返した合計金額が保存される"
    backlog := ne![bid!"bbcce088-c475-4378-9cc6-e3d821acc0f5"] }

/-- D-013 の主張（形式化していない。証明も公理も持たない）: [Source] の会員情報変更は、現在パスワードの照合と更新を別のトランザクションで行うので、並行実行の下では、[Spec]（1 トランザクション）と観測が異なりうる。どのモデルも並行実行を表さないので、命題として書けない -/
@[gap "D-013"] opaque claim_D013 : Prop

/-- [Source] は、現在パスワードの照合と更新を別のトランザクションで行う。[Spec] は 1 トランザクションで行う（[ADR 578b](../decision/578b-member-update-in-single-transaction.md)）。違いが観測できるのは並行実行のときだけである。各モデルは各ユースケースを 1 つの原子的な操作として扱うので、[Source] の具体機械でも 1 つの操作として写す -/
@[gap_entry]
def D013 : Gap where
  id := gid!"D-013"
  sites := ne![⟨ne!"会員情報変更", ne!"docs/spec/member.md#会員情報変更update", ""⟩, ⟨ne!"トランザクション", ne!"docs/spec/ports.md#トランザクション", "（規範節）"⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（並行実行はモデルに現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
    claim := ``claim_D013
    resolution := ""
    backlog := [] }

/-- [Source] は `today()` を呼ぶたびに現在日付を読む。そのため、日付をまたいで実行されたユースケースの中で今日が変わりうる。[Spec] はユースケースの初めに 1 回だけ読む -/
@[gap_entry]
def D014 : Gap where
  id := gid!"D-014"
  sites := ne![⟨ne!"Clock", ne!"docs/spec/ports.md#clock", ""⟩]
  body := .pre {
    side := .concreteEnv
    premise := ne!"1 つのユースケースの中で、[Source] の Clock の各呼び出しが同じ日付を返す（機能ごとの具体側の環境の述語）。空席照会では `dev_D014S`（`Abstraction.FlightSearch.Alpha`）: `TicketSharedServiceImpl` の `validateDepatureDate`・`getSearchLimitDate` が読む今日の日付が、`searchFlight` の今日の日付と同じ。予約では `dev_D014R`（`Abstraction.Reserve.Alpha`）: 1 回の操作の中で、Clock のどの読み出しも最初の読み出しと同じ日付（予約確定の予約日と、予約フライトごとの `isAvailableFareType` の今日が同じ）"
    evidence := .refuted ne![``Abstraction.FlightSearch.Alpha.dev_D014S, ``Abstraction.Reserve.Alpha.dev_D014R] ne![``Abstraction.FlightSearch.need_D014]
    rTasks := ne![oid!"ABS-011", oid!"ABS-031", oid!"ABS-041", oid!"ABS-044", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"日付をまたぐと、予約・レポートに記録される日付が変わりうる"
    backlog := ne![bid!"aedfeffc-3e82-46b1-b497-3d8b7808d068", bid!"0be7c5d4-01d9-43f4-a50d-227f174830f0"] }

/-- MD-1〜MD-3 が破れると、後勝ちの上書きか、`null` による前提違反になる -/
@[gap_entry]
def D015 : Gap where
  id := gid!"D-015"
  sites := ne![⟨ne!"マスタの不変条件", ne!"docs/spec/master-data.md#不変条件spec", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE MD-1〜MD-3"
    pre := [``Spec.MasterData.MD1, ``Spec.MasterData.MD2, ``Spec.MasterData.MD3]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- D-016 の主張（形式化していない。証明も公理も持たない）: [Source] のログインはセッション ID を変えないので、セッション固定化の攻撃に対して [Spec] と振る舞いが異なる。セッション ID はどのモデルにも現れないので、命題として書けない -/
@[gap "D-016"] opaque claim_D016 : Prop

/-- [Source] はログイン時にセッション ID を変えない（セッション固定化の対策が無い）。[Spec] は新しい ID に変える -/
@[gap_entry]
def D016 : Gap where
  id := gid!"D-016"
  sites := ne![⟨ne!"セッション", ne!"docs/spec/http-contract.md#セッション", "（規範節）"⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（セッション ID は [Spec] の外の規範節で定め、どのモデルにも現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
    claim := ``claim_D016
    resolution := ""
    backlog := [] }

/-- [Source] は `redirectTo` の絶対 URL（外部サイト）へもリダイレクトする。[Spec] はアプリ内のパスだけを受け付ける -/
@[gap_entry]
def D017 : Gap where
  id := gid!"D-017"
  sites := ne![⟨ne!"ログイン成功時の遷移先", ne!"docs/spec/http-contract.md#認証と権限", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D017`: `redirectTo` が無いか、`/` で始まり `//` で始まらない"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-117")
    rTasks := ne![oid!"ABS-045"]
    impact := .outputOnly
    impactReason := ne!"ログインの成否と状態更新は同じで、遷移先だけが異なる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- [Source] は文字列の `Min`・`Max` を `BigDecimal` として判定する（`"1.5"`, `"+1"`, `"1e1"`、Unicode の十進数字 `"１２"` も数になる）。`creditTerm` が 6 文字以上なら、DB の `VARCHAR(5)` 違反でシステムエラーになる（会員登録・会員情報変更）。[Spec] は十進整数だけを数とし、長さの上限を持たない -/
@[gap_entry]
def D018 : Gap where
  id := gid!"D-018"
  sites := ne![⟨ne!"Min/Max", ne!"docs/spec/input-validation.md#文字クラス", ""⟩, ⟨ne!"creditTerm", ne!"docs/spec/domain-model.md#member", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D018`: `creditMonth`・`creditYear` が `[0-9]+` で、`creditTerm` が 5 文字以下"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-118")
    rTasks := ne![oid!"ABS-031", oid!"ABS-034", oid!"ABS-042", oid!"ABS-045", oid!"ABS-046"]
    impact := .abort
    impactReason := ne!"入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる"
    backlog := ne![bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2"] }

/-- [Source] は曜日を要求のロケールで表示する（テンプレート `tmpl:` の書式処理 `#temporals.format(…,'MM月dd日(E)')`。予約完了画面の支払期限と、予約入力・予約確認・予約失敗の画面の搭乗日）。[Spec] は常に日本語で表示する -/
@[gap_entry]
def D019 : Gap where
  id := gid!"D-019"
  sites := ne![⟨ne!"支払期限・搭乗日の表示", ne!"docs/spec/domain-model.md#書式", ""⟩]
  body := .pre {
    side := .concreteInput
    premise := ne!"`dev_D019`: `Accept-Language` が日本語"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-119")
    rTasks := ne![oid!"ABS-045"]
    impact := .outputOnly
    impactReason := ne!"曜日の表示だけが異なる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- `GET /ticket/reserve?form` で、便名・搭乗日・搭乗クラス・運賃種別の欠落や、マスタに無い値を渡すと、[Source] は `NullPointerException`・`Assert` で 500 を返す。[Spec] は `InvalidRequest` で 400 を返す（[Spec] が振る舞いを定める入力なので PRE の内）。同じことが、フライトの表示を組み立てる `POST /ticket/reserve?redo`・`POST ?confirm` の入力エラーでの再表示・`POST ?backToSearch` でも起きる。さらに `?backToSearch` では、[Source] は送られた `flightType` で照会条件を復元する（無ければ 400）。[Spec] は選択数から決める（`flightType = (選択数 = 2 ? RT : OW)`） -/
@[gap_entry]
def D020 : Gap where
  id := gid!"D-020"
  sites := ne![⟨ne!"予約入力画面の表示・照会へ戻る", ne!"docs/spec/http-contract.md#b2-予約", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D020`: 選択フライトの全項目（便名・搭乗日・搭乗クラス・運賃種別）が与えられ、それぞれマスタで解決できる。`?backToSearch` では、送られた `flightType` が選択数から決まる値に等しい"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-120")
    rTasks := ne![oid!"ABS-045"]
    impact := .outputOnly
    impactReason := ne!"予約入力画面の表示・再表示と照会へ戻る遷移（状態を変えない）の応答だけが異なる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- [Source] は、符号付きの 5 桁以上の年（`+10000/01/01`）と 0 以下の年も受け付ける。[Spec] は 4 桁の年 1〜9999 だけを受け付ける -/
@[gap_entry]
def D021 : Gap where
  id := gid!"D-021"
  sites := ne![⟨ne!"日付の解析", ne!"docs/spec/input-validation.md#日付の解析", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D021`: 年が符号無しの 4 桁で 1 以上"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-121")
    rTasks := ne![oid!"ABS-031", oid!"ABS-045", oid!"ABS-046"]
    impact := .abort
    impactReason := ne!"入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる"
    backlog := ne![bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2"] }

/-- [Source] の単項目の検証エラーは順序不定（Bean Validation の `HashSet`）。[Spec] は定順の列。[Source] のほうが非決定性が大きいので、エラーの列を多重集合として比べる成分を、名前付きで置く -/
@[gap_entry]
def D022 : Gap where
  id := gid!"D-022"
  sites := ne![⟨ne!"入力検証エラーの並び", ne!"docs/spec/input-validation.md#検証の順序とエラーの並び", ""⟩, ⟨ne!"ADR e24e", ne!"docs/decision/e24e-validation-error-ordering.md", ""⟩]
  body := .observational {
    component := ne!"`obs_D022`: 検証エラーの列を多重集合として対応させる"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-122")
    rTasks := ne![oid!"ABS-031", oid!"ABS-045", oid!"ABS-046"]
    backlog := [bid!"4e0e3dd1-d282-46e2-aa98-719853bc9fd2"] }

/-- D-023 の主張（形式化していない。証明も公理も持たない）: [Source] は JVM の既定のタイムゾーンで今日を決めるので、Asia/Tokyo 以外で実行すると [Spec] と今日が異なりうる。各モデルは今日を入力として受け取るので、命題として書けない -/
@[gap "D-023"] opaque claim_D023 : Prop

/-- [Spec] の本番の Clock は Asia/Tokyo で今日を決める。[Source] は JVM の既定のタイムゾーンで決める -/
@[gap_entry]
def D023 : Gap where
  id := gid!"D-023"
  sites := ne![⟨ne!"Clock", ne!"docs/spec/ports.md#clock", ""⟩, ⟨ne!"ADR 9ee4", ne!"docs/decision/9ee4-clock-timezone-and-fixture-base-date.md", ""⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（各モデルは「今日」を入力として受け取る。原典実行は JST で実行する。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
    claim := ``claim_D023
    resolution := ""
    backlog := [] }

/-- D-024 の主張（形式化していない。証明も公理も持たない）: [Source] のセッションの Cookie は `HttpOnly` だけを持ち、[Spec] の配備環境で決める属性（`Secure`・`SameSite`）と異なりうる。Cookie の属性はどのモデルにも現れないので、命題として書けない -/
@[gap "D-024"] opaque claim_D024 : Prop

/-- [Spec] は `HttpOnly` を付け、`Secure`・`SameSite` は配備環境で決める。[Source] は `HttpOnly` だけを付ける -/
@[gap_entry]
def D024 : Gap where
  id := gid!"D-024"
  sites := ne![⟨ne!"セッションの Cookie 属性", ne!"docs/spec/http-contract.md#セッション", "（規範節）"⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
    claim := ``claim_D024
    resolution := ""
    backlog := [] }

/-- D-025 の主張（形式化していない。証明も公理も持たない）: [Source] は PostgreSQL の READ COMMITTED で動くので、並行実行の下では、状態変更が直列化可能でないことがある。どのモデルも操作を原子的に扱うので、命題として書けない -/
@[gap "D-025"] opaque claim_D025 : Prop

/-- [Spec] は状態変更の直列化可能性を要求する。[Source] は PostgreSQL の READ COMMITTED で動き、一般には直列化可能でない（会員情報変更の事例は D-013 としてモデルに写す） -/
@[gap_entry]
def D025 : Gap where
  id := gid!"D-025"
  sites := ne![⟨ne!"トランザクション", ne!"docs/spec/ports.md#トランザクション", "（規範節）"⟩, ⟨ne!"ADR 97f9", ne!"docs/decision/97f9-persistence-and-transaction-semantics.md", ""⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（モデルでは操作は原子的である。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
    claim := ``claim_D025
    resolution := ""
    backlog := [] }

/-- [Source]（Jackson）は、JSON の文字列にある不対サロゲートのエスケープ（例 `"\ud800"`）を受け付け、不対サロゲートを含む文字列として処理する。[Spec] の文字列はスカラ値の列なので、その要求を `InvalidRequest` とする -/
@[gap_entry]
def D026 : Gap where
  id := gid!"D-026"
  sites := ne![⟨ne!"REST API", ne!"docs/spec/http-contract.md#rest-apiapiv1", ""⟩]
  body := .pre {
    side := .concreteInput
    premise := ne!"`dev_D026`: 要求の JSON の文字列に、不対サロゲートのエスケープを含まない"
    evidence := .pending [] ne!"Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some oid!"ABS-126")
    rTasks := ne![oid!"ABS-031", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"[Source] は [Spec] が拒む要求を処理し、状態を変えうる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- [Source] は、DB のマスタと注入された設定を起動時に読み込み、問い合わせの引数（`LocalDate` など）を受ける。値が [Spec] の型で表せないとき、[Source] は例外で起動しないか（未知の搭乗クラス・運賃種別のコード）、そのまま読み込む（`BOARDING_CLASS_NAME` の `NULL`、負の値・値域を超える値、`HHmm` で表せない時刻（到着時刻は翌日の 23:59 を超えるもの。[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）、範囲外の日付、`yyyy/MM/dd` でない生年月日の下限など）。[Spec] はそれらを入力に取らない。列の型は処理系の範囲（`Int4`・`PgDate`・`Varchar n`）で写すので、範囲の違いもこの差異の前提で扱う（[ADR c108](../decision/c108-master-data-source-model-and-spec-fixes.md)） -/
@[gap_entry]
def D027 : Gap where
  id := gid!"D-027"
  sites := ne![⟨ne!"マスタ", ne!"docs/spec/master-data.md", ""⟩, ⟨ne!"設定", ne!"docs/spec/configuration.md", ""⟩, ⟨ne!"空席照会の状態（FLIGHT 表）", ne!"docs/spec/ports.md#world抽象状態", ""⟩]
  body := .pre {
    side := .concreteInput
    premise := ne!"`dev_D027`（`Abstraction.MasterData.Alpha`）: 具体側の入力（DB のマスタの各行・設定・問い合わせの引数）が、[Spec] の型で表せる（`aiMQ` が定義される。コード値（空港コード・便名・会員番号・カード種別コード）の形式に合わない値を含まない。[ADR 6d36](../decision/6d36-misu-spec-types.md)）。問い合わせの日付が [Spec] の暦日（1〜9999 年）を超える場合を含む（[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）。運賃計算では、`dev_D027BF`（基本運賃。DB のマスタ・設定・`calculateBasicFare` の引数。`aiBF` が定義される。`null` と負の値を含まない）・`dev_D027F`（運賃。`calculateFare` の引数が負でない）・`dev_D027TF`（合計金額。DB のマスタ・設定・選択フライト情報（便名の形式を含む）・搭乗者。`aiTF` が定義される）（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)）。空席照会・予約では、状態の表とシーケンスも [Spec] の型で表せる（`Abstraction.World.Alpha.worldOfDb` が定義される。負の数・未知のコード・形式に合わない会員番号・暦日の外の日付・0:00 でないログイン日時・親の順に並ばない子の行を含まない）。初期状態（シードを投入した後の表）が前提を満たすこと（`Abstraction.World.Init.worldOfDb_seed`）は backlog aedf の第 3 段で示した。到達する状態が満たすことは、各 R 課題の正しさ（`J` を保つ）で示す。空席照会の入力の述語は `dev_D027S`（`aiS` が定義される）。予約の入力の述語は `dev_D027R`（`aiR` が定義され、業務例外の引数に使う運賃種別名が改行を含まない。`Abstraction.Reserve.Alpha`）。種類は「具体側の入力」のままとし、状態の部分は貼り合わせの部分写像（α が定義されない状態は `World` と結ばれない）で表す（[ADR cdb6](../decision/cdb6-flight-search-stage2-machines-seed-sql.md)）"
    evidence := .refuted ne![``Abstraction.MasterData.Alpha.dev_D027, ``Abstraction.Fare.Alpha.dev_D027BF, ``Abstraction.Fare.Alpha.dev_D027F, ``Abstraction.Fare.TotalAlpha.dev_D027TF, ``Abstraction.FlightSearch.Alpha.dev_D027S, ``Abstraction.Reserve.Alpha.dev_D027R] ne![``Abstraction.MasterData.need_D027]
    rTasks := ne![oid!"ABS-001", oid!"ABS-002", oid!"ABS-004", oid!"ABS-011", oid!"ABS-026", oid!"ABS-031", oid!"ABS-041", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"[Source] は起動しないか、[Spec] の型で表せないマスタ・設定で動き続ける"
    backlog := ne![bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227", bid!"bbcce088-c475-4378-9cc6-e3d821acc0f5"] }

/-- [Source] の画面ログイン（`POST /auth/dologin`）は、ログイン状態（`loginDateTime`・`loginFlg`）を更新しない。状態を更新する `AtrsAuthenticationSuccessListener` は `AuthenticationSuccessEvent` を受けるが、画面ログインのフィルタが使う`authenticationManager`（`new ProviderManager(authProvider)`）にはイベント発行者が無く、イベントが出ないためである。一方、REST の HTTP Basic 認証は、Spring Security が組み立てる認証マネージャ（イベント発行者付き）を使うので、成功のたびに`loginDateTime := today`・`loginFlg := true` に更新する。[Spec] は画面ログインで更新し、REST の要求では更新しない。Java の原典実行で確かめた（`tools/origin-run/http/login.json`。backlog f18c） -/
@[gap_entry]
def D028 : Gap where
  id := gid!"D-028"
  sites := ne![⟨ne!"ログイン時の状態更新", ne!"docs/spec/authentication.md#ログインlogin", "（`loginDateTime`・`loginFlg`）"⟩, ⟨ne!"REST の認証", ne!"docs/spec/http-contract.md#rest-apiapiv1", ""⟩]
  body := .observational {
    component := ne!"`obs_D028`（予定）: 貼り合わせで、会員のログイン状態（`loginDateTime`・`loginFlg`）を対応させない"
    evidence := .pending [] ne!"Lean に成分がまだ無い。認証の `SourceModel` と R 課題が未着手" (some oid!"ABS-128")
    rTasks := ne![oid!"ABS-043", oid!"ABS-045"]
    backlog := [bid!"44f89eb1-e59a-4573-8129-7b0c1d4699bb", bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- コードが区切り行と同じ `NOP` の空港があると、`LinkedHashMap` の同じキーへの `put` で、区切り行の表示がその空港の名前に置き換わり、空港の行は現れない -/
@[gap_entry]
def D029 : Gap where
  id := gid!"D-029"
  sites := ne![⟨ne!"空港コードリスト", ne!"docs/spec/master-data.md#空港コードリスト画面用", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE（MD-8 の第 1 連言のうち、空港のコードが `NOP` でないこと。[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）"
    pre := [``Spec.MasterData.MD8]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- マスタ・入力が値域の外のとき、int32 で折り返すか（`(int)` の縮小変換・`intValue` の切詰め）、`Assert` で前提違反になる（`calculateFare` の割引率 > 100） -/
@[gap_entry]
def D030 : Gap where
  id := gid!"D-030"
  sites := ne![⟨ne!"値域", ne!"docs/spec/domain-model.md#値域", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE（MD-8 の値域の連言、運賃の入力の値域 `FareInput.Pre`、設定の不変条件 `Config.Valid`（`childFareRate ≤ 100`））"
    pre := [``Spec.MasterData.MD8, ``Spec.Fare.FareInput.Pre, ``Spec.Config.Valid]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- [Source] の往復の予約の検査（`validateFlightDepartureDateForRoundTripFlight`）は、往路便の到着時刻を
`DateTimeFormatter("HHmm")`（SMART）で読むので、到着時刻が 24:00 より後（翌日着。シードの NTT523・NTT528 の `2415`）の便では
`DateTimeParseException` を投げる。`2400` は例外にならず、翌日 0:00 でなく当日 0:00 と読まれる（往路便の到着日時が 1 日早くなる）。[Spec] は到着時刻を出発日 0:00 からの時分で表し、往路便の到着日時を求められる
（[ADR ce36](../decision/ce36-flight-search-stage1-world-and-arrival-time.md)）。検査は `TicketSharedServiceImpl.validateFlightList` の中にあり、
画面の空席照会からの予約への遷移（`POST /ticket/search`）・画面の予約・REST の予約が呼ぶ。空席照会の照会（`searchFlight`）は到着時刻を
文字列として整形するだけなので、この差異は起きない -/
@[gap_entry]
def D031 : Gap where
  id := gid!"D-031"
  sites := ne![⟨ne!"往復の便の検査", ne!"docs/spec/reservation.md#validateflightlist", ""⟩, ⟨ne!"便マスタの到着時刻", ne!"docs/spec/master-data.md", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D031`（`Abstraction.Reserve.Alpha`。抽象側の入力の述語）: 往復の予約で、往路便の便マスタの到着時刻が 24:00 より前である"
    evidence := .refuted ne![``Abstraction.Reserve.Alpha.dev_D031] ne![``Abstraction.Reserve.need_D031]
    rTasks := ne![oid!"ABS-031", oid!"ABS-041", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"翌日着の便を往路とする往復の予約が、500 システムエラーになる（`2400` なら往路便の到着日時を 1 日早く検査する）"
    backlog := ne![bid!"0be7c5d4-01d9-43f4-a50d-227f174830f0", bid!"aedfeffc-3e82-46b1-b497-3d8b7808d068"] }

/-- [Source] の空席照会は、運賃を `new DecimalFormat("###,###")` で書式化する。記号（3 桁区切りの文字・零の数字・負号）は
JVM の既定の書式ロケール（`Locale.getDefault(Locale.Category.FORMAT)`）で決まる（例: ドイツ語では `20.600`）。[Spec] は常に ASCII の数字を
`,` で区切る（`fmtYen`）。モデル `SourceModel.Domain.Service.B1.TicketSearchServiceImpl.createFlightVacantInfoList` は、記号を
配備の環境 `formatSymbols`（`LangSemantics.Java.DecimalFormat.Symbols`）として受ける -/
@[gap_entry]
def D032 : Gap where
  id := gid!"D-032"
  sites := ne![⟨ne!"空席照会の運賃の書式", ne!"docs/spec/flight-search.md#出力-flightvacantinfo", ""⟩]
  body := .pre {
    side := .concreteEnv
    premise := ne!"`dev_D032`（`Abstraction.FlightSearch.Alpha`。具体側の環境の述語）: [Source] の JVM の既定の書式ロケールの記号（`SearchInput.formatSymbols`）が `Symbols.ascii`（3 桁区切りの文字 `,`・零の数字 `0`・負号 `-`。日本語・英語のロケール）である"
    evidence := .refuted ne![``Abstraction.FlightSearch.Alpha.dev_D032] ne![``Abstraction.FlightSearch.need_D032]
    rTasks := ne![oid!"ABS-011", oid!"ABS-045"]
    impact := .outputOnly
    impactReason := ne!"空席照会の運賃の表示だけが異なる"
    backlog := ne![bid!"0be7c5d4-01d9-43f4-a50d-227f174830f0"] }

/-- 空白の便名の便マスタが空席照会の結果に現れると、[Source] は `FlightMasterProvider.getFlightMaster` の `Assert.hasText` で
`IllegalArgumentException` を投げる。[Spec] は PRE で除く（照会の区間の便マスタに限る）。照会の空港コードが空白のとき（`Assert.hasText`）と、
照会の搭乗クラスがマスタに無いとき（`calculateBasicFare` の `NullPointerException`）も、[Source] は前提違反になる。[Spec] は `SearchInput.Pre` で除く -/
@[gap_entry]
def D033 : Gap where
  id := gid!"D-033"
  sites := ne![⟨ne!"空席照会の便マスタの参照", ne!"docs/spec/flight-search.md#事前条件", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE `FlightNamesHaveText`（照会の区間の便マスタの便名が空白でない）と `SearchInput.Pre` の連言（照会の搭乗クラスがマスタにあり、照会の空港コードが空白でない）"
    pre := [``Spec.FlightSearch.FlightNamesHaveText, ``Spec.FlightSearch.SearchInput.Pre]
    backlog := [bid!"0be7c5d4-01d9-43f4-a50d-227f174830f0"] }

/-- マスタの問い合わせの引数が `Query.Valid` を満たさないとき、[Source] は、便名・空港コードが空白なら
`FlightMasterProvider.getFlightMaster`・`RouteProvider.getRouteByAirportCd` の `Assert.hasText` で `IllegalArgumentException` を投げる。
空港コードが英大文字 3 文字でなく `-` を含むと、キャッシュのキー `[出発]-[到着]`（`RouteProvider.makeCacheKey`）が別の組と重なり、
別の区間を返しうる。[Spec] は PRE `Query.Valid` で除く -/
@[gap_entry]
def D034 : Gap where
  id := gid!"D-034"
  sites := ne![⟨ne!"マスタの参照関数の引数", ne!"docs/spec/master-data.md#参照関数", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE `Query.Valid`（空港コードが英大文字 3 文字、便名が形を満たし空白でない）"
    pre := [``Spec.MasterQuery.Query.Valid]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- 運賃計算の入力が PRE の外のとき、[Source] は前提違反になる。基本運賃では、搭乗クラスがマスタに無いと、`calculateBasicFare` が
`null` の搭乗クラスを参照して `NullPointerException` になる。合計金額では、便名が空白なら `Assert.hasText`、便マスタ・区間・搭乗クラス・
運賃種別がマスタに無ければ `NullPointerException`、フライト・搭乗者の列が空なら `Assert.notEmpty` になる。予約フライト数 1〜2・搭乗者数 1〜6・
年齢 0〜999 を超える入力は、[Spec] が値域で除く。[Spec] は `BasicFareInput.Pre`・`TotalFareInput.Pre` で除く。これらの条件は MD-3 に
含まれない（MD-3 は区間の空港と便マスタの区間だけを課す） -/
@[gap_entry]
def D035 : Gap where
  id := gid!"D-035"
  sites := ne![⟨ne!"基本運賃の事前条件", ne!"docs/spec/fare-calculation.md#基本運賃", ""⟩, ⟨ne!"合計金額", ne!"docs/spec/fare-calculation.md#合計金額", ""⟩]
  body := .outsidePre {
    excludingPre := ne!"PRE `BasicFareInput.Pre`（搭乗クラスがマスタに在る）・`TotalFareInput.Pre`（便名が空白でなく、便マスタ・区間・搭乗クラス・運賃種別がマスタに在り、フライト数・搭乗者数・年齢が値域の内）"
    pre := [``Spec.Fare.BasicFareInput.Pre, ``Spec.Fare.TotalFareInput.Pre]
    backlog := [bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227", bid!"bbcce088-c475-4378-9cc6-e3d821acc0f5"] }

/-- マスタの空港コードが英大文字 3 文字でないとき、[Source] の `RouteProvider.load` は、区間をキー `[出発]-[到着]`
（`RouteProvider.makeCacheKey`）で `put` するので、`-` を含むコードでは別の区間とキーが重なり、後勝ちで上書きする。
[Spec] の空港コード `AirportCd` は形式を型に持つので、そのようなマスタを表せない（D-027 に覆われる。ADR 6d36） -/
@[gap_entry]
def D036 : Gap where
  id := gid!"D-036"
  sites := ne![⟨ne!"コード値", ne!"docs/spec/domain-model.md#コード値", "（空港コードの形式）"⟩, ⟨ne!"マスタの不変条件", ne!"docs/spec/master-data.md#不変条件spec", ""⟩]
  body := .pre {
    side := .concreteInput
    premise := ne!"`dev_D036`（`Abstraction.MasterData.Alpha`）: DB のマスタの空港の行のコードが、どれも英大文字 3 文字（`AirportCd.valid`）である"
    evidence := .covered ne![``Abstraction.MasterData.Alpha.dev_D036] ``Abstraction.MasterData.Alpha.dev_D027 ne![``Abstraction.MasterData.covers_D036]
    rTasks := ne![oid!"ABS-026"]
    impact := .abort
    impactReason := ne!"[Source] は区間の照会で別の区間を返しうる。[Spec] の型はそのマスタを表せない"
    backlog := ne![bid!"25f7ef96-f77d-4ed8-973d-8cecc2a0f227"] }

/-- D-037 の主張（形式化していない。証明も公理も持たない）: [Source] の予約確定は、予約内容の検査（`validateReservation`）と登録（`registerReservation`）を別のトランザクションで行うので、並行実行の下では、[Spec]（1 トランザクション）と観測が異なりうる。どのモデルも並行実行を表さないので、命題として書けない -/
@[gap "D-037"] opaque claim_D037 : Prop

/-- [Source] の予約確定は、ヘルパー（`TicketReserveHelper.reserve`・REST の `TicketHelper`。トランザクションの外）から、`@Transactional` のサービスの `validateReservation` と `registerReservation` を別々に呼ぶ。そのため、検査と登録が別のトランザクションになる。[Spec] は 1 トランザクションで行う。違いが観測できるのは並行実行のときだけである（D-013 と同じ形）。各モデルは各ユースケースを 1 つの原子的な操作として扱う -/
@[gap_entry]
def D037 : Gap where
  id := gid!"D-037"
  sites := ne![⟨ne!"予約確定", ne!"docs/spec/reservation.md#予約確定reserve", ""⟩, ⟨ne!"トランザクション", ne!"docs/spec/ports.md#トランザクション", "（規範節）"⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（並行実行はモデルに現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
    claim := ``claim_D037
    resolution := ""
    backlog := [] }

/-- 画面の予約（`POST /ticket/reserve`・`?confirm`）で、要求が `passengerFormList[6]` 以降の欄を含むと、[Source] は Spring の
データバインダが搭乗者のリストを伸ばし（上限 256）、検証が搭乗者数の上限を持たないので、7 名以上の予約を受け付ける。
[Spec] の予約入力は搭乗者 6 枠で、搭乗者は 1〜6 名である -/
@[gap_entry]
def D038 : Gap where
  id := gid!"D-038"
  sites := ne![⟨ne!"予約入力", ne!"docs/spec/input-validation.md#ticketreserveinput", ""⟩, ⟨ne!"値域", ne!"docs/spec/domain-model.md#値域", ""⟩]
  body := .pre {
    side := .concreteInput
    premise := ne!"`dev_D038`: 画面の予約の要求が、`passengerFormList[6]` 以降の欄を含まない"
    evidence := .pending [] ne!"Lean に述語がまだ無い。HTTP の `SourceModel` と R 課題が未着手" (some oid!"ABS-138")
    rTasks := ne![oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"[Source] は [Spec] が表せない 7 名以上の予約を登録する"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44", bid!"aedfeffc-3e82-46b1-b497-3d8b7808d068"] }

/-- 選択フライトの便名が空白だけ（画面では前後の空白の除去で残る U+3000 など、REST では任意の空白）のとき、`@NotEmpty` は通るが、
[Source] は `FlightMasterProvider.getFlightMaster` の `Assert.hasText` で `IllegalArgumentException` を投げ、500（REST は `e.ar.fw.9999`）を返す。
[Spec] は便マスタが無いとして `InvalidRequest`（画面は 400、REST は `e.ar.a0.L9001` で 500）を返す。`POST /ticket/search`・`POST /ticket/reserve?confirm`・`POST /ticket/reserve`・`POST /api/v1/ticket` で起きる -/
@[gap_entry]
def D039 : Gap where
  id := gid!"D-039"
  sites := ne![⟨ne!"選択フライト", ne!"docs/spec/reservation.md#選択フライト", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D039`: 選択フライトの便名が、Unicode の空白（`Character.isWhitespace`）だけからなる文字列でない"
    evidence := .pending [] ne!"Lean に述語がまだ無い。予約・HTTP の `SourceModel` と R 課題が未着手" (some oid!"ABS-139")
    rTasks := ne![oid!"ABS-031", oid!"ABS-045"]
    impact := .outputOnly
    impactReason := ne!"どちらも状態を変えずに失敗し、エラーの種類（応答の状態コード・コード）だけが異なる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44", bid!"aedfeffc-3e82-46b1-b497-3d8b7808d068"] }

/-- `GET /api/member/available` の会員番号が、前後の空白（U+0000〜U+0020）を除いた後に U+3000 などの Unicode の空白だけからなるとき、
[Source] は `StringUtils.hasText` が偽なので 200 を返す。[Spec] は `isMember` を引いて 404 を返す -/
@[gap_entry]
def D040 : Gap where
  id := gid!"D-040"
  sites := ne![⟨ne!"会員番号の存在確認", ne!"docs/spec/http-contract.md#a0a1-トップログイン", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D040`: 会員番号の値が、前後の空白（U+0000〜U+0020）を除いた後に、Unicode の空白（`Character.isWhitespace`）だけからなる空でない文字列でない"
    evidence := .pending [] ne!"Lean に述語がまだ無い。HTTP の `SourceModel` と R 課題が未着手" (some oid!"ABS-140")
    rTasks := ne![oid!"ABS-045"]
    impact := .outputOnly
    impactReason := ne!"状態を変えない問い合わせの応答の状態コードだけが異なる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

/-- [Source]（Jackson）は、REST の要求の JSON で `Integer` の欄（`repAge`・`age`）に数字の文字列（例 `"repAge": "44"`）を渡しても、
数に変換して受け付ける（Java の原典実行で確かめた。`tools/origin-run/http/postTicket.json`）。[Spec] は JSON の数値だけを定め、
その要求を `InvalidRequest` とする。小数・その他の形の受理は確かめていない（backlog で原典実行にかける） -/
@[gap_entry]
def D041 : Gap where
  id := gid!"D-041"
  sites := ne![⟨ne!"REST API", ne!"docs/spec/http-contract.md#rest-apiapiv1", ""⟩]
  body := .pre {
    side := .concreteInput
    premise := ne!"`dev_D041`: 要求の JSON の `Integer` の欄が、JSON の数値である"
    evidence := .pending [] ne!"Lean に述語がまだ無い。HTTP の `SourceModel` と R 課題が未着手" (some oid!"ABS-141")
    rTasks := ne![oid!"ABS-031", oid!"ABS-045"]
    impact := .abort
    impactReason := ne!"[Source] は [Spec] が拒む要求を処理し、状態を変えうる"
    backlog := ne![bid!"a89ec8f0-4d15-46a6-86fa-a640e4df0b44"] }

end Abstraction.Gap
