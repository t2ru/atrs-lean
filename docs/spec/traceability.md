---
type: Specification
title: "追跡（トレーサビリティ）"
description: "移植元ソース⇔SourceModel と TargetModel⇔移植先ソースの 2 本の追跡について、ロケータ文法・注釈・検査・生成表と、運賃計算の追跡例。"
tags: [spec, traceability]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 追跡（トレーサビリティ）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

方針は [ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)（構成）、[ADR 0023](../decision/0023-cross-language-traceability.md)（追跡の方式）、[ADR 0024](../decision/0024-following-upstream-releases.md)（版上げ）。

```
移植元ソース  ⇔①⇔  SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel  ⇔②⇔  移植先ソース
(Java/SQL)                                                                         (Rust)
```

- 追跡は ①（移植元ソース ⇔ `SourceModel`）と ②（`TargetModel` ⇔ 移植先ソース）の **2 本だけ** である。
- 内側（`SourceModel` ↔ `Spec` ↔ `TargetModel`）は追跡ではなく **証明**（`Abstraction`, `Refinement`）でつながる。
- 移植元ソースと移植先ソースを直接つないではならない。影響分析は証明グラフをたどって行う。

## ロケータ

ソースの位置は、版に依存しない記号的なロケータで指す。行番号は道具が版ごとに解決し、permalink を生成する。

```
locator   = kind ":" body
kind      = "java" | "sql" | "ddl" | "prop" | "msg" | "http" | "rust" | "dep" | "lang"
```

| kind | 側 | body の形式 | 例 |
| --- | --- | --- | --- |
| `java` | 移植元 | `<FQCN>#<メソッド名>(<引数の単純型名,…>)`。コンストラクタは `<init>`、フィールドは `<FQCN>.<名前>` | `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)` |
| `sql` | 移植元 | `<Mapper の namespace>#<文の id>` | `sql:jp.co.ntt.atrs.domain.repository.flight.FlightRepository#findByVacantSeatSearchCriteria` |
| `ddl` | 移植元 | `<ファイル名>#<オブジェクト名>` | `ddl:00100_create_all_tables.sql#SQ_MEMBER_1` |
| `prop` | 移植元 | `<ファイル名>#<キー>` | `prop:atrs.properties#atrs.limitDay` |
| `msg` | 移植元 | `<ファイル名>#<キー>` | `msg:atrs-messages_ja.properties#e.ar.b2.2009` |
| `http` | 移植元 | `<METHOD> <パス>[?<判別パラメータ>]` | `http:POST /ticket/reserve?confirm` |
| `rust` | 移植先 | `<crate>::<パス>` | `rust:atrs::fare::basic_fare`, `rust:atrs::model::fare::basic_fare` |
| `dep` | 両側 | `<座標>#<シンボル>`。座標は Maven の `groupId:artifactId` または crate 名 | `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText`, `dep:serde_json#from_str` |
| `lang` | 両側 | `<言語>#<節>` | `lang:java#JLS-5.1.3`, `lang:postgresql#ORDER-BY`, `lang:rust#integer-overflow` |

- 引数型は単純型名で書く（パッケージを省く）。同名の型が衝突する場合だけ完全名にする。
- `dep`・`lang` が移植元側か移植先側かは、それを参照するモデルの側で決まる。移植元側のモデルが移植先の `dep`（crate）を参照してはならない。逆も同じ。

## 版の宣言とインベントリ

| ファイル | 内容 |
| --- | --- |
| `trace/upstream.json` | 追従中の上流: repo, variant（`JavaConfig-Thymeleaf`）, release, commit, 依存の版（`pom.xml` から）, Java の版, PostgreSQL の版 |
| `trace/target.json` | 移植先: Rust ツールチェーン, Verus, Kani, 依存クレートの版 |
| `trace/source-inventory.json` | 上流（submodule `upstream/atrs`）を走査した、ロケータ・ファイル・行範囲・正規化した本文ハッシュ |
| `trace/target-inventory.json` | `rust/` を走査した、同じ形式の一覧 |
| `trace/manifest.json` | 全ノードと型付きのリンク（生成） |
| `trace/renames.json` | 版上げ時の、本文ハッシュで判別できない改名の対応（手書き） |
| `trace/out-of-scope.json` | 追跡の対象外とするロケータと理由（手書き。[ADR 0002](../decision/0002-porting-scope.md) に基づく） |

`dep`・`lang` の項目は、本文ハッシュの代わりに版文字列（例 `spring-beans@6.2.1`）を持つ。

## 注釈

リンクの正は Lean のモデル側の属性である（Rust の写しのタグだけは Rust 側）。

