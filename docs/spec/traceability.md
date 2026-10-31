---
type: Specification
title: "追跡（トレーサビリティ）"
description: "ATRS の両端の追跡: 使うロケータ種別、運賃計算の追跡例と検査の判定、生成表、予定対応、対象外。方式はスキル port-lang に従う。"
tags: [spec, traceability]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:18:59+09:00
---

# 追跡（トレーサビリティ）

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

方針は [ADR 0035](../decision/0035-generate-verus-mirror-from-target-model.md)（構成）、[ADR 0036](../decision/0036-traceability-hash-as-deterministic-check-record.md)（追跡の方式）、[ADR 0024](../decision/0024-following-upstream-releases.md)（版上げ）。

```
移植元ソース  ⇔①⇔  SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel  ⇔②⇔  移植先ソース
(Java/SQL)                                                                         (Rust)
```

- 追跡は ①（移植元ソース ⇔ `SourceModel`）と ②（`TargetModel` ⇔ 移植先ソース）の **2 本だけ** である。
- 内側（`SourceModel` ↔ `Spec` ↔ `TargetModel`）は、追跡ではなく **証明** でつながる。証明は、B メソッドのリファインメントである `Abstraction`・`Refinement` である（[ADR 0034](../decision/0034-b-method-refinement-and-explicit-deviations.md)）。
- 追跡は対応を示すだけである。一致は、決定論的な検査で確かめる（[assurance.md](assurance.md)）。注釈のハッシュは、その検査が合格した版の記録である。
- 移植元ソースと移植先ソースを直接つないではならない。影響分析は証明グラフをたどって行う。

## 方式

ロケータの文法、版の宣言とインベントリ、注釈と検査済みハッシュ、検査（TR-S1〜TR-R。TR-D・TR-G・TR-N・TR-V・TR-PE を含む）、道具は、スキル port-lang の [traceability.md](../../.agents/skills/port-lang/references/traceability.md) に従う（[ADR 0036](../decision/0036-traceability-hash-as-deterministic-check-record.md)）。
ATRS が使うロケータの種別は次のとおり（文法は各言語パックの `locators.md`）。

