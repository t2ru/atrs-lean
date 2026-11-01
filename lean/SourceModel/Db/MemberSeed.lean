import SourceModel.Db.Schema
import Trace

/-!
# SourceModel.Db.MemberSeed

シードの会員（上流の `00230_insert_member.sql`）の MEMBER・MEMBER_LOGIN の行と、`sq_member_1` の状態。
`tools/conformance/member_seed.py` が生成する。手で編集しない。
`LOGIN_DATE_TIME`（`localtimestamp`）は投入日の 0:00 とみなす。
-/

namespace SourceModel.Db.MemberSeed

open LangSemantics.Sql.Postgresql SourceModel.Db.Schema

/-- MEMBER（7 行）。 -/
@[source "seed:00230_insert_member.sql#MEMBER@0fa5d725ee1debb7"]
def memberRows : List MemberRow := [
  { customerNo := ⟨"0000000001", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"花子", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"ハナコ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"F", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"VIS", by decide⟩, creditTerm := ⟨"01/20", by decide⟩ },
  { customerNo := ⟨"0000000002", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"太郎", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"タロウ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"M", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"JCB", by decide⟩, creditTerm := ⟨"02/20", by decide⟩ },
  { customerNo := ⟨"0000000003", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"次郎", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"ジロウ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"M", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"MTR", by decide⟩, creditTerm := ⟨"03/20", by decide⟩ },
  { customerNo := ⟨"0000000004", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"三郎", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"サブロウ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"M", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"AMX", by decide⟩, creditTerm := ⟨"04/20", by decide⟩ },
  { customerNo := ⟨"0000000005", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"四郎", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"シロウ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"M", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"VIS", by decide⟩, creditTerm := ⟨"05/20", by decide⟩ },
  { customerNo := ⟨"0000000006", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"五郎", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"ゴロウ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"M", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"JCB", by decide⟩, creditTerm := ⟨"06/20", by decide⟩ },
  { customerNo := ⟨"0000000007", by decide⟩, kanjiFamilyName := ⟨"電電", by decide⟩, kanjiGivenName := ⟨"六郎", by decide⟩, kanaFamilyName := ⟨"デンデン", by decide⟩, kanaGivenName := ⟨"ロクロウ", by decide⟩, birthday := ⟨3311, by decide⟩, gender := ⟨"M", by decide⟩, tel := ⟨"111-1111-1111", by decide⟩, zipCode := ⟨"1111111", by decide⟩, address := ⟨"東京都港区港南Ｘ－Ｘ－Ｘ", by decide⟩, mail := ⟨"xxxxxx@ntt.co.jp", by decide⟩, creditNo := ⟨"1111111111111111", by decide⟩, creditTypeCd := ⟨"MTR", by decide⟩, creditTerm := ⟨"07/20", by decide⟩ }
]

/-- MEMBER_LOGIN（7 行）。 -/
@[source "seed:00230_insert_member.sql#MEMBER_LOGIN@d692d2c1627b0945"]
def memberLoginRows : List MemberLoginRow := [
  { customerNo := ⟨"0000000001", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false },
  { customerNo := ⟨"0000000002", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false },
  { customerNo := ⟨"0000000003", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false },
  { customerNo := ⟨"0000000004", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false },
  { customerNo := ⟨"0000000005", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false },
  { customerNo := ⟨"0000000006", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false },
  { customerNo := ⟨"0000000007", by decide⟩, password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc", by decide⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8", by decide⟩, loginDateTime := some ⟨1793491200000000, by decide⟩, loginFlg := false }
]

/-- `sq_member_1` の状態（シードが 7 回 `nextval` を呼んだ後）。 -/
@[source "seed:00230_insert_member.sql#MEMBER@0fa5d725ee1debb7"]
def sqMember : LangSemantics.Sql.Sequence.SequenceState := some 7

end SourceModel.Db.MemberSeed
