---
type: Architecture Decision Record
title: "ADR と backlog の ID を UUID にし、ファイル名を ID の先頭 4 文字と slug にする"
description: "ADR・backlog の ID を 4 桁の連番から UUID v4（小文字 16 進）に改め、ファイル名を <ID の先頭 4 文字>-<slug>.md とする。道具が読む箇所は ID 全体を、本文は先頭 4 文字を書く。既存の 78 件を採番し直し、旧番号との対応表を残す。ADR d845 のファイル名の部分を置き換える。"
tags: [adr, process, backlog]
id: "f57e06e4-818f-4215-b71a-acfb47624a25"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T12:55:53+09:00
---

# ADR と backlog の ID を UUID にし、ファイル名を ID の先頭 4 文字と slug にする

## Context and Problem Statement

ADR と backlog は、4 桁ゼロ埋めの連番（`NNNN-<slug>.md`）で採番していた（[ADR d845](d845-record-architecture-decisions-with-madr.md)）。
複数のブランチ・セッションが並行して ADR や backlog を作ると、同じ番号を取り合う。
これまでも、マージのたびに番号を採り直し、本文の参照を書き換えてきた（旧番号 0039・0043・0044・0045 の ADR。[log.md](../log.md)）。
並行して作っても衝突しない ID の付け方を決める必要がある。

## Decision Drivers

* 並行するブランチで、調整なしに ID を採れること
* ファイル名と本文の参照が、人にとって短く読めること
* 道具（`tools/trace`・`check_obligations.py`）が、ID を一意に引けること
* 旧番号で書かれた記録（commit メッセージ、他のブランチ）を読み解けること
* 規則が決定論的に検査できること

## Considered Options

* 連番を続け、衝突したら採り直す
* UUID をそのままファイル名と参照に使う
* ID を UUID とし、ファイル名と本文の参照には先頭 4 文字を使う（重複を許し、slug で区別する）

## Decision Outcome

Chosen option: "ID を UUID とし、ファイル名と本文の参照には先頭 4 文字を使う", because 衝突しない ID と、短く読める名前を両立できるため。
先頭 4 文字が重なっても、ファイル名は slug で区別でき、道具は ID 全体で引くので、重複を禁じる必要がない。

* **ID**: UUID v4。小文字 16 進、ハイフン付きの 36 文字。先頭 4 文字が十進の数字だけのものは、旧番号と見分けにくいので使わない。
* **ファイル名**: `docs/decision/<ID の先頭 4 文字>-<slug>.md`、`docs/backlog/<ID の先頭 4 文字>-<slug>.md`。
* **ID 全体を書く箇所**（道具が読む）: frontmatter の `id`（ADR にも置く）・`depends_on`・`superseded_by`、`trace/features.json` の `backlog`、[spec/abstraction.md](../spec/abstraction.md)・[spec/refinement.md](../spec/refinement.md) の登録簿の backlog の列。
* **先頭 4 文字を書く箇所**: 本文・コード中のコメントの参照（`[ADR xxxx](…)`、`backlog xxxx`、列挙は `ADR xxxx・yyyy`）。先頭 4 文字が同じ種類の他の項目と重なる項目は、リンクの無い参照では stem（`ADR xxxx-<slug>`）で書く。
* **時系列**: 連番の順は失われる。ADR は `date`、backlog は依存関係と [backlog/README.md](../backlog/README.md) の着手順で追う。
* **道具**: `tools/docs/ids.py`。`new` が ID とファイル名を出し、`check` が ID・ファイル名・参照を検査し（`tools/ci/lean.sh`）、`migrate` が旧番号を新 ID に書き換える。
* **旧番号**: 既存の ADR 45 件と backlog 33 件を採番し直した。旧番号の stem と ID の対応は `tools/docs/legacy-ids.json` に置く（下の表と同じ）。旧番号で書かれたブランチを取り込んだら `ids.py migrate` を実行する。過去の文書と [log.md](../log.md) の参照も新 ID に書き換えた。採番の経緯を述べた箇所の番号は「旧番号」と明記して残した。

[ADR d845](d845-record-architecture-decisions-with-madr.md) のうち、ファイル名を `NNNN-<slug>.md` とする部分を本 ADR で置き換える。MADR 形式とする決定はそのまま有効である。

### Consequences

