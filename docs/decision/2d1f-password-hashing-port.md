---
type: Architecture Decision Record
title: "パスワードのハッシュ化と照合を PasswordHasher ポートに抽象化する"
description: "ドメインはハッシュ文字列を不透明値として扱い、{pbkdf2}/{bcrypt} 形式との互換はアダプタの責務とする。"
tags: [adr, security, ports]
id: "2d1fa701-c1a5-43c4-982e-4ff80a79a603"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# パスワードのハッシュ化と照合を PasswordHasher ポートに抽象化する

## Context and Problem Statement

原典は Spring Security の `DelegatingPasswordEncoder` を使い、既定は `{pbkdf2}`（`Pbkdf2PasswordEncoder.defaultsForSpringSecurity_v5_8()`）、`{bcrypt}` も照合できる。
シードデータの会員はパスワード `aaaaa11111` の `{pbkdf2}…` ハッシュを持つ。
ハッシュは塩（ランダム）を含むため、生成結果は非決定的である。ドメインロジックとハッシュアルゴリズムをどう切り分けるかを決める。

## Decision Drivers

* ドメイン仕様と証明を非決定性から切り離すこと
* 原典の DB（シードのハッシュ）と互換にする選択肢を残すこと
* 暗号実装を仕様の対象にしないこと（[ADR 84bf](84bf-porting-scope.md)）

## Considered Options

* `PasswordHasher` ポート（`hash`, `matches`）として抽象化
* PBKDF2 のパラメータまで仕様化する
* 平文で保存する簡易モデル

## Decision Outcome

Chosen option: "`PasswordHasher` ポートとして抽象化", because ドメインに必要なのは「ハッシュ化して保存する」「照合する」の 2 操作だけであり、アルゴリズムはアダプタで差し替えられるため。

* `hash(raw) : PasswordHash`（非決定的でよい）、`matches(raw, hash) : Bool`。
* 契約: `matches(raw, hash(raw)) = true`。`raw ≠ raw'` のとき `matches(raw', hash(raw))` は高確率で `false`（参照実装では常に `false`）。
* ドメインは `PasswordHash` を不透明な文字列として扱い、比較・分解しない。
* 参照（インメモリ）アダプタはテスト用の決定的な可逆でない写像（例: `"{test}" ++ raw`）を使ってよい。本番相当の互換アダプタは `{pbkdf2}` 形式（Spring Security 5.8 既定パラメータ）を実装する。互換アダプタの詳細は [backlog 4b0e](../backlog/4b0e-in-memory-adapters-and-seed-data.md) で扱う。
* ログインの事前検査（会員番号 10 文字、パスワード 8〜20 文字）は業務規則として [spec/authentication.md](../../lean/Spec/Authentication.lean) に定義する。

### Consequences

* Good, because ドメインの仕様・テストベクタが決定的になる
* Good, because 移植先言語の暗号ライブラリを自由に選べる
* Bad, because 原典 DB との互換は別途アダプタで保証する必要がある

### Confirmation

* `Spec` / `TargetModel` の業務ロジックがハッシュ文字列の中身に依存しないことをレビューで確認する。

## Pros and Cons of the Options

### ポート化

* Good, because 決定的・差し替え可能
* Bad, because 互換性はアダプタ任せ

### PBKDF2 まで仕様化

* Good, because 原典 DB と完全互換
* Bad, because 暗号の実装・検証が仕様の範囲に入る

### 平文保存

* Good, because 単純
* Bad, because 安全でなく、原典の意図に反する

## More Information

* [spec/ports.md](../../lean/Spec/Port.lean), [spec/authentication.md](../../lean/Spec/Authentication.lean)