| 側 | 種別 | 言語パック |
| --- | --- | --- |
| 移植元 | `java:` `prop:` `msg:` `http:` `xml:` `tmpl:` | [java/locators.md](../../.agents/skills/port-lang/references/java/locators.md) |
| 移植元 | `sql:` `ddl:` `seed:` | [sql/locators.md](../../.agents/skills/port-lang/references/sql/locators.md) |
| 移植先 | `rust:`（クレート `atrs`） | [rust/locators.md](../../.agents/skills/port-lang/references/rust/locators.md) |
| 両側 | `dep:` `lang:` | ATRS で必須の `dep:` は [atrs-porting.md](../rules/atrs-porting.md#source-に必ず含める依存atrs) |

道具は `tools/trace`（[backlog 0024](../backlog/0024-trace-tooling.md)）である。細部（本文ハッシュ・正規化・ロケータの形・版の文字列・警告と誤りの区別）は [ADR 0040](../decision/0040-trace-tooling-unresolved-details.md) による。

| ファイル | 内容 | 作り方 |
| --- | --- | --- |
| `trace/source-inventory.json` | 移植元のインベントリ（上流の submodule の走査結果） | `tools/trace inventory source` |
| `trace/target-inventory.json` | 移植先のインベントリ（`rust/src/` の走査結果と `/// trace: models` の札） | `tools/trace inventory target` |
| `trace/manifest.json` | ノード・型付きのリンク・合格した検査の記録 | `tools/trace manifest`（合格の記録は `tools/trace rehash`） |
| `trace/features.json` | 機能と backlog・ロケータ・Lean の名前空間・R 課題の対応表。TR-S1・TR-T1・TR-P・TR-PE・TR-D の警告と誤りを決める | 手で書く |
| `trace/checks.json` | `rehash` が実行する決定論的な検査と、それが覆う Lean の定義（名前の glob と、ベクタの `modelDef`） | 手で書く（検査を足す backlog が登録する） |
| `trace/renames.json` | ハッシュで判別できない改名の対応 | 手で書く（版上げのとき） |

道具の細部のうち `rehash`・`diff`・`impact`・`checks.json`・`renames.json`・「出典:」の検査は [ADR 0041](../decision/0041-rehash-diff-impact-details.md) による。

| 使い方 | コマンド |
| --- | --- |
| 注釈のハッシュの更新（検査を実行し、合格した組だけ更新して manifest に記録する） | `tools/trace rehash --dump <trace-dump.json>`（`--dry-run` で対象と検査を表示するだけ） |
| 新旧のインベントリの分類（版上げの手順 3） | `tools/trace diff --old git:<rev>`（`--side target` で移植先） |
| 証明のグラフに沿った影響一覧（版上げの手順 5） | `tools/trace impact --dump <trace-dump.json> --obligations <obligation-check.json> <ロケータ・Lean 名…>`（`--diff git:<rev>` で差分を起点にする） |

CI（`tools/ci/lean.sh`）は、インベントリ・manifest・下の生成区画が最新であることと、`tools/trace check` の誤りが 0 件であることを確かめる。

## 例: 運賃計算（基本運賃）

### 注釈

```lean
-- lean/SourceModel/Fare.lean
@[source "java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)@<h1>",
         "lang:java#JLS-15.17.1@java-17"]
def calculateBasicFare ... -- [Source]

-- lean/Abstraction/Fare.lean
@[deviation "D-001"]
def dev_D001 : Spec.Fare.BasicFareInput → Prop := ...   -- 前提型の差異（ABS-101 で確定）

@[obligation "ABS-001"]
theorem basicFare_refines :
  Machine.Refines (Spec.Fare.basicFareMachine.restrict dev_D001)
                  SourceModel.Fare.basicFareMachine
                  basicFareGlue

-- lean/Spec/Fare.lean
@[spec_doc "docs/spec/fare-calculation.md#基本運賃"]
def basicFare ... -- [Spec]

-- lean/Refinement/Fare.lean
@[obligation "REF-004"]
theorem basicFare_target_refines_spec :
  Machine.Refines Spec.Fare.basicFareMachine
                  TargetModel.Fare.basicFareMachine
                  basicFareGlue

-- lean/TargetModel/Fare.lean
@[target "rust:atrs::fare::basic_fare@<h3>", "lang:rust#integer-overflow@<rust の版>"]
def basicFare ... -- [Target]
```

```rust
// rust/src/model/fare.rs   （lake exe gen-verus の生成物。手で編集しない）
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
| TR-S1 | `calculateBasicFare` は `@[source]` で覆われる。private の `getMultiplicationRatio` はインベントリの単位ではなく、その本文は `<h1>` に含まれる（[ADR 0040](../decision/0040-trace-tooling-unresolved-details.md)）。同じクラスの他のメソッドは、別の `SourceModel` 定義が覆う必要がある |
| TR-S2 | `<h1>` が `source-inventory` の現在値と一致し、`<h1>` と定義の Merkle の組に合格の記録があれば合格。上流の版上げで本文が変わると失敗する。`tools/trace rehash` が、`trace/checks.json` で `SourceModel.Fare.calculateBasicFare` を覆う検査（`source-model/fare` のベクタの照合）を実行し、合格した場合に限ってハッシュを更新して記録する |
| TR-T1 | `TargetModel.Fare.basicFare` は `@[target]` を持つ。Rust の `atrs::fare::basic_fare` は覆われる。`atrs::model::fare::basic_fare`（写し）は TR-T2 で扱う |
| TR-T2 | `<h3>` が `target-inventory` と、`<m1>` が `TargetModel.Fare.basicFare` の Merkle ハッシュと一致すれば合格。Rust の本文を変えると `<h3>` がずれ、Lean を変えると `<m1>` がずれる |
| TR-P | `SourceModel.Fare.calculateBasicFare` は、R 課題 ABS-001 の具体機械 `SourceModel.Fare.basicFareMachine` の操作（定義が参照する定数の閉包）に含まれる。`TargetModel.Fare.basicFare` も同様に REF-004 の具体機械に含まれるので合格 |
| TR-D | D-001 の `Abstraction.Fare.dev_D001` が `@[deviation "D-001"]` を持ち、ABS-001 の型に現れ、W 課題 ABS-101 があれば合格 |
| TR-X | Lean の移植元側に `rust:` が無く、Rust と `TargetModel` に `java:` が無いので合格 |
| TR-R | 参照先がすべて存在すれば合格 |

影響分析の例: 上流で `calculateBasicFare` の本文が変わると、TR-S2 → `SourceModel.Fare.calculateBasicFare` → ABS-001 → `Spec.Fare.basicFare` の順に影響が出る。`Spec` を変えない判断なら、ここで止まる（`TargetModel`・Rust には影響しない）。

## 生成される表

以下の 2 本の表は `tools/trace manifest` が生成する。生成区画の中を手で編集してはならない。

### ① 移植元ソース ⇔ SourceModel

<!-- BEGIN GENERATED: source-trace -->
移植元ソース ⇔ SourceModel: インベントリ 1963 件（対象範囲 1323 件、対象外 640 件）、対応あり 9 件。`tools/trace manifest` が生成する（手で編集しない）。

| ロケータ | Lean の定義 | 本文ハッシュ | 合格した検査 |
| --- | --- | --- | --- |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateBasicFare(int,BoardingClassCd,LocalDate)` | `SourceModel.Fare.calculateBasicFare` | `9872678663e9a896` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateBasicFare(int,BoardingClassCd,LocalDate)` | `SourceModel.Fare.calculateBasicFare` | `5b0822fe4c6991ac` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedService#calculateFare(int,int)` | `SourceModel.Fare.calculateFare` | `8088a7f2c9efaf7e` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl#calculateFare(int,int)` | `SourceModel.Fare.calculateFare` | `1e12eb714e2bc395` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#calculateTotalFare(List,List)` | `SourceModel.Fare.calculateTotalFare` | `ca1a14757ce1cb33` | lake-test |
| `java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)` | `SourceModel.Fare.calculateTotalFare` | `35bc5d27ed5f2ca9` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.util.FareUtil#ceilFare(int)` | `SourceModel.Fare.ceilFare` | `345c1d9656b3930c` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.BoardingClassProvider#getBoardingClass(BoardingClassCd)` | `SourceModel.MasterData.getBoardingClass` | `363af6d3dd2e282d` | lake-test |
| `java:jp.co.ntt.atrs.domain.common.masterdata.PeakTimeProvider#getPeakTime(LocalDate)` | `SourceModel.MasterData.getPeakTime` | `1b19d6cad612b687` | lake-test |
<!-- END GENERATED: source-trace -->

### ② TargetModel ⇔ 移植先ソース

<!-- BEGIN GENERATED: target-trace -->
TargetModel ⇔ 移植先ソース: インベントリ 0 件（対象範囲 0 件、対象外 0 件）、対応あり 0 件。`tools/trace manifest` が生成する（手で編集しない）。

| ロケータ | Lean の定義 | 本文ハッシュ | 合格した検査 |
| --- | --- | --- | --- |
| （対応なし） | | | |
<!-- END GENERATED: target-trace -->

機能ごとの移植元の範囲（ロケータの glob）・Lean の名前空間・R 課題・backlog は [`trace/features.json`](../../trace/features.json) にある。道具ができる前の見取り図だった「初期の予定対応」の表は、これと生成表に置き換えて削除した。

## 対象外

`atrs-web/src/main/java/jp/co/ntt/atrs/app/common/logging/AccessLogFilter.java`、`atrs-env/**`、`atrs-selenium/**`、`atrs-web/src/main/webapp/**/*.html` の HTML 構造・静的資源（[ADR 0002](../decision/0002-porting-scope.md)）。一覧の正は [`trace/out-of-scope.json`](../../trace/out-of-scope.json) であり、各項目に ADR 0002 の該当節を書いている。

ただし、テンプレートのうち [Source] の観測可能な振る舞いに影響する式は、対象外にしない。たとえば支払期限の曜日の書式（`#temporals.format`。既知差異 D-019）がこれに当たる。これらは `tmpl:` ロケータで追跡する（[ADR 0036](../decision/0036-traceability-hash-as-deterministic-check-record.md)）。
