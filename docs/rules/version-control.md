---
type: Guideline
title: "バージョン管理規約"
description: "一通りの作業が終わったら git commit する。push は自分で作ったブランチに限り、PR を作成してよい。PR は draft で作り、人間のレビューを求める段で ready にする。コミットの単位とメッセージの規則。"
tags: [rules, git]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:30:00+09:00
---

# バージョン管理規約

## 原則

- **一通りの作業が終わったら `git commit` する。** コミットは可逆な操作なので、確認を待たずに行ってよい（人間・AI エージェントとも）。
- **`git push` は、自分で作ったブランチに限って行ってよい。** 自分で作ったブランチには、作業環境が作業用に割り当てたブランチを含む。既定ブランチ（`main`）と、他人が作ったブランチには push しない。
- **自分で作ったブランチから PR を作成してよい。** PR の説明には、関係する ADR・backlog の番号と未完了の事項を書く。PR のマージ（既定ブランチへの取り込み）はプロジェクトオーナーが行う。
- **PR は draft で作成し、人間にレビューを求める段になったら、作成者が draft から ready for review に変える**（[ADR 8bb7](../decision/8bb7-pr-draft-until-review-ready.md)）。レビューを求める段とは、次のすべてを満たしたときである。
  - 依頼された作業、または backlog 項目の完了条件を満たした（[「一通りの作業」](#一通りの作業とは)）。
  - [コミット前の確認](#コミット前の確認)をすべて通し、push 済みで、CI が通っている。
  - 作成者の側で残る作業が無い。人間の判断を待つ事項や未完了の事項は、PR の説明に書いたうえで ready にしてよい。

  レビューで大きな作業の追加・やり直しを求められたら draft に戻してよく、その作業を終えたら同じ条件で再び ready にする。ready への変更はレビューとマージの依頼である。
- push と PR の作成の前に、[コミット前の確認](#コミット前の確認)をすべて通す。
- 履歴を書き換える操作（`git commit --amend` で既存コミットを変える、`rebase`、`reset --hard`、`push --force`）は、オーナーの指示がある場合に限る。push 済みのコミットも同様とし、PR への追加の変更は新しいコミット（必要ならマージコミット）で行う。

## 「一通りの作業」とは

次のいずれかが完了した時点でコミットする。

- 依頼された作業の 1 つ（例: ADR の追加、規約の改訂、backlog 項目 1 件の完了）
- backlog 項目の完了条件を満たしたとき（[backlog.md](backlog.md#完了の定義definition-of-done)）

作業の途中（検査が通っていない状態）ではコミットしない。

## コミット前の確認

- `docs/` を変更した場合: frontmatter・[docs/index.md](../index.md)・[docs/log.md](../log.md) を更新し、OKF とリンクの検査（[backlog ddbd](../backlog/ddbd-okf-bundle-lint.md)）を通す。
- 検査: `mise run check`（常時の段と、コミットしていない変更に関係する長い段。push と PR の作成の前は `CHECK_BASE=origin/main mise run check`）。全数 `mise run ci` を実行する時点（backlog 項目の完了・上流の版上げ・層の設定の変更）と、層の分け方は [checks.md](checks.md) による（[ADR 9c1c](../decision/9c1c-check-tiers-and-change-scoped-long-checks.md)。段ごとには `mise run lean:test` など。一覧は `mise tasks`。[ADR 44a0](../decision/44a0-mise-tasks-and-uv-for-tools.md)）。
- Rust を変更した場合: Verus の検証、`cargo kani`、`cargo test`（[spec-pivot/rust/verification.md](../../.agents/skills/spec-pivot/references/docs/lang/rust/verification.md#品質)）。
- Lean・Rust・上流を変更した場合: 追跡の検査 `trace check`（[ADR e2a4](../decision/e2a4-traceability-hash-as-deterministic-check-record.md)）。インベントリ・manifest を再生成して一緒にコミットする。
- 上流の版上げでは、旧版の最後のコミットに `upstream-<旧 release>` タグを付ける（[spec-pivot/upgrade.md](../../.agents/skills/spec-pivot/references/docs/guide/upgrade.md)）。
- 機密情報（鍵・パスワード・個人情報）を含めない。

## メッセージ

- 1 行目は変更内容の要約（日本語可、50 文字程度まで）。
- 本文に、関係する ADR・backlog の番号と、未完了の事項を書く。
- AI エージェントがコミットする場合は、その環境が求める帰属表示（`Co-Authored-By:` 行など）を末尾に付ける。
