---
type: Backlog Item
title: "会員（C1/C2）と入力検証"
description: "会員登録・変更と、全画面の入力検証（前処理・文字クラス・単項目・相関）を両モデルで実装する。"
tags: [backlog, spec, source-model, member, validation]
id: "4e0e3dd1-d282-46e2-aa98-719853bc9fd2"
state: todo
depends_on: ["591d9aa4-065b-4975-8146-86aae05b780a", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "f18c3c0f-4007-42c1-ba25-102fb385a16c", "aedfeffc-3e82-46b1-b497-3d8b7808d068", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 会員（C1/C2）と入力検証

## 目的

入力検証は全画面に共通であり、文字列長の差異（D-006）を含むため早めに確定させる。

## 範囲

- `Spec.Validation`, `SourceModel.Validation`
- `Spec.UseCase.Member`, `SourceModel.UseCase.Member`
- `Email` 判定規則の形式化（[input-validation.md](../spec/input-validation.md#email)、[ADR ac33](../decision/ac33-email-validation-rule.md)）
- エラーの並び（[Spec] は列、[Source] は多重集合。[ADR e24e](../decision/e24e-validation-error-ordering.md)）の形式化
- 会員情報変更を 1 トランザクションにする（[ADR 578b](../decision/578b-member-update-in-single-transaction.md)）
- R 課題: ABS-024（会員のリポジトリと PasswordHasher）、ABS-034（会員情報変更）、ABS-042（会員のユースケース）、ABS-046（入力検証とエラーメッセージ）
- W 課題: ABS-106（D-006）、ABS-108（D-008）、ABS-111（D-011）、ABS-118（D-018）、ABS-121（D-021）、ABS-122（D-022）
- SPEC 課題: 会員と入力検証の SPEC-001〜SPEC-004
- L 課題: ABS-030, ABS-032, ABS-033

## 対象外

- なし

## 完了条件

- [x] [input-validation.md](../spec/input-validation.md) の TODO(spec) を解消した（2026-10-29。ADR ac33・e24e）
- [ ] Email の境界値（ローカル部 64/65 文字、末尾のドット、`[IPv4]`、`[IPv6:…]`、引用符付きローカル部）のベクタが通る
- [ ] 文字クラス境界値のベクタが通る
- [ ] 範囲の R・W・L・SPEC 課題を証明し、TR-D が通る
- [ ] 会員と入力検証の `source-model/` ベクタが Java オラクル（HTTP レベルを含む）と一致する

## 参照

- [member.md](../spec/member.md)
- [input-validation.md](../spec/input-validation.md)
- [ADR 10a5](../decision/10a5-text-length-and-character-classes.md)
