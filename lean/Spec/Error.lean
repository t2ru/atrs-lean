import Trace

/-!
# Spec.Error

エラーの分類 `AtrsError`（`docs/spec/errors-and-messages.md#分類atrserror`、ADR a4fa）。
空席照会・予約が使う `Business`・`NotFound`・`InvalidRequest`・`System`・`Conflict` を置く。`Validation` は、
それを使う機能の backlog（4e0e）で足す。`PreconditionViolation` は [Source] だけの分類なので置かない。
-/

namespace Spec.Error

/-- 業務規則違反の事由（`docs/spec/errors-and-messages.md`）。メッセージのコード `code` と引数 `args` は事由で決まり、
引数の数は構築子の欄で決まる（不正な状態を表現できない型。ADR 6d36）。 -/
@[spec_doc "docs/spec/errors-and-messages.md#分類atrserror"]
inductive BusinessError where
  /-- `e.ar.b1.2001`: 搭乗日が照会可能期間の外 -/
  | outOfSearchPeriod
  /-- `e.ar.b1.2002`: 区間が無い -/
  | routeNotFound
  /-- `e.ar.b2.2001`: 往路の到着から復路の出発までの間隔が短い -/
  | intervalTooShort
  /-- `e.ar.b2.2002`: 代表者の会員番号の会員が無い -/
  | repMemberNotFound
  /-- `e.ar.b2.2003`: 代表者が会員と一致しない -/
  | repMemberMismatch
  /-- `e.ar.b2.2004`: 代表者が最小年齢より若い（引数: 最小年齢） -/
  | repTooYoung (minAge : String)
  /-- `e.ar.b2.2005`: 搭乗者の会員番号の会員が無い（引数: 搭乗者の位置） -/
  | passengerMemberNotFound (pos : String)
  /-- `e.ar.b2.2006`: 搭乗者が会員と一致しない（引数: 搭乗者の位置） -/
  | passengerMemberMismatch (pos : String)
  /-- `e.ar.b2.2007`: レディース割の運賃種別に男性の搭乗者がいる -/
  | ladiesOnly
  /-- `e.ar.b2.2008`: 運賃種別が予約可能期間の外 -/
  | fareTypeUnavailable
  /-- `e.ar.b2.2009`: 空席が足りない -/
  | noVacancy
  /-- `e.ar.b2.2010`: 搭乗者が運賃種別の最少人数に足りない（引数: 運賃種別名、最少人数） -/
  | tooFewPassengers (fareTypeName minNum : String)
  deriving DecidableEq, Repr

namespace BusinessError

/-- メッセージのコード。 -/
def code : BusinessError → String
  | .outOfSearchPeriod => "e.ar.b1.2001"
  | .routeNotFound => "e.ar.b1.2002"
  | .intervalTooShort => "e.ar.b2.2001"
  | .repMemberNotFound => "e.ar.b2.2002"
  | .repMemberMismatch => "e.ar.b2.2003"
  | .repTooYoung _ => "e.ar.b2.2004"
  | .passengerMemberNotFound _ => "e.ar.b2.2005"
  | .passengerMemberMismatch _ => "e.ar.b2.2006"
  | .ladiesOnly => "e.ar.b2.2007"
  | .fareTypeUnavailable => "e.ar.b2.2008"
  | .noVacancy => "e.ar.b2.2009"
  | .tooFewPassengers .. => "e.ar.b2.2010"

/-- メッセージの引数。 -/
def args : BusinessError → List String
  | .repTooYoung a | .passengerMemberNotFound a | .passengerMemberMismatch a => [a]
  | .tooFewPassengers a b => [a, b]
  | _ => []

/-- コードと引数から事由を読む（知らないコード・引数の数の違うものは無し）。 -/
def ofCode? : String → List String → Option BusinessError
  | "e.ar.b1.2001", [] => some .outOfSearchPeriod
  | "e.ar.b1.2002", [] => some .routeNotFound
  | "e.ar.b2.2001", [] => some .intervalTooShort
  | "e.ar.b2.2002", [] => some .repMemberNotFound
  | "e.ar.b2.2003", [] => some .repMemberMismatch
  | "e.ar.b2.2004", [a] => some (.repTooYoung a)
  | "e.ar.b2.2005", [a] => some (.passengerMemberNotFound a)
  | "e.ar.b2.2006", [a] => some (.passengerMemberMismatch a)
  | "e.ar.b2.2007", [] => some .ladiesOnly
  | "e.ar.b2.2008", [] => some .fareTypeUnavailable
  | "e.ar.b2.2009", [] => some .noVacancy
  | "e.ar.b2.2010", [a, b] => some (.tooFewPassengers a b)
  | _, _ => none

theorem ofCode?_code_args (e : BusinessError) : ofCode? e.code e.args = some e := by
  cases e <;> rfl

theorem code_args_of_ofCode? {c : String} {a : List String} {e : BusinessError} (h : ofCode? c a = some e) :
    e.code = c ∧ e.args = a := by
  unfold ofCode? at h
  split at h <;> (try cases h) <;> exact ⟨rfl, rfl⟩

end BusinessError

/-- 照会結果 0 件の事由。 -/
@[spec_doc "docs/spec/errors-and-messages.md#分類atrserror"]
inductive NotFoundError where
  /-- `e.ar.b1.2003`: 照会の条件に合うフライトが無い -/
  | noFlight
  deriving DecidableEq, Repr

/-- メッセージのコード。 -/
def NotFoundError.code : NotFoundError → String
  | .noFlight => "e.ar.b1.2003"

/-- コードから事由を読む（知らないコードは無し）。 -/
def NotFoundError.ofCode? : String → Option NotFoundError
  | "e.ar.b1.2003" => some .noFlight
  | _ => none

theorem NotFoundError.code_of_ofCode? {c : String} {e : NotFoundError} (h : NotFoundError.ofCode? c = some e) :
    e.code = c := by
  unfold NotFoundError.ofCode? at h
  split at h <;> (try cases h) <;> rfl

/-- 整合性違反・I/O 失敗の事由。いまは I/O 失敗だけを持つ（N-002）。 -/
@[spec_doc "docs/spec/errors-and-messages.md#分類atrserror"]
inductive SystemError where
  /-- `e.ar.fw.9999`: ポートの I/O の失敗（N-002） -/
  | ioFailure
  deriving DecidableEq, Repr

/-- メッセージのコード。 -/
def SystemError.code : SystemError → String
  | .ioFailure => "e.ar.fw.9999"

/-- エラーの分類。 -/
@[spec_doc "docs/spec/errors-and-messages.md#分類atrserror"]
inductive AtrsError where
  /-- 業務規則違反 -/
  | business (e : BusinessError)
  /-- 照会結果 0 件 -/
  | notFound (e : NotFoundError)
  /-- 改竄検知（`detail` はログ用の詳細。変えうる部分は N-004） -/
  | invalidRequest (detail : String)
  /-- 整合性違反・I/O 失敗 -/
  | system (e : SystemError)
  /-- 排他制御の失敗（`reason` はログ用。N-001） -/
  | conflict (reason : String)
  deriving DecidableEq, Repr

end Spec.Error
