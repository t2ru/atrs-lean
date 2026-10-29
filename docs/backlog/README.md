---
type: Overview
title: "バックログ"
description: "作業項目の索引。状態と依存関係。"
tags: [backlog, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# バックログ

運用は [rules/backlog.md](../rules/backlog.md)。状態は各項目の frontmatter の `state` が正である。

| ID | 項目 | state | 依存 |
| --- | --- | --- | --- |
| 0001 | [Lean プロジェクトの雛形と CI](0001-lean-project-scaffold.md) | todo | — |
| 0002 | [LangSemantics.Java: Java 基本型の意味論](0002-lang-semantics-java.md) | todo | 0001 |
| 0003 | [Spec: ドメイン型・基本演算・マスタデータ](0003-abstract-domain-types-and-master-data.md) | todo | 0001 |
| 0004 | [運賃計算（Spec と SourceModel）](0004-fare-calculation-both-models.md) | todo | 0002, 0003 |
| 0005 | [運賃計算の抽象化証明](0005-fare-abstraction-proofs.md) | todo | 0004 |
| 0006 | [空席照会（B1）](0006-flight-search-usecase.md) | todo | 0004, 0016 |
| 0007 | [予約（B0/B2）](0007-reservation-usecase.md) | todo | 0006 |
| 0008 | [会員（C1/C2）と入力検証](0008-member-usecases-and-input-validation.md) | todo | 0003 |
| 0009 | [認証（A1/A2）](0009-authentication-usecases.md) | todo | 0008 |
| 0010 | [予約履歴レポート（D1）](0010-reservation-history-report.md) | todo | 0007 |
| 0011 | [Rust: インメモリアダプタとシードデータ](0011-in-memory-adapters-and-seed-data.md) | todo | 0020 |
| 0012 | [適合テストベクタの生成と検査（Lean 側）](0012-conformance-vector-format-and-generator.md) | todo | 0004 |
| 0013 | [Java オラクルハーネス](0013-java-oracle-harness.md) | todo | 0012 |
| 0014 | [Rust: HTTP 契約アダプタ](0014-http-contract-adapter.md) | todo | 0011 |
| 0015 | [第二言語での移植試行](0015-second-language-portability-pilot.md) | dropped | 0012 |
| 0016 | [LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論](0016-lang-semantics-sql.md) | todo | 0001 |
| 0017 | [OKF バンドルとリンクの検査](0017-okf-bundle-lint.md) | todo | 0001 |
| 0018 | [Rust プロジェクトの雛形、Verus と Kani の併用確認、CI](0018-rust-project-scaffold.md) | todo | — |
| 0019 | [Rust: Spec の Verus 写しと運賃計算コア](0019-rust-spec-mirror-and-fare-core.md) | todo | 0004, 0012, 0018 |
| 0020 | [Rust: 空席照会・予約・会員・認証・レポートのコア](0020-rust-usecases-core.md) | todo | 0006, 0007, 0008, 0009, 0010, 0019 |

## 推奨する着手順

Lean（正規仕様と抽象化証明）と Rust（移植先と具体化証明）は並行して進められる。

1. 基盤: Lean 0001 → 0017, 0002, 0016, 0003（並行可）／ Rust 0018（Verus と Kani の併用確認を最優先）
2. 運賃: 0004 → 0012 → 0005、Rust 0019（0004・0012・0018 の後）
3. 機能（Lean）: 0008 → 0009、0006 → 0007 → 0010
4. 機能（Rust）: 0020 → 0011 → 0014
5. 原典との照合: 0013（0012 の後いつでも）
