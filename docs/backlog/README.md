---
type: Overview
title: "バックログ"
description: "作業項目の索引。状態と依存関係。"
tags: [backlog, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:00:00+09:00
---

# バックログ

運用は [rules/backlog.md](../rules/backlog.md)。状態は各項目の frontmatter の `state` が正である。

| ID | 項目 | state | 依存 |
| --- | --- | --- | --- |
| be49 | [Lean プロジェクトの雛形と CI](be49-lean-project-scaffold.md) | done | — |
| a8be | [LangSemantics.Java: Java 基本型の意味論](a8be-lang-semantics-java.md) | done | [be49](be49-lean-project-scaffold.md) |
| 591d | [Spec: ドメイン型・基本演算・マスタデータ](591d-abstract-domain-types-and-master-data.md) | done | [be49](be49-lean-project-scaffold.md) |
| 25f7 | [運賃計算（Spec と SourceModel）](25f7-fare-calculation-both-models.md) | done | [a8be](a8be-lang-semantics-java.md), [591d](591d-abstract-domain-types-and-master-data.md), [c7e8](c7e8-lang-semantics-sql.md), [1ae4](1ae4-machine-refinement-framework.md), [ffdc](ffdc-trace-tooling.md) |
| bbcc | [運賃計算の抽象化証明](bbcc-fare-abstraction-proofs.md) | done | [25f7](25f7-fare-calculation-both-models.md), [1ae4](1ae4-machine-refinement-framework.md), [ffdc](ffdc-trace-tooling.md) |
| 0be7 | [空席照会（B1）](0be7-flight-search-usecase.md) | todo | [25f7](25f7-fare-calculation-both-models.md), [c7e8](c7e8-lang-semantics-sql.md), [1ae4](1ae4-machine-refinement-framework.md), [f18c](f18c-java-oracle-harness.md), [bbcc](bbcc-fare-abstraction-proofs.md), [ffdc](ffdc-trace-tooling.md) |
| aedf | [予約（B0/B2）](aedf-reservation-usecase.md) | todo | [0be7](0be7-flight-search-usecase.md), [1ae4](1ae4-machine-refinement-framework.md), [f18c](f18c-java-oracle-harness.md), [bbcc](bbcc-fare-abstraction-proofs.md), [ffdc](ffdc-trace-tooling.md) |
| 4e0e | [会員（C1/C2）と入力検証](4e0e-member-usecases-and-input-validation.md) | todo | [591d](591d-abstract-domain-types-and-master-data.md), [1ae4](1ae4-machine-refinement-framework.md), [f18c](f18c-java-oracle-harness.md), [aedf](aedf-reservation-usecase.md), [ffdc](ffdc-trace-tooling.md) |
| 44f8 | [認証（A1/A2）](44f8-authentication-usecases.md) | todo | [4e0e](4e0e-member-usecases-and-input-validation.md), [f18c](f18c-java-oracle-harness.md), [ffdc](ffdc-trace-tooling.md) |
| ac71 | [予約履歴レポート（D1）](ac71-reservation-history-report.md) | todo | [aedf](aedf-reservation-usecase.md), [4e0e](4e0e-member-usecases-and-input-validation.md), [f18c](f18c-java-oracle-harness.md), [ffdc](ffdc-trace-tooling.md) |
| 4b0e | [Rust: インメモリアダプタとシードデータ](4b0e-in-memory-adapters-and-seed-data.md) | todo | [9c1b](9c1b-rust-usecases-core.md), [ffdc](ffdc-trace-tooling.md) |
| a8ef | [適合テストベクタの生成と検査（Lean 側）](a8ef-conformance-vector-format-and-generator.md) | todo | [25f7](25f7-fare-calculation-both-models.md) |
| f18c | [Java オラクルハーネス](f18c-java-oracle-harness.md) | todo | [a8ef](a8ef-conformance-vector-format-and-generator.md) |
| a89e | [Rust: HTTP 契約アダプタ](a89e-http-contract-adapter.md) | todo | [4b0e](4b0e-in-memory-adapters-and-seed-data.md), [f18c](f18c-java-oracle-harness.md), [bbcc](bbcc-fare-abstraction-proofs.md), [ffdc](ffdc-trace-tooling.md) |
| 31da | [第二言語での移植試行](31da-second-language-portability-pilot.md) | dropped | [a8ef](a8ef-conformance-vector-format-and-generator.md) |
| c7e8 | [LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論](c7e8-lang-semantics-sql.md) | done | [be49](be49-lean-project-scaffold.md) |
| ddbd | [OKF バンドルとリンクの検査](ddbd-okf-bundle-lint.md) | todo | [be49](be49-lean-project-scaffold.md) |
| fb50 | [Rust プロジェクトの雛形、Verus と Kani の併用確認、CI](fb50-rust-project-scaffold.md) | todo | — |
| ddb4 | [Rust: 運賃計算の移植先ソースと TargetModel の写し](ddb4-rust-spec-mirror-and-fare-core.md) | todo | [fb50](fb50-rust-project-scaffold.md), [eff6](eff6-target-model-fare-and-refinement.md), [d77c](d77c-verus-mirror-generator.md), [ffdc](ffdc-trace-tooling.md) |
| 9c1b | [Rust: 空席照会・予約・会員・認証・レポートの移植先ソース](9c1b-rust-usecases-core.md) | todo | [ddb4](ddb4-rust-spec-mirror-and-fare-core.md), [26c5](26c5-target-model-usecases-and-refinement.md), [ffdc](ffdc-trace-tooling.md) |
| a936 | [LangSemantics.Rust: Rust の意味論](a936-lang-semantics-rust.md) | todo | [be49](be49-lean-project-scaffold.md) |
| eff6 | [TargetModel と Refinement: 運賃計算](eff6-target-model-fare-and-refinement.md) | todo | [25f7](25f7-fare-calculation-both-models.md), [a8ef](a8ef-conformance-vector-format-and-generator.md), [a936](a936-lang-semantics-rust.md), [1ae4](1ae4-machine-refinement-framework.md), [ffdc](ffdc-trace-tooling.md) |
| 26c5 | [TargetModel と Refinement: 空席照会・予約・会員・認証・レポート](26c5-target-model-usecases-and-refinement.md) | todo | [eff6](eff6-target-model-fare-and-refinement.md), [0be7](0be7-flight-search-usecase.md), [aedf](aedf-reservation-usecase.md), [4e0e](4e0e-member-usecases-and-input-validation.md), [44f8](44f8-authentication-usecases.md), [ac71](ac71-reservation-history-report.md), [ffdc](ffdc-trace-tooling.md) |
| ffdc | [追跡の道具（tools/trace）](ffdc-trace-tooling.md) | done | [be49](be49-lean-project-scaffold.md), [455f](455f-upstream-submodule-and-inventory.md) |
| 455f | [上流の submodule 化と版の宣言](455f-upstream-submodule-and-inventory.md) | done | — |
| 773f | [差分オラクル（新旧 2 版の振る舞い比較）](773f-differential-oracle.md) | todo | [f18c](f18c-java-oracle-harness.md), [455f](455f-upstream-submodule-and-inventory.md) |
| 1ae4 | [Machine: 抽象機械と B メソッドのリファインメントの枠組み](1ae4-machine-refinement-framework.md) | done | [be49](be49-lean-project-scaffold.md) |
| d77c | [Lean TargetModel から Verus の写しを生成する道具](d77c-verus-mirror-generator.md) | todo | [be49](be49-lean-project-scaffold.md), [a936](a936-lang-semantics-rust.md) |
| 9c04 | [Rust: DB・ファイル・時計のアダプタと TargetModel.Adapter](9c04-rust-external-adapters.md) | todo | [4b0e](4b0e-in-memory-adapters-and-seed-data.md), [c7e8](c7e8-lang-semantics-sql.md), [ffdc](ffdc-trace-tooling.md) |
| f7b7 | [リファインメントの空虚化を防ぐ義務と検査](f7b7-refinement-non-vacuity.md) | done | [be49](be49-lean-project-scaffold.md), [1ae4](1ae4-machine-refinement-framework.md) |
| 0fdf | [Spec の非決定性の選択の型と入口の環境の前提](0fdf-spec-nondet-and-entry-env.md) | done | [591d](591d-abstract-domain-types-and-master-data.md), [f7b7](f7b7-refinement-non-vacuity.md) |
| ae04 | [名前付きの成分の必要性の義務と検査（G9）](ae04-component-necessity-witness.md) | done | [f7b7](f7b7-refinement-non-vacuity.md) |
| 0d1a | [名前付きの成分の変異テスト](0d1a-mutation-testing-of-named-components.md) | todo | [bbcc](bbcc-fare-abstraction-proofs.md), [ae04](ae04-component-necessity-witness.md) |
| c27d | [ギャップの証明の状態を Lean で表す](c27d-gap-evidence-states.md) | done | [38fb](38fb-move-generic-elements-to-skill.md) |
| 38fb | [アプリに依存しない道具・Lean のライブラリ・方法をスキルへ移す](38fb-move-generic-elements-to-skill.md) | done | [114a](114a-gap-attributes-and-trace-in-skill.md) |
| 114a | [追跡属性をスキルへ移し、ギャップを Lean の属性で表す](114a-gap-attributes-and-trace-in-skill.md) | done | [ffdc](ffdc-trace-tooling.md), [ae04](ae04-component-necessity-witness.md) |

## 推奨する着手順

```
移植元側（Lean）                 内側（Lean）            移植先側（Lean → Rust）
455f → ffdc ┐
be49 ┬ a8be, c7e8 ─────────┐
     ├ 1ae4（Machine）─ f7b7 ─ ae04 ┤
     ├ 591d ─ 25f7 ─ bbcc  ├─ a8ef ─ eff6 ─ ddb4（Rust）
     ├ a936 ─ d77c（生成器）┘
     └ ddbd
fb50（Rust 雛形・Verus/Kani 併用確認）は単独で先行可
機能: 4e0e → 44f8、0be7 → aedf → ac71 → 26c5 → 9c1b → 4b0e → a89e、4b0e → 9c04
原典との照合: f18c → 各機能（0be7・aedf・4e0e・44f8・ac71・a89e）、f18c → 773f
```
