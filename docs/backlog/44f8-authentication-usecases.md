---
type: Backlog Item
title: "認証（A1/A2）"
description: "ログインの事前検査・照合・状態更新、ログアウトを両モデルで実装する。"
tags: [backlog, spec, source-model, authentication]
id: "44f89eb1-e59a-4573-8129-7b0c1d4699bb"
state: todo
depends_on: ["4e0e3dd1-d282-46e2-aa98-719853bc9fd2", "f18c3c0f-4007-42c1-ba25-102fb385a16c", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T19:00:00+09:00
---

# 認証（A1/A2）

## 目的

会員情報変更・レポートの前提となるセッションを定義する。

## 範囲

- `Spec.UseCase.Auth`, `SourceModel.UseCase.Auth`
- 事前検査の境界（会員番号の長さ 9/10/11、パスワードの長さ 7/8/20/21）のベクタ
- R 課題 ABS-043（認証のユースケース）。D-006 の W 課題 ABS-106 は [backlog 4e0e](4e0e-member-usecases-and-input-validation.md) で示す
- ログイン時の状態更新の既知差異 D-028（観測型。[backlog f18c](f18c-java-oracle-harness.md) の Java の原典実行で確かめた。[abstraction.md](../spec/abstraction.md#既知差異)）の成分 `obs_D028` と W 課題 ABS-128

## 対象外

- Spring Security の実装方式

## 完了条件

- [ ] [`Spec.Auth`](../../lean/Spec/Auth.lean) の全手順がベクタで確認できる
- [ ] ABS-043 と、認証の SPEC-001〜SPEC-004 を証明した
- [ ] 認証の `source-model/` ベクタが Java の原典実行と一致する
- [ ] ログイン時の状態更新の差異 D-028（画面ログインで更新しない・REST の Basic 認証で更新する）の成分 `obs_D028` を R 課題 ABS-043 に置き、W 課題 ABS-128 を証明した

## 参照

- [`Spec.Auth`](../../lean/Spec/Auth.lean)
- [ADR 2d1f](../decision/2d1f-password-hashing-port.md)
