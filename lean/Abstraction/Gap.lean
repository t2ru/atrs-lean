import Trace
import Abstraction.MasterData
import Abstraction.Fare

/-!
# Abstraction.Gap

[Spec] と [Source] のギャップの登録簿（正）。既知差異（前提型・観測型・モデル外）、[Spec] の PRE の外での [Source] の振る舞い、
未確定の差異を、ID ごとに 1 つの宣言として置く（ADR cc24・port-lang の `references/docs/lang/lean/trace-attributes.md`）。

- 説明（`docs/spec/abstraction.md` の表の「差異」「振る舞い」「状況」の列）は docstring に書く。
- `docs/spec/abstraction.md` の 4 つの表は、`trace manifest`（port-lang の `scripts/trace`）がここから生成する。表を手で直してはならない。
- 前提型・観測型の述語・成分（`dev_DNNN`・`obs_DNNN`）は、各機能の `Abstraction.<機能>` に `@[deviation]` を付けて置く。
- ギャップが生じる `Spec`・`SourceModel` の定義には、`@[gap "D-NNN"]` を付ける（検査 TR-K）。
-/

namespace Abstraction.Gap
open Trace.Attr

open Trace Trace.Gap

/-- [Source] は `(ratio * 0.01)` を double で掛けて切り捨てる。[Spec] は `floorDiv(x * ratio, 100)`。[Source] は [Spec] に等しいか 1 小さい。1 小さいのは、`x·ratio` が 100 で割り切れ（厳密値が整数）、積算比率の因子 `fl(ratio × fl(0.01))` が `ratio/100` を `2^-54` 以上下回る（安全でない）ときに限る（`Abstraction.Fare.Factors.basicFare_src`）。安全でない積算比率は 1〜1000 のうち 49 個（29, 58, 116, 117, 141, 205, …。`basicFactor_unsafe`）で、シードの比率（100・110・120・125・130・140・150）は安全である。条件は十分条件で、安全でない比率でも差異が起きるとは限らない（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） -/
@[gap_entry]
def D001 : Gap where
  id := "D-001"
  kind := .pre
  sites := [⟨"基本運賃", "docs/spec/fare-calculation.md#基本運賃", ""⟩]
  premise := "`dev_D001`（`Abstraction.Fare`。抽象側の入力の述語）: `x = routeBasicFare + extraCharge`・`ratio` = 出発日の積算比率について、`x·ratio` が 100 で割り切れないか、`ratio` が安全でない積算比率の一覧 `unsafeBasicRatios` に無い（`basicFare_src_eq'`）。合計金額では、各フライトに同じ条件を課す（`dev_D001T`）"
  deviations := [``Abstraction.Fare.Alpha.dev_D001, ``Abstraction.Fare.TotalAlpha.dev_D001T]
  evidence := .refuted [``Abstraction.Fare.need_D001]
  rTasks := ["ABS-001", "ABS-004", "ABS-011", "ABS-031", "ABS-041", "ABS-045"]
  impact := some (.abort, "予約確定で、差のある運賃が合計金額として保存される")
  backlog := ["bbcce088-c475-4378-9cc6-e3d821acc0f5"]

/-- [Source] は `1 - rate*0.01` の丸め誤差により、厳密値が整数 `k` で `k ≡ 1 (mod 100)` のとき、切り捨てた値が `k − 1` になって 100 円少なくなる（例: 1430 円・30% で [Source] 1000、[Spec] 1100）。[Source] は [Spec] に等しいか 100 円少なく、少ないのは `b·(100−r) ≡ 100 (mod 10000)` で、割引率の因子 `fl(1 − fl(r × fl(0.01)))` が安全でないときに限る（`Abstraction.Fare.Factors.fare_src`）。安全でない割引率は 0〜99 のうち 33 個（6, 7, 30〜35, 53〜57, 65〜70, 77〜83, 89〜95。`fareFactor_unsafe`）で、シードの割引率 0・5・10・20 は安全、30 は安全でない（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)） -/
@[gap_entry]
def D002 : Gap where
  id := "D-002"
  kind := .pre
  sites := [⟨"運賃", "docs/spec/fare-calculation.md#運賃", ""⟩]
  premise := "`dev_D002`（`Abstraction.Fare`。抽象側の入力の述語）: `b·(100−r) mod 10000 ≠ 100` か、`r` が安全でない割引率の一覧 `unsafeDiscountRates` に無い（`fare_src_eq'`）。合計金額では、各フライトに同じ条件を課す（`dev_D002T`）"
  deviations := [``Abstraction.Fare.Alpha.dev_D002, ``Abstraction.Fare.TotalAlpha.dev_D002T]
  evidence := .refuted [``Abstraction.Fare.need_D002]
  rTasks := ["ABS-002", "ABS-004", "ABS-011", "ABS-031", "ABS-041", "ABS-045"]
  impact := some (.abort, "同上")
  backlog := ["bbcce088-c475-4378-9cc6-e3d821acc0f5"]