* Good, because 並行するブランチで ADR・backlog を作っても、番号の採り直しと参照の書き換えが要らない
* Good, because 道具は frontmatter の `id` で backlog を引くので、ファイル名の形に依存しない
* Good, because 参照の解決・リンク先の実在・旧形式の残りを `ids.py check` で決定論的に検査できる
* Bad, because ファイル名から作成の順序が分からなくなる
* Bad, because 登録簿の backlog の列が 36 文字になり、表が広くなる
* Bad, because 旧番号を含む commit メッセージや外部の記録は、対応表を介して読む必要がある

### Confirmation

* `python3 -I tools/docs/ids.py check` を `tools/ci/lean.sh` で実行する。ファイル名と `id` の一致、ID の一意性、`depends_on`・`superseded_by`・`features.json`・登録簿の ID の実在、本文の参照の解決、ADR・backlog へのリンク先の実在を検査する。
* `tools/ci/check_obligations.py --self-test` と `tools/trace` の `cargo test` が、UUID の backlog の状態で段階導入を判定できることを確かめる。

## Pros and Cons of the Options

### 連番を続け、衝突したら採り直す

* Good, because 番号から順序が分かり、参照が短い
* Bad, because 並行するブランチで衝突し、マージのたびに採り直しと全文の書き換えが要る

### UUID をそのままファイル名と参照に使う

* Good, because 常に一意で、規則が単純
* Bad, because ファイル名と 900 箇所近い本文の参照が長くなり、読みにくい

### ID を UUID とし、ファイル名と本文の参照には先頭 4 文字を使う

* Good, because 衝突しない ID と短い名前を両立する
* Bad, because 先頭 4 文字が重なる場合の書き方（stem）を規則に持つ必要がある

## More Information

