---
type: Overview
title: "バックログ"
description: "作業項目の索引。状態と依存関係。"
tags: [backlog, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:30:00+09:00
---

# バックログ

運用は [rules/backlog.md](../rules/backlog.md)。状態は各項目の frontmatter の `state` が正である。

| ID | 項目 | state | 依存 |
| --- | --- | --- | --- |
| 0001 | [Lean プロジェクトの雛形と CI](0001-lean-project-scaffold.md) | done | — |
| 0002 | [LangSemantics.Java: Java 基本型の意味論](0002-lang-semantics-java.md) | todo | 0001 |
| 0003 | [Spec: ドメイン型・基本演算・マスタデータ](0003-abstract-domain-types-and-master-data.md) | todo | 0001 |
| 0004 | [運賃計算（Spec と SourceModel）](0004-fare-calculation-both-models.md) | todo | 0002, 0003, 0016, 0027, 0024 |
| 0005 | [運賃計算の抽象化証明](0005-fare-abstraction-proofs.md) | todo | 0004, 0027, 0013, 0024 |
| 0006 | [空席照会（B1）](0006-flight-search-usecase.md) | todo | 0004, 0016, 0027, 0013, 0005, 0024 |
| 0007 | [予約（B0/B2）](0007-reservation-usecase.md) | todo | 0006, 0027, 0013, 0005, 0024 |
| 0008 | [会員（C1/C2）と入力検証](0008-member-usecases-and-input-validation.md) | todo | 0003, 0027, 0013, 0007, 0024 |
| 0009 | [認証（A1/A2）](0009-authentication-usecases.md) | todo | 0008, 0013, 0024 |
| 0010 | [予約履歴レポート（D1）](0010-reservation-history-report.md) | todo | 0007, 0008, 0013, 0024 |
| 0011 | [Rust: インメモリアダプタとシードデータ](0011-in-memory-adapters-and-seed-data.md) | todo | 0020, 0024 |
| 0012 | [適合テストベクタの生成と検査（Lean 側）](0012-conformance-vector-format-and-generator.md) | todo | 0004 |
| 0013 | [Java オラクルハーネス](0013-java-oracle-harness.md) | todo | 0012 |
| 0014 | [Rust: HTTP 契約アダプタ](0014-http-contract-adapter.md) | todo | 0011, 0013, 0005, 0024 |
| 0015 | [第二言語での移植試行](0015-second-language-portability-pilot.md) | dropped | 0012 |
| 0016 | [LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論](0016-lang-semantics-sql.md) | todo | 0001 |
| 0017 | [OKF バンドルとリンクの検査](0017-okf-bundle-lint.md) | todo | 0001 |
| 0018 | [Rust プロジェクトの雛形、Verus と Kani の併用確認、CI](0018-rust-project-scaffold.md) | todo | — |
| 0019 | [Rust: 運賃計算の移植先ソースと TargetModel の写し](0019-rust-spec-mirror-and-fare-core.md) | todo | 0018, 0022, 0028, 0024 |
| 0020 | [Rust: 空席照会・予約・会員・認証・レポートの移植先ソース](0020-rust-usecases-core.md) | todo | 0019, 0023, 0024 |
| 0021 | [LangSemantics.Rust: Rust の意味論](0021-lang-semantics-rust.md) | todo | 0001 |
| 0022 | [TargetModel と Refinement: 運賃計算](0022-target-model-fare-and-refinement.md) | todo | 0004, 0012, 0021, 0027, 0024 |
| 0023 | [TargetModel と Refinement: 空席照会・予約・会員・認証・レポート](0023-target-model-usecases-and-refinement.md) | todo | 0022, 0006, 0007, 0008, 0009, 0010, 0024 |
| 0024 | [追跡の道具（tools/trace）](0024-trace-tooling.md) | todo | 0001, 0025 |
| 0025 | [上流の submodule 化と版の宣言](0025-upstream-submodule-and-inventory.md) | done | — |
| 0026 | [差分オラクル（新旧 2 版の振る舞い比較）](0026-differential-oracle.md) | todo | 0013, 0025 |
| 0027 | [Machine: 抽象機械と B メソッドのリファインメントの枠組み](0027-machine-refinement-framework.md) | done | 0001 |
| 0028 | [Lean TargetModel から Verus の写しを生成する道具](0028-verus-mirror-generator.md) | todo | 0001, 0021 |
| 0029 | [Rust: DB・ファイル・時計のアダプタと TargetModel.Adapter](0029-rust-external-adapters.md) | todo | 0011, 0016, 0024 |
| 0030 | [リファインメントの空虚化を防ぐ義務と検査](0030-refinement-non-vacuity.md) | done | 0001, 0027 |

## 推奨する着手順

```
移植元側（Lean）                 内側（Lean）            移植先側（Lean → Rust）
0025 → 0024 ┐
0001 ┬ 0002, 0016 ─────────┐
     ├ 0027（Machine）─ 0030 ┤
     ├ 0003 ─ 0004 ─ 0005  ├─ 0012 ─ 0022 ─ 0019（Rust）
     ├ 0021 ─ 0028（生成器）┘
     └ 0017
0018（Rust 雛形・Verus/Kani 併用確認）は単独で先行可
機能: 0008 → 0009、0006 → 0007 → 0010 → 0023 → 0020 → 0011 → 0014、0011 → 0029
原典との照合: 0013 → 各機能（0005〜0010・0014）、0013 → 0026
```
