---
type: Guideline
title: "ATRS での port-lang スキルの適用"
description: "言語間移植の方法（スキル port-lang）を ATRS に適用するときの固有事項。言語ペア、リポジトリ配置、機能名、型、依存フレームワーク、追従中の上流、ATRS で採った値。"
tags: [rules, porting, atrs]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# ATRS での port-lang スキルの適用

移植の **方法** は、アプリに依存しないスキル [port-lang](../../.agents/skills/port-lang/SKILL.md) に従う（[ADR 0025](../decision/0025-extract-porting-method-as-agent-skill.md)）。
本書は、それを ATRS に適用するときの **固有事項** だけを定める。スキルと本書が食い違う場合は、ATRS の ADR が優先し、次に本書、次にスキルの順とする。

## 言語ペアと使う言語パック

| 役割 | 言語 | 言語パック | ATRS で使う主な対象 |
| --- | --- | --- | --- |
| 移植元 | Java | `references/java/` | Spring MVC、Spring Security、Bean Validation（Hibernate Validator）、Jackson、MyBatis |
| 移植元 | SQL | `references/sql/`（方言 `references/sql/dialects/postgresql/`） | PostgreSQL、MyBatis の Mapper XML、`atrs-initdb` の DDL・シード |
| 移植先 | Rust | `references/rust/` | Verus、Kani |
| 形式化 | Lean 4 | `references/lean/` | core + Batteries（Mathlib 不使用。[ADR 0014](../decision/0014-lean-toolchain-and-dependencies.md)） |

使うスキルの版: `metadata.version` = `0.2`。言語意味論の Lean モデルは、スキルの `assets/LangSemantics/`（`Java`, `Sql`, `Sql.Postgresql`, `Rust`）を `lean/LangSemantics/` に取り込んで使う。ATRS に固有の定義を `LangSemantics` に足してはならない（不足はスキルの assets 側に足す）。スキルを更新したら、本書の版の記載と影響する ADR を見直す。

スキルの一般的な名前と、ATRS での置き場所は次のとおり。

| スキルでの名前 | ATRS での置き場所 |
| --- | --- |
| 保証の限界の文書 | [spec/assurance.md](../spec/assurance.md) |
| 移植元側の既知差異（`D-NNN`）と抽象化の課題 | [spec/abstraction.md](../spec/abstraction.md) |
| 移植先側の既知差異（`T-NNN`）と具体化・確認の課題 | [spec/refinement.md](../spec/refinement.md) |
| リファインメントの枠組み `Machine` | スキルの `assets/Machine/` を Lake 依存として取り込む（[backlog 0027](../backlog/0027-machine-refinement-framework.md)。[ADR 0034](../decision/0034-b-method-refinement-and-explicit-deviations.md)、[ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)） |
| 移植先の写しの生成器 | `lean/Tools/GenVerus`（`lake exe gen-verus`。[backlog 0028](../backlog/0028-verus-mirror-generator.md)） |

## リポジトリ配置

| パス | 内容 |
| --- | --- |
| `lakefile.lean`, `lean-toolchain`, `lake-manifest.json`（ルート） | Lake ワークスペース。Lean の LSP がルートから import を解決できるよう、スキルの `assets`（`langSemantics`）と `lean/` を `require` する。ルートの `lean-toolchain` は `leanprover/lean4:v4.35.0` で、全パッケージと同じ版にする |
| `upstream/atrs` | 移植元ソース（submodule。[backlog 0025](../backlog/0025-upstream-submodule-and-inventory.md)） |
| `lean/` | Lean プロジェクト（全モデルと証明） |
| `rust/` | 移植先ソース。パッケージ名 `atrs` |
| `conformance/` | 適合テストベクタ |
| `trace/` | 版の宣言・インベントリ・manifest |
| `tools/trace/` | 追跡の道具 |

## 追従中の上流