* 規約: [rules/decision-records.md](../rules/decision-records.md)、[rules/backlog.md](../rules/backlog.md)、[rules/documentation.md](../rules/documentation.md#リンク)
* 道具: `tools/docs/ids.py`、対応表 `tools/docs/legacy-ids.json`

### 旧番号と ID の対応

#### ADR

| 旧番号 | ID | ファイル |
| --- | --- | --- |
| 0001 | `d845e30d-651f-4772-a180-4abe056d7796` | [d845-record-architecture-decisions-with-madr.md](../decision/d845-record-architecture-decisions-with-madr.md) |
| 0002 | `84bfbea8-5da1-49a5-ace7-f38db5992d26` | [84bf-porting-scope.md](../decision/84bf-porting-scope.md) |
| 0003 | `3b0ab328-a955-4296-a49f-8b6b28cb3b1a` | [3b0a-spec-as-normative-source.md](../decision/3b0a-spec-as-normative-source.md) |
| 0004 | `a43d7889-12f1-468f-8ae5-85616febe9c6` | [a43d-two-layer-model-java-faithful-and-abstract.md](../decision/a43d-two-layer-model-java-faithful-and-abstract.md) |
| 0005 | `935beea6-484c-40f8-8e58-8a9c43f1bb61` | [935b-java-primitive-semantics.md](../decision/935b-java-primitive-semantics.md) |
| 0006 | `e41d046b-519e-43c7-872c-cd4f807f8941` | [e41d-exact-integer-arithmetic-in-abstract-model.md](../decision/e41d-exact-integer-arithmetic-in-abstract-model.md) |
| 0007 | `f0e4889d-5cbf-4c3d-b194-d62a87d0ff45` | [f0e4-functional-core-with-ports.md](../decision/f0e4-functional-core-with-ports.md) |
| 0008 | `a4fa924b-2e38-4b68-918d-1cf4aadefab5` | [a4fa-errors-as-values-with-stable-codes.md](../decision/a4fa-errors-as-values-with-stable-codes.md) |
| 0009 | `6eb2264c-1ab2-466e-9019-56b04386cf08` | [6eb2-date-and-time-model.md](../decision/6eb2-date-and-time-model.md) |
| 0010 | `10a5a064-d7b8-4607-ae9a-ea41aacd46f8` | [10a5-text-length-and-character-classes.md](../decision/10a5-text-length-and-character-classes.md) |
| 0011 | `97f9f4bc-43d3-4ec9-863f-e070387d0739` | [97f9-persistence-and-transaction-semantics.md](../decision/97f9-persistence-and-transaction-semantics.md) |
| 0012 | `1b002128-29b2-4638-ae70-5acdde3386ce` | [1b00-http-contract-specification.md](../decision/1b00-http-contract-specification.md) |
| 0013 | `dc3a6a3c-03fd-445a-8856-f9e130cb35cf` | [dc3a-conformance-test-vectors.md](../decision/dc3a-conformance-test-vectors.md) |
| 0014 | `659f8739-1579-4d0b-8640-77ef36c4b235` | [659f-lean-toolchain-and-dependencies.md](../decision/659f-lean-toolchain-and-dependencies.md) |
| 0015 | `2d1fa701-c1a5-43c4-982e-4ff80a79a603` | [2d1f-password-hashing-port.md](../decision/2d1f-password-hashing-port.md) |
| 0016 | `ff4d73a5-05e5-41d8-8891-e0585c7cdf81` | [ff4d-asynchronous-report-generation.md](../decision/ff4d-asynchronous-report-generation.md) |
| 0017 | `a0f1f899-b342-4e15-881f-8878d29680d7` | [a0f1-documentation-format-okf-v0-2.md](../decision/a0f1-documentation-format-okf-v0-2.md) |
| 0018 | `3e1d0a0c-a87e-42be-af3d-40110fa20351` | [3e1d-language-neutral-top-level-namespaces.md](../decision/3e1d-language-neutral-top-level-namespaces.md) |
| 0019 | `5fcb0c8c-6512-4275-84bb-3046874de7f9` | [5fcb-sql-semantics-for-source-repositories.md](../decision/5fcb-sql-semantics-for-source-repositories.md) |
| 0020 | `dd0fe79a-3c1b-4b0a-903f-af29ba1f41a1` | [dd0f-rust-as-target-language.md](../decision/dd0f-rust-as-target-language.md) |
| 0021 | `61bce953-a515-42f0-a216-a3af9ef39e1d` | [61bc-lean-spec-as-normative-source.md](../decision/61bc-lean-spec-as-normative-source.md) |
| 0022 | `796cdc52-2288-46c9-a061-40bc68d61fa4` | [796c-models-in-lean-and-sources-traced-at-both-ends.md](../decision/796c-models-in-lean-and-sources-traced-at-both-ends.md) |
| 0023 | `81ab9a21-02d3-4fe4-8f3a-53366e2cb7c9` | [81ab-cross-language-traceability.md](../decision/81ab-cross-language-traceability.md) |
| 0024 | `3f36f0b6-9a74-46a9-a75a-66fd601b538d` | [3f36-following-upstream-releases.md](../decision/3f36-following-upstream-releases.md) |
| 0025 | `f4e1419f-97dc-4629-b465-b90a88300568` | [f4e1-extract-porting-method-as-agent-skill.md](../decision/f4e1-extract-porting-method-as-agent-skill.md) |
| 0026 | `ac33c0e6-b9cd-4d5d-a557-7eceb6670a48` | [ac33-email-validation-rule.md](../decision/ac33-email-validation-rule.md) |
| 0027 | `e24e3004-4e8e-4096-adb4-2c7e7d8820df` | [e24e-validation-error-ordering.md](../decision/e24e-validation-error-ordering.md) |
| 0028 | `9ee48fe1-9894-43e4-a2fd-48e81954b63c` | [9ee4-clock-timezone-and-fixture-base-date.md](../decision/9ee4-clock-timezone-and-fixture-base-date.md) |
| 0029 | `41f7faa3-9f34-4730-95b3-c91173dd2a58` | [41f7-concurrency-failure-as-conflict-error.md](../decision/41f7-concurrency-failure-as-conflict-error.md) |
| 0030 | `578b46a6-486f-4998-8245-4d1a89840ee1` | [578b-member-update-in-single-transaction.md](../decision/578b-member-update-in-single-transaction.md) |
| 0031 | `90f57e28-6457-40a3-a50c-43683fb05336` | [90f5-report-queue-at-least-once-delivery.md](../decision/90f5-report-queue-at-least-once-delivery.md) |
| 0032 | `e10f17b4-5c61-4adf-9175-fee48c2388ac` | [e10f-spec-corrects-unsafe-source-behavior.md](../decision/e10f-spec-corrects-unsafe-source-behavior.md) |
| 0033 | `c3364914-71b0-4e9e-b193-a5b4e261583f` | [c336-foundational-principles.md](../decision/c336-foundational-principles.md) |
| 0034 | `01d40490-d5c8-4239-a74e-c3e8b2004b7c` | [01d4-b-method-refinement-and-explicit-deviations.md](../decision/01d4-b-method-refinement-and-explicit-deviations.md) |
| 0035 | `0bd389b9-3285-4134-9408-200fb9c0a666` | [0bd3-generate-verus-mirror-from-target-model.md](../decision/0bd3-generate-verus-mirror-from-target-model.md) |
| 0036 | `e2a45550-1535-4d77-b945-d3dcb49fd16b` | [e2a4-traceability-hash-as-deterministic-check-record.md](../decision/e2a4-traceability-hash-as-deterministic-check-record.md) |
| 0037 | `e56eec10-e852-4b8b-ba4d-fef0ca37baf8` | [e56e-conflict-as-spec-nondeterminism.md](../decision/e56e-conflict-as-spec-nondeterminism.md) |
| 0038 | `6edfa687-49f5-4f4e-a708-d4cc0c475ace` | [6edf-lean-package-under-skill-assets-lean.md](../../.agents/skills/spec-pivot/references/docs/decision/6edf-lean-package-under-skill-assets-lean.md) |
| 0039 | `70ebaf6b-ec24-4790-bdc2-543d6734dda0` | [70eb-refinement-non-vacuity-obligations.md](../decision/70eb-refinement-non-vacuity-obligations.md) |
| 0040 | `0eeac635-5514-4dbb-a7b1-47c6328eeddf` | [0eea-trace-tooling-unresolved-details.md](../../.agents/skills/spec-pivot/references/docs/decision/0eea-trace-tooling-unresolved-details.md) |
| 0041 | `9cd93670-deeb-4878-bba4-aa51f977d6ae` | [9cd9-rehash-diff-impact-details.md](../../.agents/skills/spec-pivot/references/docs/decision/9cd9-rehash-diff-impact-details.md) |
| 0042 | `8f184bed-5fb3-4da6-8ee1-e2d3a0ffdeb6` | [8f18-fare-source-model-and-shared-vectors.md](../decision/8f18-fare-source-model-and-shared-vectors.md) |
| 0043 | `9ac6367a-6c10-4d55-a1fe-167d6ce59f17` | [9ac6-vacuity-literature-necessity-and-mutation.md](../decision/9ac6-vacuity-literature-necessity-and-mutation.md) |
| 0044 | `0b83c75e-af18-453d-8384-f30da3c66bee` | [0b83-porting-conditions-and-workflow.md](../../.agents/skills/spec-pivot/references/docs/decision/0b83-porting-conditions-and-workflow.md) |
| 0045 | `c10895a2-8187-428d-8c87-f925e9c55a4e` | [c108-master-data-source-model-and-spec-fixes.md](../decision/c108-master-data-source-model-and-spec-fixes.md) |

#### backlog

| 旧番号 | ID | ファイル |
| --- | --- | --- |
| 0001 | `be4969d4-478c-47a9-8fd9-b8cf31202bc8` | [be49-lean-project-scaffold.md](../backlog/be49-lean-project-scaffold.md) |
| 0002 | `a8be97e4-d846-4b86-bfcc-413d6d980578` | [a8be-lang-semantics-java.md](../backlog/a8be-lang-semantics-java.md) |
| 0003 | `591d9aa4-065b-4975-8146-86aae05b780a` | [591d-abstract-domain-types-and-master-data.md](../backlog/591d-abstract-domain-types-and-master-data.md) |
| 0004 | `25f7ef96-f77d-4ed8-973d-8cecc2a0f227` | [25f7-fare-calculation-both-models.md](../backlog/25f7-fare-calculation-both-models.md) |
| 0005 | `bbcce088-c475-4378-9cc6-e3d821acc0f5` | [bbcc-fare-abstraction-proofs.md](../backlog/bbcc-fare-abstraction-proofs.md) |
| 0006 | `0be7c5d4-01d9-43f4-a50d-227f174830f0` | [0be7-flight-search-usecase.md](../backlog/0be7-flight-search-usecase.md) |
| 0007 | `aedfeffc-3e82-46b1-b497-3d8b7808d068` | [aedf-reservation-usecase.md](../backlog/aedf-reservation-usecase.md) |
| 0008 | `4e0e3dd1-d282-46e2-aa98-719853bc9fd2` | [4e0e-member-usecases-and-input-validation.md](../backlog/4e0e-member-usecases-and-input-validation.md) |
| 0009 | `44f89eb1-e59a-4573-8129-7b0c1d4699bb` | [44f8-authentication-usecases.md](../backlog/44f8-authentication-usecases.md) |
| 0010 | `ac713033-9b94-4e5a-bfc4-d27bdee7ee2e` | [ac71-reservation-history-report.md](../backlog/ac71-reservation-history-report.md) |
| 0011 | `4b0e2070-e086-4966-95f8-9e366f4324a0` | [4b0e-in-memory-adapters-and-seed-data.md](../backlog/4b0e-in-memory-adapters-and-seed-data.md) |
| 0012 | `a8ef4e5b-1870-4669-9398-1916a439a6f7` | [a8ef-conformance-vector-format-and-generator.md](../backlog/a8ef-conformance-vector-format-and-generator.md) |
| 0013 | `f18c3c0f-4007-42c1-ba25-102fb385a16c` | [f18c-java-oracle-harness.md](../backlog/f18c-java-oracle-harness.md) |
| 0014 | `a89ec8f0-4d15-46a6-86fa-a640e4df0b44` | [a89e-http-contract-adapter.md](../backlog/a89e-http-contract-adapter.md) |
| 0015 | `31da2562-49f1-4c27-866e-723e126e8da1` | [31da-second-language-portability-pilot.md](../backlog/31da-second-language-portability-pilot.md) |
| 0016 | `c7e8d83d-8d90-44fe-a6f5-de54b2efe811` | [c7e8-lang-semantics-sql.md](../backlog/c7e8-lang-semantics-sql.md) |
| 0017 | `ddbd8fec-9d87-4ba1-a2bf-58d0f159ae50` | [ddbd-okf-bundle-lint.md](../backlog/ddbd-okf-bundle-lint.md) |
| 0018 | `fb50dcb4-2c24-46aa-ad02-cee5924cd095` | [fb50-rust-project-scaffold.md](../backlog/fb50-rust-project-scaffold.md) |
| 0019 | `ddb4cafe-4bc3-4235-8efa-7f6eb7ff0ea8` | [ddb4-rust-spec-mirror-and-fare-core.md](../backlog/ddb4-rust-spec-mirror-and-fare-core.md) |
| 0020 | `9c1b5a33-ee88-4bd7-87f3-05094c95b55b` | [9c1b-rust-usecases-core.md](../backlog/9c1b-rust-usecases-core.md) |
| 0021 | `a936801c-476d-4b16-baed-ca3bab07cee3` | [a936-lang-semantics-rust.md](../../.agents/skills/spec-pivot/references/docs/backlog/a936-lang-semantics-rust.md) |
| 0022 | `eff6bfce-0ef0-49a1-8c6e-e2b7235fd113` | [eff6-target-model-fare-and-refinement.md](../backlog/eff6-target-model-fare-and-refinement.md) |
| 0023 | `26c57ac3-b6b7-440a-aca5-994943bd7ebd` | [26c5-target-model-usecases-and-refinement.md](../backlog/26c5-target-model-usecases-and-refinement.md) |
| 0024 | `ffdc480d-eaf2-42a0-9818-0b128e9403d4` | [ffdc-trace-tooling.md](../backlog/ffdc-trace-tooling.md) |
| 0025 | `455ffb21-3a0e-4833-b82c-2d972bfec450` | [455f-upstream-submodule-and-inventory.md](../backlog/455f-upstream-submodule-and-inventory.md) |
| 0026 | `773f2c47-5a43-4da9-9c16-b9f36bfe5765` | [773f-differential-oracle.md](../backlog/773f-differential-oracle.md) |
| 0027 | `1ae40815-ac5a-4602-99bc-1d9ad267dd0b` | [1ae4-machine-refinement-framework.md](../../.agents/skills/spec-pivot/references/docs/backlog/1ae4-machine-refinement-framework.md) |
| 0028 | `d77caf9a-257d-4bcc-9be8-f34b6c03f2b6` | [d77c-verus-mirror-generator.md](../backlog/d77c-verus-mirror-generator.md) |
| 0029 | `9c0448f7-eb9f-43ec-8364-d8b6dd1ec01f` | [9c04-rust-external-adapters.md](../backlog/9c04-rust-external-adapters.md) |
| 0030 | `f7b791e2-3d95-4436-a2d9-0320ad16a4fa` | [f7b7-refinement-non-vacuity.md](../backlog/f7b7-refinement-non-vacuity.md) |
| 0031 | `0fdf5090-3432-4a6e-9064-40f53e4231a9` | [0fdf-spec-nondet-and-entry-env.md](../backlog/0fdf-spec-nondet-and-entry-env.md) |
| 0032 | `ae0448b1-af43-4d95-af6f-cfec8c58768c` | [ae04-component-necessity-witness.md](../backlog/ae04-component-necessity-witness.md) |
| 0033 | `0d1a6233-ace0-4abe-9b9a-ed032d7b7f59` | [0d1a-mutation-testing-of-named-components.md](../backlog/0d1a-mutation-testing-of-named-components.md) |