/-- `discountRate > childFareRate` のとき小児分が負になり、0 方向に切り捨てる -/
@[gap_entry]
def D003 : Gap where
  id := "D-003"
  kind := .outsidePre
  sites := [⟨"合計金額", "docs/spec/fare-calculation.md#合計金額", ""⟩]
  premise := "PRE MD-7"
  evidence := .excludedBy [``Spec.MasterData.MD7]
  backlog := ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227"]

/-- 期間が重なる場合、取得順（未規定）で最初に一致したものを使う -/
@[gap_entry]
def D004 : Gap where
  id := "D-004"
  kind := .outsidePre
  sites := [⟨"ピーク時期", "docs/spec/master-data.md#参照関数", ""⟩]
  premise := "PRE MD-4"
  evidence := .excludedBy [``Spec.MasterData.MD4]
  backlog := ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227"]

/-- 同一区間に同じ出発時刻の便があると、1 グループに統合し、運賃種別ごとに後勝ちになる -/
@[gap_entry]
def D005 : Gap where
  id := "D-005"
  kind := .outsidePre
  sites := [⟨"空席照会の集約", "docs/spec/flight-search.md#searchflight", ""⟩]
  premise := "PRE MD-5"
  evidence := .excludedBy [``Spec.MasterData.MD5]
  backlog := ["0be7c5d4-01d9-43f4-a50d-227f174830f0"]