| 項目 | 値 |
| --- | --- |
| repo | <https://github.com/terasolunaorg/atrs> |
| variant | `JavaConfig-Thymeleaf` |
| release | `release/5.11.0.RELEASE` |
| commit | `f4bfbf0615eb91805546c9c780d4761be92ce17e` |

上流が依存する主な版（2026-10-29 に上流の `pom.xml` と、親 `terasoluna-gfw-parent`・BOM `terasoluna-dependencies` から調べた値）:

| 依存 | 版 | 出所 |
| --- | --- | --- |
| Java | 17 | `pom.xml` の `java-version` |
| TERASOLUNA Server Framework（`terasoluna-gfw-parent`） | 5.11.0.RELEASE | `pom.xml` の親 |
| BOM `org.terasoluna.bom:terasoluna-dependencies` | 3.0.0.RELEASE | `terasoluna-gfw-parent` |
| Spring Boot BOM（依存管理のみ。Spring Boot 本体は使わない） | 4.0.2 | `terasoluna-dependencies` |
| Spring Framework | 7.0.3 | Spring Boot BOM 4.0.2 |
| Hibernate Validator | 9.1.0.Final | `terasoluna-dependencies` |
| Jackson | 3.0.4（`tools.jackson`）と 2.20.2（`com.fasterxml.jackson`）の両方 | Spring Boot BOM 4.0.2、`terasoluna-gfw-common-dependencies` |
| MyBatis | 3.5.19 | `terasoluna-dependencies` |
| PostgreSQL JDBC | 42.7.9 | `pom.xml` |
| Tomcat（cargo で起動） | 11.0.15 | `terasoluna-gfw-parent` |

道具の導入後は `trace/upstream.json` を正とする（[ADR 0024](../decision/0024-following-upstream-releases.md)）。

## 機能名（層をまたいで共通）

| Lean の下位名前空間 | Rust モジュール | ベクタの `<feature>` | 仕様の草案 |
| --- | --- | --- | --- |
| `Fare` | `fare` | `fare` | [fare-calculation.md](../spec/fare-calculation.md) |
| `FlightSearch` | `flight_search` | `flight-search` | [flight-search.md](../spec/flight-search.md) |
| `Ticket`, `UseCase.Reserve` | `reservation` | `reservation` | [reservation.md](../spec/reservation.md) |
| `UseCase.Member` | `member` | `member` | [member.md](../spec/member.md) |
| `UseCase.Auth` | `auth` | `authentication` | [authentication.md](../spec/authentication.md) |
| `UseCase.Report` | `report` | `report` | [reservation-history-report.md](../spec/reservation-history-report.md) |
| `Validation` | `validation` | `validation` | [input-validation.md](../spec/input-validation.md) |
| `Model`, `MasterData`, `CodeList`, `Config`, `Prim.Format` | `model_types`, `master_data` | `format` | [domain-model.md](../spec/domain-model.md), [master-data.md](../spec/master-data.md) |
| `Error`, `Message` | `error` | — | [errors-and-messages.md](../spec/errors-and-messages.md) |
| `Repository.*` | `adapter` | — | [ports.md](../spec/ports.md) |
| `Http` | `adapter::http` | `http` | [http-contract.md](../spec/http-contract.md) |

- エラー型の名前は `AtrsError`（[ADR 0008](../decision/0008-errors-as-values-with-stable-codes.md)）。
- Rust の `model/` には、上表の Rust モジュール名で `TargetModel` の写しを置く。

## Spec の型（ATRS）

| 量 | 型 |
| --- | --- |
| 金額・人数・日数・百分率・積算比率 | `Nat` |
| 空港コード・便名・会員番号・予約番号 | 専用 `structure` |
| `FlightType`, `BoardingClassCd`, `FareTypeCd`, `Gender`, `LineType` | `inductive`（綴りは原典の Java enum と同一） |