| 置き場所 | 注釈 | リンク |
| --- | --- | --- |
| `SourceModel`, `LangSemantics.Java/Sql` | `@[source "<ロケータ>@<ハッシュ>", …]` | ① |
| `TargetModel`, `LangSemantics.Rust` | `@[target "<ロケータ>@<ハッシュ>", …]` | ② |
| Rust `model/` | `/// trace: models <TargetModel の完全名> @<Merkle ハッシュ>` | ②（逆向きの確認） |
| `Abstraction`, `Refinement` | `@[obligation "ABS-NNN" / "REF-NNN"]`。モデル間の対応は定理の型から自動導出 | 内側（証明） |
| `Spec` | `@[spec_doc "<docs/spec のパス#アンカー>"]`、`@[no_source "<理由>"]` | 文書 |
| ベクタ | `modelDef`, `upstream`（[conformance.md](conformance.md)） | テスト |

## 検査

| ID | 失敗条件 |
| --- | --- |
| TR-S1 | スコープ内の `source-inventory` の項目が `@[source]` で覆われず、`out-of-scope.json` にも無い |
| TR-S2 | `@[source]` のハッシュが `source-inventory` と一致しない |
| TR-T1 | `TargetModel` の公開定義に `@[target]` が無い。または `target-inventory` の公開項目が `@[target]` で覆われず、`out-of-scope.json` にも無い |
| TR-T2 | `@[target]` のハッシュが `target-inventory` と、`/// trace: models` のハッシュが Lean の Merkle ハッシュと一致しない |
| TR-P | `SourceModel` の公開定義に `Abstraction` 定理が、`TargetModel` の公開定義に `Refinement` 定理が無い（理由付きの例外を除く） |
| TR-X | 移植元側の層に移植先ロケータが、移植先側の層・`rust/` に移植元ロケータがある |
| TR-R | 存在しない Lean 名・ロケータ・課題 ID への参照がある |

段階導入: Lean・Rust のコードがそろうまで TR-S1・TR-T1・TR-P は警告とする（[ADR 0023](../decision/0023-cross-language-traceability.md)）。

## 例: 運賃計算（基本運賃）

### 注釈

```lean
-- lean/SourceModel/Fare.lean
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@<h1>",
         "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#getMultiplicationRatio(LocalDate)@<h2>",
         "lang:java#JLS-15.17.1@java-21"]
def calculateBasicFare ... -- [Source]

-- lean/Abstraction/Fare.lean
@[obligation "ABS-001"]
theorem basicFare_source_eq_spec ... :
  α (SourceModel.Fare.calculateBasicFare ...) = Spec.Fare.basicFare ...

-- lean/Spec/Fare.lean
@[spec_doc "docs/spec/fare-calculation.md#基本運賃"]
def basicFare ... -- [Spec]

-- lean/Refinement/Fare.lean
@[obligation "REF-004"]
theorem basicFare_target_refines_spec ... :
  β (TargetModel.Fare.basicFare ...) = Spec.Fare.basicFare ...

-- lean/TargetModel/Fare.lean
@[target "rust:atrs::fare::basic_fare@<h3>", "lang:rust#integer-overflow@<rust の版>"]
def basicFare ... -- [Target]
```

```rust
// rust/src/model/fare.rs
/// trace: models TargetModel.Fare.basicFare @<m1>
pub open spec fn basic_fare(...) -> int { ... }

// rust/src/fare.rs   （移植元ロケータは書かない）
pub fn basic_fare(...) -> (r: u64)
    ensures r == model::fare::basic_fare(...)
{ ... }
```

### 検査の判定

| 検査 | この例での判定 |
| --- | --- |
| TR-S1 | `calculateBasicFare`・`getMultiplicationRatio` は `@[source]` で覆われる。同じクラスの他のメソッドは、別の `SourceModel` 定義が覆う必要がある |
| TR-S2 | `<h1>`・`<h2>` が `source-inventory` の現在値と一致すれば合格。上流の版上げで本文が変わると失敗し、見直しを求める |
| TR-T1 | `TargetModel.Fare.basicFare` は `@[target]` を持つ。Rust の `atrs::fare::basic_fare` は覆われる。`atrs::model::fare::basic_fare`（写し）は TR-T2 で扱う |
| TR-T2 | `<h3>` が `target-inventory` と、`<m1>` が `TargetModel.Fare.basicFare` の Merkle ハッシュと一致すれば合格。Rust の本文を変えると `<h3>` がずれ、Lean を変えると `<m1>` がずれる |
| TR-P | `SourceModel.Fare.calculateBasicFare` は ABS-001 の型に、`TargetModel.Fare.basicFare` は REF-004 の型に現れるので合格 |
| TR-X | Lean の移植元側に `rust:` が無く、Rust と `TargetModel` に `java:` が無いので合格 |
| TR-R | 参照先がすべて存在すれば合格 |

