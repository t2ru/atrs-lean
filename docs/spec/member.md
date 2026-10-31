---
type: Specification
title: "会員（C0/C1/C2）"
description: "会員登録・会員情報変更・現在パスワード照合・入力値と会員エンティティの相互変換。"
tags: [spec, member, c0, c1, c2]
status: draft
spec_role: draft
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 会員（C0/C1/C2）

> **区分: 形式化前の草案（draft）。** Lean `Spec` に形式化した時点で、定義を Lean へのリンクと非規範の要約に置き換える（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。

入力検証は [input-validation.md](input-validation.md#会員入力c1c2)、画面遷移は [http-contract.md](http-contract.md#c1-会員登録) を参照。

## 入力から会員への変換（toMember）

**[Spec=Source]** 会員入力 `MemberInput`（登録・変更で共通の項目）から `Member` を作る。

| Member | 値 |
| --- | --- |
| `kanjiFamilyName` ほか氏名 4 項目 | 入力値 |
| `birthday` | `dateOfBirth` |
| `gender`, `address`, `mail`, `creditNo`, `creditTypeCd` | 入力値 |
| `tel` | `tel1 ++ "-" ++ tel2 ++ "-" ++ tel3` |
| `zipCode` | `zipCode1 ++ zipCode2`（7 文字、ハイフン無し） |
| `creditTerm` | `creditMonth ++ "/" ++ creditYear`（例 `"01/25"`） |
| `login.password`（生パスワード） | `password`（変更時は空でありうる） |

`membershipNumber` は入力から設定しない（登録時は採番、変更時はログイン中の会員番号）。`reEnterMail`・`reEnterPassword`・`currentPassword` は変換に使わない。

出典: atrs-web/.../app/c0/MemberHelper.java `toMember`, C0Mapper.java

## 会員から変更画面入力への変換（toMemberUpdateInput）

**[Spec=Source]**

- 氏名・性別・住所・メール・カード番号・カード種別はそのまま。`dateOfBirth ← birthday`。
- `tel` を `-` で分割し、ちょうど 3 要素なら `tel1, tel2, tel3`。それ以外は未設定。
- `zipCode` の長さが 7 以上なら `zipCode1 = zipCode[0..3]`, `zipCode2 = zipCode[3..7]`。それ以外は未設定。
- `creditTerm` を `/` で分割し、ちょうど 2 要素なら `creditMonth, creditYear`。それ以外は未設定。
- `reEnterMail`・各パスワード欄は **空** とする（利用者が再入力する）。

出典: atrs-web/.../app/c0/MemberHelper.java `toMemberUpdateForm`

## 会員登録（register）

### シグネチャ

`register(input: MemberRegisterInput; ports) : Except AtrsError MembershipNumber`

### 定義

1 つのトランザクションとして実行する。

1. `m = toMember(input)`。
2. `h = PasswordHasher.hash(input.password)`。
3. `m.login = { password = h, lastPassword = h, loginDateTime = 無し, loginFlg = false }`。
4. `m.membershipNumber = IdGenerator.nextMembershipNumber()`。
5. 会員とログイン情報を登録する。
6. `m.membershipNumber` を返す（完了画面に表示する）。

[Source] の追加の振る舞い: 登録件数が 1 でなければ `System("e.ar.a0.L9002")`。リポジトリの契約（[Spec] の前提）の下では到達しないため、差異ではない（[abstraction.md](abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない) の D-010、補題 ABS-022）。

出典: atrs-domain/.../service/c1/MemberRegisterServiceImpl.java `register`

## 現在パスワードの照合（checkMemberPassword）

**[Spec=Source]** `checkMemberPassword(currentPassword, membershipNumber)`:

- `currentPassword` が空なら何もしない。
- そうでなければ、会員の現在のパスワードハッシュ `h` について `PasswordHasher.matches(currentPassword, h)` が偽なら `Business("e.ar.c2.2001")`。

[Source]: 会員が存在しない場合は `NullPointerException`（前提違反）。ログイン中の会員番号で呼ぶため通常は到達しない。

出典: atrs-domain/.../service/c2/MemberUpdateServiceImpl.java `checkMemberPassword`

## 会員情報変更（update）

### シグネチャ

`update(input: MemberUpdateInput, membershipNumber; ports) : Except AtrsError Unit`

### 定義

**[Spec]**（[ADR 578b](../decision/578b-member-update-in-single-transaction.md)）

1. 1 つのトランザクションとして:
   1. `checkMemberPassword(input.currentPassword, membershipNumber)`。失敗したら何も更新せずに終える。
   2. `m = toMember(input)`、`m.membershipNumber = membershipNumber`。
   3. 会員の基本情報（氏名・生年月日・性別・電話・郵便番号・住所・メール・カード情報）を更新する。
   4. `input.password` が空でなければ、`lastPassword := password（更新前のハッシュ）`, `password := PasswordHasher.hash(input.password)` に更新する。
2. ログイン中のセッションが保持する会員情報を、更新後の会員情報で置き換える（[authentication.md](authentication.md#セッション)）。
3. 成功メッセージ `i.ar.c2.2001` を表示する。

**[Source]** 手順 1.1（照合）と 1.2〜1.4（更新）は別のトランザクションである。照合の後・更新の前に他のセッションが同じ会員のパスワードを変えても、更新は通る（モデル外の既知差異 [D-013](abstraction.md#既知差異)。並行実行でだけ観測できる）。

出典: atrs-web/.../app/c2/MemberUpdateController.java `update`, atrs-domain/.../service/c2/MemberUpdateServiceImpl.java `updateMember`, MemberRepository.xml `updateMemberLogin`

## 会員の存在確認

**[Spec=Source]** `isMember(membershipNumber) = 会員が存在する`。予約入力画面の会員番号欄の即時確認（REST）に使う。

出典: atrs-domain/.../service/a0/MembershipSharedServiceImpl.java `isMember`
