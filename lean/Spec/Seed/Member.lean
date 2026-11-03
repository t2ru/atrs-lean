import Spec.Model
import Spec.Port
import Trace

/-!
# Spec.Seed.Member

シードの会員（上流の `00230_insert_member.sql`）の [Spec] の値と、採番の初期値。
`tools/conformance/member_seed.py` が生成する。手で編集しない。
ログイン日時（`localtimestamp`）は投入日とみなす。
-/

namespace Spec.Seed.Member

open Spec.Model Spec.Prim

/-- シードの会員（7 名。シードの順）。 -/
@[source "seed:00230_insert_member.sql#MEMBER@0fa5d725ee1debb7", "seed:00230_insert_member.sql#MEMBER_LOGIN@d692d2c1627b0945"]
def members : List Member := [
  { membershipNumber := ⟨"0000000001"⟩, kanjiFamilyName := "電電", kanjiGivenName := "花子", kanaFamilyName := "デンデン", kanaGivenName := "ハナコ", birthday := Date.ymd! 1979 1 25, gender := .F, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "VIS" }, creditTerm := "01/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } },
  { membershipNumber := ⟨"0000000002"⟩, kanjiFamilyName := "電電", kanjiGivenName := "太郎", kanaFamilyName := "デンデン", kanaGivenName := "タロウ", birthday := Date.ymd! 1979 1 25, gender := .M, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "JCB" }, creditTerm := "02/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } },
  { membershipNumber := ⟨"0000000003"⟩, kanjiFamilyName := "電電", kanjiGivenName := "次郎", kanaFamilyName := "デンデン", kanaGivenName := "ジロウ", birthday := Date.ymd! 1979 1 25, gender := .M, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "MTR" }, creditTerm := "03/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } },
  { membershipNumber := ⟨"0000000004"⟩, kanjiFamilyName := "電電", kanjiGivenName := "三郎", kanaFamilyName := "デンデン", kanaGivenName := "サブロウ", birthday := Date.ymd! 1979 1 25, gender := .M, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "AMX" }, creditTerm := "04/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } },
  { membershipNumber := ⟨"0000000005"⟩, kanjiFamilyName := "電電", kanjiGivenName := "四郎", kanaFamilyName := "デンデン", kanaGivenName := "シロウ", birthday := Date.ymd! 1979 1 25, gender := .M, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "VIS" }, creditTerm := "05/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } },
  { membershipNumber := ⟨"0000000006"⟩, kanjiFamilyName := "電電", kanjiGivenName := "五郎", kanaFamilyName := "デンデン", kanaGivenName := "ゴロウ", birthday := Date.ymd! 1979 1 25, gender := .M, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "JCB" }, creditTerm := "06/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } },
  { membershipNumber := ⟨"0000000007"⟩, kanjiFamilyName := "電電", kanjiGivenName := "六郎", kanaFamilyName := "デンデン", kanaGivenName := "ロクロウ", birthday := Date.ymd! 1979 1 25, gender := .M, tel := "111-1111-1111", zipCode := "1111111", address := "東京都港区港南Ｘ－Ｘ－Ｘ", mail := "xxxxxx@ntt.co.jp", creditNo := "1111111111111111", creditTypeCd := { val := "MTR" }, creditTerm := "07/20", login := { password := ⟨"{pbkdf2}699f9ebb02750159265aa3a96f9f8dd1a04c05e9e3464da8b4563a6b516d5cd063cdfc0b593a3479bcabfa7d46a6b8dc"⟩, lastPassword := some ⟨"{pbkdf2}48eb31479082c5af0eff80b24429c909706c6226c15d179c6d5ae75b07153a3eb79929fd9db220dd018ef406e234d4e8"⟩, loginDateTime := some (Date.ymd! 2026 11 1), loginFlg := false } }
]

/-- 採番の初期値: 会員はシードが 7 回採番した次、ほかは 1。 -/
@[source "seed:00230_insert_member.sql#MEMBER@0fa5d725ee1debb7"]
def sequences : Spec.Port.Sequences := { member := 8 }

end Spec.Seed.Member
