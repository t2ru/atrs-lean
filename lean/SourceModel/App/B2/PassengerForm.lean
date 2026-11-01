import Trace
import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.App.B2.PassengerForm

原典の `jp.co.ntt.atrs.app.b2.PassengerForm`（`atrs-web/src/main/java/jp/co/ntt/atrs/app/b2/PassengerForm.java`）の写し。
入力の前処理（`StringTrimmerEditor`）と単項目検証の後の値を持つ（検証は backlog 4e0e）。
-/

namespace SourceModel.App.B2
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int LangSemantics.Java.Spring

/-- `PassengerForm`（搭乗者情報フォーム）。 -/
structure PassengerForm where
  familyName : JRef String := none
  givenName : JRef String := none
  age : JRef J32 := none
  gender : JRef Spec.Model.Gender := none
  membershipNumber : JRef String := none
  deriving DecidableEq, Repr

namespace PassengerForm

/-- `isEmpty()`: 姓・名・会員番号がいずれも空白のみか `null` で、年齢と性別が `null`。 -/
@[source "java:jp.co.ntt.atrs.app.b2.PassengerForm#isEmpty()@4c989a582a1c8d97",
  "dep:org.springframework:spring-core#StringUtils@spring-core-7.0.3"]
def isEmpty (p : PassengerForm) : Bool :=
  !StringUtils.hasText p.familyName && !StringUtils.hasText p.givenName && p.age.isNone && p.gender.isNone &&
    !StringUtils.hasText p.membershipNumber

end PassengerForm

end SourceModel.App.B2