/-- [Source] は UTF-16 単位、[Spec] はスカラ値単位で長さを数える -/
@[gap_entry]
def D006 : Gap where
  id := "D-006"
  kind := .pre
  sites := [⟨"文字列長", "docs/spec/input-validation.md#文字クラス", ""⟩, ⟨"ログインの事前検査", "docs/spec/authentication.md#ログインlogin", ""⟩, ⟨"レポート要求の長さ", "docs/spec/reservation-history-report.md#要求の受信onreportrequested", ""⟩]
  premise := "`dev_D006`: 入力が補助文字（U+10000 以上）を含まない"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-106")
  rTasks := ["ABS-031", "ABS-034", "ABS-042", "ABS-043", "ABS-044", "ABS-045", "ABS-046"]
  impact := some (.abort, "入力検証の合否が変わり、会員登録・会員情報変更・レポート要求の成否が変わる")
  backlog := ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- [Source] は相関検証を適用しない（原典の不具合）。[Spec] は相関検証を適用し、さらに搭乗者リストの要素数を 1〜6 に制限する（[input-validation.md](input-validation.md#予約入力b2)） -/
@[gap_entry]
def D007 : Gap where
  id := "D-007"
  kind := .pre
  sites := [⟨"REST 予約 API", "docs/spec/http-contract.md#post-apiv1ticket", ""⟩]
  premise := "`dev_D007`: 入力が相関検証を満たし、搭乗者が 1〜6 名"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-107")
  rTasks := ["ABS-031"]
  impact := some (.abort, "[Source] は [Spec] が拒む予約を登録する")
  backlog := ["a89ec8f0-4d15-46a6-86fa-a640e4df0b44"]

/-- [Source] の表示名「登場クラスコード」は誤記。[Spec] は「搭乗クラスコード」 -/
@[gap_entry]
def D008 : Gap where
  id := "D-008"
  kind := .observational
  sites := [⟨"表示名", "docs/spec/errors-and-messages.md#項目の表示名", ""⟩]
  premise := "`obs_D008`: エラーメッセージの表示名の対応で、[Source] の「登場クラスコード」を [Spec] の「搭乗クラスコード」に対応させる"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-108")
  rTasks := ["ABS-031", "ABS-045", "ABS-046"]
  backlog := ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- [Source] のシーケンスは最大値の後に 1 へ循環し、使用済みの値を返しうる。[Spec] は常に未使用の値を返す -/
@[gap_entry]
def D009 : Gap where
  id := "D-009"
  kind := .preConcreteState
  sites := [⟨"採番", "docs/spec/ports.md#idgenerator", ""⟩]
  premise := "`dev_D009`: [Source] の各シーケンスが最大値に達していない"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-109")
  rTasks := ["ABS-021", "ABS-031", "ABS-041", "ABS-042", "ABS-045"]
  impact := some (.abort, "使用済みの番号による挿入の失敗、または既存の行との衝突")
  backlog := ["aedfeffc-3e82-46b1-b497-3d8b7808d068"]

/-- 登録・更新の件数 ≠ 1 で `System("e.ar.a0.L9002")` になる -/
@[gap_entry]
def D010 : Gap where
  id := "D-010"
  kind := .outsidePre
  sites := [⟨"更新件数", "docs/spec/reservation.md#予約確定reserve", ""⟩, ⟨"ログイン", "docs/spec/authentication.md#ログインlogin", ""⟩, ⟨"会員登録", "docs/spec/member.md", ""⟩]
  premise := "`J` と INV（キーが存在する）。到達しないことは ABS-022 で示す"
  evidence := .excludedBy []
  backlog := ["aedfeffc-3e82-46b1-b497-3d8b7808d068", "44f89eb1-e59a-4573-8129-7b0c1d4699bb", "4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- [Source] はドメイン部を `IDN.toASCII` で変換し、失敗すれば不合格とし、変換後の長さで 255 を判定する。[Spec] は変換しない（[ADR ac33](../decision/ac33-email-validation-rule.md)） -/
@[gap_entry]
def D011 : Gap where
  id := "D-011"
  kind := .pre
  sites := [⟨"Email", "docs/spec/input-validation.md#email", ""⟩]
  premise := "`dev_D011`: ドメイン部が ASCII だけからなる"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-111")
  rTasks := ["ABS-031", "ABS-034", "ABS-042", "ABS-045", "ABS-046"]
  impact := some (.abort, "入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる")
  backlog := ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- [Source] の小児分の途中計算 `j32mul(b, childFareRate − r)` は、`b × (childFareRate − r) > 2,147,483,647` のとき int32 で折り返す（値域の上限 `b = 100,000,000` では最大 約 1e10）。[Spec] は任意精度 -/
@[gap_entry]
def D012 : Gap where
  id := "D-012"
  kind := .pre
  sites := [⟨"合計金額", "docs/spec/fare-calculation.md#合計金額", ""⟩]
  premise := "`dev_D012`（`Abstraction.Fare`。抽象側の入力の述語）: 各フライトで、基本運賃 `b`・割引率 `r` について `b × (childFareRate − r) ≤ 2,147,483,647`（小児がいなくても課す十分条件）"
  deviations := [``Abstraction.Fare.TotalAlpha.dev_D012]
  evidence := .refuted [``Abstraction.Fare.need_D012]
  rTasks := ["ABS-004", "ABS-031", "ABS-041", "ABS-045"]
  impact := some (.abort, "折り返した合計金額が保存される")
  backlog := ["bbcce088-c475-4378-9cc6-e3d821acc0f5"]

/-- D-013 の主張（形式化していない。証明も公理も持たない）: [Source] の会員情報変更は、現在パスワードの照合と更新を別のトランザクションで行うので、並行実行の下では、[Spec]（1 トランザクション）と観測が異なりうる。どのモデルも並行実行を表さないので、命題として書けない -/
@[gap "D-013"] opaque claim_D013 : Prop

/-- [Source] は、現在パスワードの照合と更新を別のトランザクションで行う。[Spec] は 1 トランザクションで行う（[ADR 578b](../decision/578b-member-update-in-single-transaction.md)）。違いが観測できるのは並行実行のときだけである。各モデルは各ユースケースを 1 つの原子的な操作として扱うので、[Source] の具体機械でも 1 つの操作として写す -/
@[gap_entry]
def D013 : Gap where
  id := "D-013"
  kind := .outOfModel
  sites := [⟨"会員情報変更", "docs/spec/member.md#会員情報変更update", ""⟩, ⟨"トランザクション", "docs/spec/ports.md#トランザクション", "（規範節）"⟩]
  premise := "— モデル外（並行実行はモデルに現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
  evidence := .unformalized ``claim_D013 ""

/-- [Source] は `today()` を呼ぶたびに現在日付を読む。そのため、日付をまたいで実行されたユースケースの中で今日が変わりうる。[Spec] はユースケースの初めに 1 回だけ読む -/
@[gap_entry]
def D014 : Gap where
  id := "D-014"
  kind := .preConcreteEnv
  sites := [⟨"Clock", "docs/spec/ports.md#clock", ""⟩]
  premise := "`dev_D014`: 1 つのユースケースの中で、[Source] の Clock の各呼び出しが同じ日付を返す"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-114")
  rTasks := ["ABS-031", "ABS-041", "ABS-044", "ABS-045"]
  impact := some (.abort, "日付をまたぐと、予約・レポートに記録される日付が変わりうる")
  backlog := ["aedfeffc-3e82-46b1-b497-3d8b7808d068"]

/-- MD-1〜MD-3 が破れると、後勝ちの上書きか、`null` による前提違反になる -/
@[gap_entry]
def D015 : Gap where
  id := "D-015"
  kind := .outsidePre
  sites := [⟨"マスタの不変条件", "docs/spec/master-data.md#不変条件spec", ""⟩]
  premise := "PRE MD-1〜MD-3"
  evidence := .excludedBy [``Spec.MasterData.MD1, ``Spec.MasterData.MD2, ``Spec.MasterData.MD3]
  backlog := ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227"]

/-- D-016 の主張（形式化していない。証明も公理も持たない）: [Source] のログインはセッション ID を変えないので、セッション固定化の攻撃に対して [Spec] と振る舞いが異なる。セッション ID はどのモデルにも現れないので、命題として書けない -/
@[gap "D-016"] opaque claim_D016 : Prop

/-- [Source] はログイン時にセッション ID を変えない（セッション固定化の対策が無い）。[Spec] は新しい ID に変える -/
@[gap_entry]
def D016 : Gap where
  id := "D-016"
  kind := .outOfModel
  sites := [⟨"セッション", "docs/spec/http-contract.md#セッション", "（規範節）"⟩]
  premise := "— モデル外（セッション ID は [Spec] の外の規範節で定め、どのモデルにも現れない。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
  evidence := .unformalized ``claim_D016 ""

/-- [Source] は `redirectTo` の絶対 URL（外部サイト）へもリダイレクトする。[Spec] はアプリ内のパスだけを受け付ける -/
@[gap_entry]
def D017 : Gap where
  id := "D-017"
  kind := .pre
  sites := [⟨"ログイン成功時の遷移先", "docs/spec/http-contract.md#認証と権限", ""⟩]
  premise := "`dev_D017`: `redirectTo` が無いか、`/` で始まり `//` で始まらない"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-117")
  rTasks := ["ABS-045"]
  impact := some (.outputOnly, "ログインの成否と状態更新は同じで、遷移先だけが異なる")
  backlog := ["a89ec8f0-4d15-46a6-86fa-a640e4df0b44"]

/-- [Source] は文字列の `Min`・`Max` を `BigDecimal` として判定する（`"1.5"`, `"+1"`, `"1e1"` も数になる）。`creditTerm` が 6 文字以上なら、DB の `VARCHAR(5)` 違反でシステムエラーになる（会員登録・会員情報変更）。[Spec] は十進整数だけを数とし、長さの上限を持たない -/
@[gap_entry]
def D018 : Gap where
  id := "D-018"
  kind := .pre
  sites := [⟨"Min/Max", "docs/spec/input-validation.md#文字クラス", ""⟩, ⟨"creditTerm", "docs/spec/domain-model.md#member", ""⟩]
  premise := "`dev_D018`: `creditMonth`・`creditYear` が `[0-9]+` で、`creditTerm` が 5 文字以下"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-118")
  rTasks := ["ABS-031", "ABS-034", "ABS-042", "ABS-045", "ABS-046"]
  impact := some (.abort, "入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる")
  backlog := ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- [Source] は曜日を要求のロケールで表示する（テンプレート `tmpl:` の書式処理）。[Spec] は常に日本語で表示する -/
@[gap_entry]
def D019 : Gap where
  id := "D-019"
  kind := .preConcreteInput
  sites := [⟨"支払期限の表示", "docs/spec/domain-model.md#書式", ""⟩]
  premise := "`dev_D019`: `Accept-Language` が日本語"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-119")
  rTasks := ["ABS-045"]
  impact := some (.outputOnly, "曜日の表示だけが異なる")
  backlog := ["a89ec8f0-4d15-46a6-86fa-a640e4df0b44"]

/-- `GET /ticket/reserve?form` で、便名・搭乗日・搭乗クラス・運賃種別の欠落や、マスタに無い値を渡すと、[Source] は `NullPointerException`・`Assert` で 500 を返す。[Spec] は `InvalidRequest` で 400 を返す（[Spec] が振る舞いを定める入力なので PRE の内） -/
@[gap_entry]
def D020 : Gap where
  id := "D-020"
  kind := .pre
  sites := [⟨"予約入力画面の表示", "docs/spec/http-contract.md#b2-予約", ""⟩]
  premise := "`dev_D020`: 選択フライトの全項目（便名・搭乗日・搭乗クラス・運賃種別）が与えられ、それぞれマスタで解決できる"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-120")
  rTasks := ["ABS-045"]
  impact := some (.outputOnly, "予約入力画面の表示（状態を変えない `GET`）の応答だけが異なる")
  backlog := ["a89ec8f0-4d15-46a6-86fa-a640e4df0b44"]

/-- [Source] は、符号付きの 5 桁以上の年（`+10000/01/01`）と 0 以下の年も受け付ける。[Spec] は 4 桁の年 1〜9999 だけを受け付ける -/
@[gap_entry]
def D021 : Gap where
  id := "D-021"
  kind := .pre
  sites := [⟨"日付の解析", "docs/spec/input-validation.md#日付の解析", ""⟩]
  premise := "`dev_D021`: 年が符号無しの 4 桁で 1 以上"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-121")
  rTasks := ["ABS-031", "ABS-045", "ABS-046"]
  impact := some (.abort, "入力検証の合否が変わり、会員登録・会員情報変更の成否が変わる")
  backlog := ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- [Source] の単項目の検証エラーは順序不定（Bean Validation の `HashSet`）。[Spec] は定順の列。[Source] のほうが非決定性が大きいので、エラーの列を多重集合として比べる成分を、名前付きで置く -/
@[gap_entry]
def D022 : Gap where
  id := "D-022"
  kind := .observational
  sites := [⟨"入力検証エラーの並び", "docs/spec/input-validation.md", ""⟩, ⟨"ADR e24e", "docs/decision/e24e-validation-error-ordering.md", ""⟩]
  premise := "`obs_D022`: 検証エラーの列を多重集合として対応させる"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-122")
  rTasks := ["ABS-031", "ABS-045", "ABS-046"]
  backlog := ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2"]

/-- D-023 の主張（形式化していない。証明も公理も持たない）: [Source] は JVM の既定のタイムゾーンで今日を決めるので、Asia/Tokyo 以外で実行すると [Spec] と今日が異なりうる。各モデルは今日を入力として受け取るので、命題として書けない -/
@[gap "D-023"] opaque claim_D023 : Prop

/-- [Spec] の本番の Clock は Asia/Tokyo で今日を決める。[Source] は JVM の既定のタイムゾーンで決める -/
@[gap_entry]
def D023 : Gap where
  id := "D-023"
  kind := .outOfModel
  sites := [⟨"Clock", "docs/spec/ports.md#clock", ""⟩, ⟨"ADR 9ee4", "docs/decision/9ee4-clock-timezone-and-fixture-base-date.md", ""⟩]
  premise := "— モデル外（各モデルは「今日」を入力として受け取る。オラクルは JST で実行する。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
  evidence := .unformalized ``claim_D023 ""

/-- D-024 の主張（形式化していない。証明も公理も持たない）: [Source] のセッションの Cookie は `HttpOnly` だけを持ち、[Spec] の配備環境で決める属性（`Secure`・`SameSite`）と異なりうる。Cookie の属性はどのモデルにも現れないので、命題として書けない -/
@[gap "D-024"] opaque claim_D024 : Prop

/-- [Spec] は `HttpOnly` を付け、`Secure`・`SameSite` は配備環境で決める。[Source] は `HttpOnly` だけを付ける -/
@[gap_entry]
def D024 : Gap where
  id := "D-024"
  kind := .outOfModel
  sites := [⟨"セッションの Cookie 属性", "docs/spec/http-contract.md#セッション", "（規範節）"⟩]
  premise := "— モデル外（[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
  evidence := .unformalized ``claim_D024 ""

/-- D-025 の主張（形式化していない。証明も公理も持たない）: [Source] は PostgreSQL の READ COMMITTED で動くので、並行実行の下では、状態変更が直列化可能でないことがある。どのモデルも操作を原子的に扱うので、命題として書けない -/
@[gap "D-025"] opaque claim_D025 : Prop

/-- [Spec] は状態変更の直列化可能性を要求する。[Source] は PostgreSQL の READ COMMITTED で動き、一般には直列化可能でない（会員情報変更の事例は D-013 としてモデルに写す） -/
@[gap_entry]
def D025 : Gap where
  id := "D-025"
  kind := .outOfModel
  sites := [⟨"トランザクション", "docs/spec/ports.md#トランザクション", "（規範節）"⟩, ⟨"ADR 97f9", "docs/decision/97f9-persistence-and-transaction-semantics.md", ""⟩]
  premise := "— モデル外（モデルでは操作は原子的である。[assurance.md](assurance.md#移植元ソース--sourcemodel)）"
  evidence := .unformalized ``claim_D025 ""

/-- [Source]（Jackson）は、JSON の文字列にある不対サロゲートのエスケープ（例 `"\ud800"`）を受け付け、不対サロゲートを含む文字列として処理する。[Spec] の文字列はスカラ値の列なので、その要求を `InvalidRequest` とする -/
@[gap_entry]
def D026 : Gap where
  id := "D-026"
  kind := .preConcreteInput
  sites := [⟨"REST API", "docs/spec/http-contract.md#rest-apiapiv1", ""⟩]
  premise := "`dev_D026`: 要求の JSON の文字列に、不対サロゲートのエスケープを含まない"
  evidence := .pending "Lean に述語がまだ無い。機能の `SourceModel` と R 課題が未着手" (some "ABS-126")
  rTasks := ["ABS-031", "ABS-045"]
  impact := some (.abort, "[Source] は [Spec] が拒む要求を処理し、状態を変えうる")
  backlog := ["a89ec8f0-4d15-46a6-86fa-a640e4df0b44"]

/-- [Source] は、DB のマスタと注入された設定を起動時に読み込み、問い合わせの引数（`LocalDate` など）を受ける。値が [Spec] の型で表せないとき、[Source] は例外で起動しないか（未知の搭乗クラス・運賃種別のコード）、そのまま読み込む（`BOARDING_CLASS_NAME` の `NULL`、負の値・値域を超える値、`HHmm` で表せない時刻 `2415`、範囲外の日付、`yyyy/MM/dd` でない生年月日の下限など）。[Spec] はそれらを入力に取らない。列の型は処理系の範囲（`Int4`・`PgDate`・`Varchar n`）で写すので、範囲の違いもこの差異の前提で扱う（[ADR c108](../decision/c108-master-data-source-model-and-spec-fixes.md)） -/
@[gap_entry]
def D027 : Gap where
  id := "D-027"
  kind := .preConcreteInput
  sites := [⟨"マスタ", "docs/spec/master-data.md", ""⟩, ⟨"設定", "docs/spec/configuration.md", ""⟩]
  premise := "`dev_D027`（`Abstraction.MasterData`）: 具体側の入力（DB のマスタの各行・設定・問い合わせの引数）が、[Spec] の型で表せる（`aiMQ` が定義される）。問い合わせの日付が [Spec] の暦日（1〜9999 年）を超える場合を含む（[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）。運賃計算では、`dev_D027BF`（基本運賃。DB のマスタ・設定・`calculateBasicFare` の引数。`aiBF` が定義される。`null` と負の値を含まない）・`dev_D027F`（運賃。`calculateFare` の引数が負でない）・`dev_D027TF`（合計金額。DB のマスタ・設定・選択フライト情報・搭乗者。`aiTF` が定義される）（[ADR e9bc](../decision/e9bc-fare-double-analysis.md)）"
  deviations := [``Abstraction.MasterData.Alpha.dev_D027, ``Abstraction.Fare.Alpha.dev_D027BF, ``Abstraction.Fare.Alpha.dev_D027F, ``Abstraction.Fare.TotalAlpha.dev_D027TF]
  evidence := .refuted [``Abstraction.MasterData.need_D027]
  rTasks := ["ABS-001", "ABS-002", "ABS-004", "ABS-026"]
  impact := some (.abort, "[Source] は起動しないか、[Spec] の型で表せないマスタ・設定で動き続ける")
  backlog := ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227", "bbcce088-c475-4378-9cc6-e3d821acc0f5"]

/-- D-028 の主張（形式化していない。証明も公理も持たない）: [Source] は、認証イベントが発行されない構成では、ログイン時に `loginDateTime`・`loginFlg` を更新しない可能性がある。認証のモデルがまだ無いので、命題として書けない -/
@[gap "D-028"] opaque claim_D028 : Prop

/-- [Source] で更新されない可能性がある（認証イベントが発行されない構成）。オラクルで確かめた結果に応じて、D-0NN（前提型または観測型）として登録するか、差異が無いことを本表から消す -/
@[gap_entry]
def D028 : Gap where
  id := "D-028"
  kind := .undetermined
  sites := [⟨"ログイン時の状態更新", "docs/spec/authentication.md#ログインlogin", "（`loginDateTime`・`loginFlg`）"⟩]
  evidence := .unformalized ``claim_D028 "[backlog 44f8](../backlog/44f8-authentication-usecases.md) の完了条件"
  backlog := ["44f89eb1-e59a-4573-8129-7b0c1d4699bb"]

/-- コードが区切り行と同じ `NOP` の空港があると、`LinkedHashMap` の同じキーへの `put` で、区切り行の表示がその空港の名前に置き換わり、空港の行は現れない -/
@[gap_entry]
def D029 : Gap where
  id := "D-029"
  kind := .outsidePre
  sites := [⟨"空港コードリスト", "docs/spec/master-data.md#空港コードリスト画面用", ""⟩]
  premise := "PRE（MD-8: 空港のコードは `NOP` でない。[ADR f353](../decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)）"
  evidence := .excludedBy [``Spec.MasterData.MD8]
  backlog := ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227"]

/-- マスタ・入力が値域の外のとき、int32 で折り返す -/
@[gap_entry]
def D030 : Gap where
  id := "D-030"
  kind := .outsidePre
  sites := [⟨"値域", "docs/spec/domain-model.md#値域", ""⟩]
  premise := "PRE（入力の値域・MD-8）"
  evidence := .excludedBy [``Spec.Model.Range.maxBasicFareWithCharge, ``Spec.Model.Range.maxMultiplicationRatio, ``Spec.Model.Range.maxDiscountRate]
  backlog := ["25f7ef96-f77d-4ed8-973d-8cecc2a0f227"]

end Abstraction.Gap
