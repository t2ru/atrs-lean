import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.MyBatis
import SourceModel.Db.Schema
import SourceModel.Db.Tx
import SourceModel.Domain.Model.CreditType
import SourceModel.Domain.Model.Gender
import SourceModel.Domain.Model.Member
import SourceModel.Domain.Model.MemberLogin
import Spec.Model

/-!
# SourceModel.Domain.Repository.Member.MemberRepository

原典の `jp.co.ntt.atrs.domain.repository.member.MemberRepository`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/repository/member/MemberRepository.java`・`atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/member/MemberRepository.xml`）の写し。

予約の会員照合が使う `findOne` だけを写す（backlog aedf）。ほかの文は会員の backlog（4e0e・44f8）で足す。
CREDIT_TYPE はマスタの表（不変の入力 `MasterDb`）なので、引数で受ける。
-/

namespace SourceModel.Domain.Repository.Member
open LangSemantics.Sql.Core LangSemantics.Sql.Query LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int
open SourceModel.Domain.Model SourceModel.Db.MyBatis

namespace MemberRepository

/-- `member-map`（`creditType-map`・`memberLogin-map` を含む）が読む列。 -/
structure MemberResult where
  member : MemberRow
  login : MemberLoginRow
  creditType : CreditTypeRow
  deriving DecidableEq, Repr

/-- `SELECT m.customer_no, …, c_t.credit_firm FROM member m, member_login m_l, credit_type c_t
WHERE m.customer_no = #{membershipNumber} AND m.customer_no = m_l.customer_no AND m.credit_type_cd = c_t.credit_type_cd` -/
@[source "sql:jp.co.ntt.atrs.domain.repository.member.MemberRepository#findOne@0d19f186b308dbfd"]
def findOneRows (mdb : MasterDb) (fd : FlightDb) (membershipNumber : SqlValue) : Bag MemberResult :=
  Bag.project (fun ((m, l), c) => ⟨m, l, c⟩)
    (Bag.select (fun ((m, l), c) =>
        ((SqlValue.eq collationC m.customerNo.toSql membershipNumber).and (eqText m.customerNo l.customerNo)).and
          (eqText m.creditTypeCd c.creditTypeCd))
      (Bag.cross (Bag.cross fd.member fd.memberLogin) mdb.creditType))

/-- `TIMESTAMP` を `LocalDate` に（JDBC の `getObject(…, LocalDate.class)`。日付の部分）。 -/
@[source "dep:org.postgresql:postgresql#TimestampUtils.toLocalDateTime@postgresql-42.7.9"]
def localDateOfTimestamp (t : PgTimestamp) : JLocalDate := JLocalDate.ofEpochDay (t.val / 86400000000)

/-- `member-map`（1 行分）。 -/
def memberMap (r : MemberResult) : JResult Member := do
  let g ← Gender.valueOf r.member.gender.val
  return { membershipNumber := str r.member.customerNo, kanjiFamilyName := str r.member.kanjiFamilyName,
           kanjiGivenName := str r.member.kanjiGivenName, kanaFamilyName := str r.member.kanaFamilyName,
           kanaGivenName := str r.member.kanaGivenName, birthday := date r.member.birthday, gender := some g,
           tel := str r.member.tel, zipCode := str r.member.zipCode, address := str r.member.address,
           mail := str r.member.mail, creditNo := str r.member.creditNo, creditTerm := str r.member.creditTerm,
           creditType := some { creditTypeCd := str r.creditType.creditTypeCd, creditFirm := str r.creditType.creditFirm },
           memberLogin := some { password := str r.login.password, lastPassword := r.login.lastPassword.map (·.val),
                                 loginDateTime := r.login.loginDateTime.map localDateOfTimestamp,
                                 loginFlg := some r.login.loginFlg } }

/-- `Member findOne(String membershipNumber)`。`selectOne` なので、0 行なら `null`（主キーの条件なので 2 行以上にはならない）。 -/
@[source "java:jp.co.ntt.atrs.domain.repository.member.MemberRepository#findOne(String)@451a02e1a5c2ef0a"]
def findOne (mdb : MasterDb) (membershipNumber : JRef String) : SourceModel.Db.Tx.DbM (JRef Member) := do
  let p : SqlValue := match membershipNumber with | some s => .text s | none => .null
  match ← SourceModel.Db.Tx.query fun fd => .ok (findOneRows mdb fd p) with
  | [] => pure none
  | r :: _ => some <$> SourceModel.Db.Tx.lift (memberMap r)

end MemberRepository

end SourceModel.Domain.Repository.Member