影響分析の例: 上流で `calculateBasicFare` の本文が変わると、TR-S2 → `SourceModel.Fare.calculateBasicFare` → ABS-001 → `Spec.Fare.basicFare` の順に影響が出る。`Spec` を変えない判断なら、ここで止まる（`TargetModel`・Rust には影響しない）。

## 生成される表

以下の 2 本の表は `tools/trace manifest` が生成する。生成区画の中を手で編集してはならない。

### ① 移植元ソース ⇔ SourceModel

<!-- BEGIN GENERATED: source-trace -->
（未生成。[backlog 0024](../backlog/0024-trace-tooling.md) で生成する）
<!-- END GENERATED: source-trace -->

### ② TargetModel ⇔ 移植先ソース

<!-- BEGIN GENERATED: target-trace -->
（未生成。[backlog 0024](../backlog/0024-trace-tooling.md) で生成する）
<!-- END GENERATED: target-trace -->

## 初期の予定対応（参考・非規範）

道具ができるまでの見取り図である。生成表ができたら削除する。
原典パスは `JavaConfig-Thymeleaf/atrs/` からの相対で、`d/` = `atrs-domain/src/main/java/jp/co/ntt/atrs/domain/`、`w/` = `atrs-web/src/main/java/jp/co/ntt/atrs/`、`x/` = `atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/` の省略である。

| 原典 | 仕様の草案 | SourceModel（予定） |
| --- | --- | --- |
| `d/common/util/FareUtil.java`, `d/service/b0/TicketSharedServiceImpl.java`（運賃） | [fare-calculation.md](fare-calculation.md) | `SourceModel.Fare` |
| `d/common/util/FareTypeUtil.java`, `d/model/*.java` | [domain-model.md](domain-model.md) | `SourceModel.Model` |
| `d/common/util/DateTimeUtil.java` | [domain-model.md#書式](domain-model.md#書式) | `SourceModel.Format` |
| `d/common/validate/*.java`, `w/app/**/*Validator.java`, `w/app/**/*Form.java`, `w/app/common/binding/GlobalBindingInitializer.java` | [input-validation.md](input-validation.md) | `SourceModel.Validation` |
| `d/common/masterdata/*Provider.java`, `d/common/codelist/AirportCodeList.java` | [master-data.md](master-data.md) | `SourceModel.MasterData`, `SourceModel.CodeList` |
| `d/common/exception/*`, `d/service/*/*ErrorCode.java`, `atrs-web/src/main/resources/i18n/*.properties` | [errors-and-messages.md](errors-and-messages.md) | `SourceModel.Error`, `SourceModel.Message` |
| `d/service/b0/TicketSharedServiceImpl.java`（フライト検証）, `d/service/b1/*` | [flight-search.md](flight-search.md), [reservation.md#validateflightlist](reservation.md#validateflightlist) | `SourceModel.FlightSearch`, `SourceModel.Ticket` |
| `d/service/b2/TicketReserveServiceImpl.java`, `w/app/b2/TicketReserveHelper.java` | [reservation.md](reservation.md) | `SourceModel.UseCase.Reserve` |
| `d/service/a0/*`, `d/service/c1/*`, `d/service/c2/*`, `w/app/c0/*` | [member.md](member.md) | `SourceModel.UseCase.Member` |
| `d/service/a1/*`, `d/service/a2/*`, `d/common/security/*`, `w/app/common/security/*` | [authentication.md](authentication.md) | `SourceModel.UseCase.Auth` |
| `d/service/d1/*`, `d/repository/reservation/ReservationHistoryDto.java`, `w/listener/d1/*` | [reservation-history-report.md](reservation-history-report.md) | `SourceModel.UseCase.Report` |
| `x/**/*.xml`（Mapper の全 SQL 文）, `atrs-initdb/src/sqls/integration-test-postgres/00100_create_all_tables.sql` | [ports.md](ports.md) | `SourceModel.Repository.*`（`LangSemantics.Sql` の式） |
| `w/app/**/*Controller.java`, `w/api/**/*.java`, `w/config/web/*.java`, `atrs-web/src/main/webapp/WEB-INF/web.xml` | [http-contract.md](http-contract.md) | `SourceModel.Http` |
| `atrs-domain/src/main/resources/META-INF/spring/atrs.properties` | [configuration.md](configuration.md) | `SourceModel.Config` |

`TargetModel` 側の予定対応は、Lean `TargetModel` の着手時（[backlog 0022](../backlog/0022-target-model-fare-and-refinement.md)）に、下位名前空間を `SourceModel` と同じ機能名でそろえて決める。

## 対象外

`w/app/common/logging/AccessLogFilter.java`、`atrs-env/**`、`atrs-selenium/**`、`atrs-web/src/main/webapp/**/*.html` の HTML 構造・静的資源（[ADR 0002](../decision/0002-porting-scope.md)）。道具の導入時に `trace/out-of-scope.json` へ移す。
