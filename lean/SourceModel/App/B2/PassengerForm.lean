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
@[source "java:jp.co.ntt.atrs.app.b2.PassengerForm#getAge()@a104b8de82dcc9aa",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#getFamilyName()@42b1265bbc5dfce0",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#getGender()@40162857f388bc4a",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#getGivenName()@d2416f58f72730cb",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#getMembershipNumber()@b2f27b5067cb06d6",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#setAge(Integer)@0f30aa30583622a4",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#setFamilyName(String)@f5e85e96b8121f23",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#setGender(Gender)@4a852d53b0d2198a",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#setGivenName(String)@b701004f7a9287e1",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#setMembershipNumber(String)@6669caafcd097fd4",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm#toString()@b78e85e304022465",
  "java:jp.co.ntt.atrs.app.b2.PassengerForm.serialVersionUID@e62c9f0ec675d596"]
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
