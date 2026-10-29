---
type: Guideline
title: "バージョン管理規約"
description: "一通りの作業が終わったら git commit する。push はしない。コミットの単位とメッセージの規則。"
tags: [rules, git]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# バージョン管理規約

## 原則

- **一通りの作業が終わったら `git commit` する。** コミットは可逆な操作なので、確認を待たずに行ってよい（人間・AI エージェントとも）。
- **`git push` はしない。** リモートへの公開はプロジェクトオーナーが行う。
- 履歴を書き換える操作（`git commit --amend` で既存コミットを変える、`rebase`、`reset --hard`、`push --force`）は、オーナーの指示がある場合に限る。

## 「一通りの作業」とは

次のいずれかが完了した時点でコミットする。

- 依頼された作業の 1 つ（例: ADR の追加、規約の改訂、backlog 項目 1 件の完了）
- backlog 項目の完了条件を満たしたとき（[backlog.md](backlog.md#完了の定義definition-of-done)）

作業の途中（検査が通っていない状態）ではコミットしない。

## コミット前の確認

- `docs/` を変更した場合: frontmatter・[docs/index.md](../index.md)・[docs/log.md](../log.md) を更新し、OKF とリンクの検査（[backlog 0017](../backlog/0017-okf-bundle-lint.md)）を通す。
- Lean を変更した場合: `lake build`, `lake test`。
- Rust を変更した場合: Verus の検証、`cargo kani`、`cargo test`（[rust.md](rust.md#品質)）。
- 機密情報（鍵・パスワード・個人情報）を含めない。

## メッセージ

- 1 行目は変更内容の要約（日本語可、50 文字程度まで）。
- 本文に、関係する ADR・backlog の番号と、未完了の事項を書く。
- AI エージェントがコミットする場合は、その環境が求める帰属表示（`Co-Authored-By:` 行など）を末尾に付ける。