値域は [domain-model.md](../spec/domain-model.md#値域) に従う。

## `@[source]` に必ず含める依存（ATRS）

原典が暗黙に受けている効果（スキルの `java/frameworks.md`）のうち、ATRS で使われているものを次に示す。これらに依存する `SourceModel` の定義には、必ず `dep:` ロケータを付ける。

| 効果 | ロケータ | ATRS で影響する仕様 |
| --- | --- | --- |
| 画面入力の前後空白の除去と空文字の null 化 | `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText` | [input-validation.md#前処理](../spec/input-validation.md#前処理) |
| Bean Validation の制約（UTF-16 長、null 合格、違反の並びが順序不定、`@Email` の判定） | `dep:org.hibernate.validator:hibernate-validator#…` | [input-validation.md](../spec/input-validation.md) |
| `@InitBinder` の名前一致（REST 予約 API の相関検証の抜け、既知差異 D-007） | `dep:org.springframework:spring-web#InitBinder` | [http-contract.md](../spec/http-contract.md) |
| ログイン時のユーザー名の `trim` | `dep:org.springframework.security:spring-security-web#UsernamePasswordAuthenticationFilter` | [authentication.md](../spec/authentication.md) |
| パスワードエンコーダ `{pbkdf2}` | `dep:org.springframework.security:spring-security-crypto#DelegatingPasswordEncoder` | [ADR 0015](../decision/0015-password-hashing-port.md) |
| REST の日付の JSON 表現（Spring 7 は Jackson 3 を優先して使う） | `dep:tools.jackson.core:jackson-databind#ObjectMapper` | [http-contract.md](../spec/http-contract.md#rest-apiapiv1) |
| `selectKey` による採番 | `dep:org.mybatis:mybatis#SelectKeyGenerator` | [ports.md#idgenerator](../spec/ports.md#idgenerator) |
| `@Transactional` | `dep:org.springframework:spring-tx#Transactional` | [ports.md#トランザクション](../spec/ports.md#トランザクション) |

> **TODO(spec):** 「追従中の上流」の依存の版を `trace/upstream.json` に記録する（道具の導入後はそちらを正とする。[backlog 0025](../backlog/0025-upstream-submodule-and-inventory.md)）。

## ATRS で採った値

| 項目 | 値 |
| --- | --- |
| テスト用パスワードハッシュ（参照実装） | `"{test}" ++ raw` |
| ロケータの省略記法（仕様文書中のみ） | `d/` = `atrs-domain/src/main/java/jp/co/ntt/atrs/domain/`、`w/` = `atrs-web/src/main/java/jp/co/ntt/atrs/`、`x/` = `atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/` |
| 文書の言語 | 日本語（識別子は英語。[documentation.md](documentation.md)） |

## 版上げの例（架空）

スキルの [upgrade.md](../../.agents/skills/port-lang/references/upgrade.md) を ATRS に当てはめた例。
Spring の版上げで `StringTrimmerEditor.setAsText` が `trim()` から `strip()` に変わった、と仮定する。

1. インベントリ差分: `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText` が「版の変化」になる。ATRS 本体のコードは不変。
2. 差分オラクル: 全角空白（U+3000）で始まる氏名を入力するベクタで、旧版は「全角カタカナでない」エラー、新版は合格になり、差分が出る。
3. 影響一覧: 入力検証の前処理（`SourceModel.Validation.trimInput`）→ ABS-046（入力検証のリファインメント）→ `Spec.Validation` が出る。
4. 判断: 業務の意図は変わらないので `Spec` は維持する。次の 3 つを行う。
   - `SourceModel` の前処理を直す。
   - 前提型の既知差異 `D-NNN`（Unicode 空白の扱い）を追加し、その述語 `dev_DNNN`「入力の前後に、U+0020 以下以外の Unicode 空白を含まない」を ABS-046 の仮定に加える。
   - W 課題 `ABS-1NN`（全角空白で始まる氏名で結果が異なる例）を証明する。
5. `Spec` を変えていないので、`Refinement`・`TargetModel`・Rust は影響を受けない。
