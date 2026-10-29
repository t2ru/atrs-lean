---
type: Backlog Item
title: "認証（A1/A2）"
description: "ログインの事前検査・照合・状態更新、ログアウトを両モデルで実装する。"
tags: [backlog, spec, source-model, authentication]
id: "0009"
state: todo
depends_on: ["0008"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 認証（A1/A2）

## 目的

会員情報変更・レポートの前提となるセッションを定義する。

## 範囲

- `Spec.UseCase.Auth`, `SourceModel.UseCase.Auth`
- 事前検査の境界（会員番号の長さ 9/10/11、パスワードの長さ 7/8/20/21）のベクタ

## 対象外

- Spring Security の実装方式

## 完了条件

- [ ] [authentication.md](../spec/authentication.md) の全手順がベクタで確認できる

## 参照

- [authentication.md](../spec/authentication.md)
- [ADR 0015](../decision/0015-password-hashing-port.md)
