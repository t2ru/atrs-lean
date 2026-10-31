---
type: Architecture Decision Record
title: "運賃計算の SourceModel の表し方（マスタのキャッシュ・列挙型・HashMap）と、共有ベクタの modelDef・共有入力を決める"
description: "運賃計算の SourceModel で、マスタを Provider のキャッシュとして入力に受けること、Java の列挙型に Spec の型を使うこと、HashMap の最小のモデルを決める。共有ベクタの modelDef をモデルごとの配列にできること、共有入力 fixtures を上流のシードから生成すること、source-model の期待値を仕様の例の表から取ること、翌日着の便の暫定の扱いを決める。"
tags: [adr, source-model, conformance, fare]
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:16:47+09:00
---

# 運賃計算の SourceModel の表し方（マスタのキャッシュ・列挙型・HashMap）と、共有ベクタの modelDef・共有入力を決める

## Context and Problem Statement

[backlog 0004](../backlog/0004-fare-calculation-both-models.md) の第 1 段では、次の 2 つを作る。

* 運賃計算の `Spec.Fare` と `SourceModel.Fare`
* 両モデルで実行する適合テストベクタ

そのために、次の点を決める必要があった。

* マスタの表し方。原典は、マスタを Provider（`@PostConstruct load()`）が起動時に読んでキャッシュし、`calculateBasicFare` などはキャッシュを引く。
* 原典の列挙型（`BoardingClassCd`・`FareTypeCd`）と `HashMap` の写し方
* `shared/` のベクタ（複数のモデルで同じ期待値）の `modelDef`。今の形式は 1 つの名前しか持てない。
* ベクタのマスタ・設定の入力（`fixtures`）の作り方
* `source-model/` の期待値の出所。Java のオラクル（[backlog 0013](../backlog/0013-java-oracle-harness.md)）はまだ無い。
* 上流のシードの便マスタにある、到着時刻 `2415`（翌日 0:15）の 2 行。`Spec` の時刻（0:00〜23:59）では表せない。

## Decision Drivers

* [abstraction.md](../spec/abstraction.md) の方針（マスタは不変なので、状態に含めず入力とする）を保つこと
* `obligation-check` の G4（`SourceModel` は `Spec` の関数を参照しない。型・構築子・射影は参照してよい）を満たすこと
* 同じ例を、モデルごとに別のファイルへ重複して書かないこと
* fixture の転記の誤りを、機械で防ぐこと

## Considered Options

* 下表のとおり決める
* マスタを `SourceModel` の状態（`Concrete` の状態）として持つ
* `shared/` を使わず、`spec/` と `source-model/` に同じケースを重複して書く

## Decision Outcome

Chosen option: "下表のとおり決める", because 方針（マスタは入力）と G4 を満たし、例を 1 か所に書けて、fixture を上流から決定論的に作れるため。

| 項目 | 決定 |
| --- | --- |
| マスタの表し方 | [Source] のマスタは、Provider のキャッシュ（`BoardingClassProvider.boardingClassCodeMap`・`PeakTimeProvider.peakTimeList`）を、操作の入力の成分として受ける。キャッシュを SQL から作る `load` と、運賃計算が使わない Provider は、0004 の第 2 段で写す |
| 列挙型 | 原典の enum（`BoardingClassCd`・`FareTypeCd`・`Gender`）は、構築子が 1 対 1 なので `Spec.Model` の型をそのまま使う（α は恒等）。値の型は `LangSemantics.Java` の型で写す（`Integer` → `JRef J32`、`LocalDate` → `JRef JLocalDate`、参照 → `JRef`） |
| `HashMap` | `LangSemantics.Java.JHashMap` を足す。範囲は `put`（後勝ちの置き換え）・`get`（無ければ null）・`containsKey`・`size` に限る。キーの等しさは `DecidableEq` で、enum・String の `equals` に一致する。反復の順序は与えない |
| 共有ベクタの `modelDef` | `shared/` のベクタでは、`modelDef` を、モデルごとの名前の配列にしてよい（例 `["Spec.Fare.fare", "SourceModel.Fare.calculateFare"]`）。実行器は、実行するモデルの層の名前を選ぶ。TR-R と `trace/checks.json` の `vectors` は、配列の各要素を扱う |
| 共有入力 | `conformance/fixtures/master-data.json`・`config.json` を、生成器 `tools/conformance/master_fixture.py` が上流のシードの SQL と `atrs.properties` から書き出す。<br>- 投入日は 2026-11-01、ピーク時期は 2026・2027 年（ADR 0028）。<br>- 行の順はシードの順。[Source] のキャッシュは、この順に `put`・`add` して作る。<br>- CI は `--check` で最新であることを確かめる |
| `source-model/` の期待値 | Java のオラクル（0013）ができるまでは、仕様の例の表の [Source] の値を使う（`source: "lean-source-model"`、`upstream` を必須とする）。double の式は、`Tests.JavaDouble`（ネイティブの double）と JVM の表で突き合わせ済みである。0013 で `java-oracle` の値に置き換える |
| 翌日着の便（暫定） | 到着時刻 `2415` の 2 行（NTT523・NTT528）は、fixture に上流どおり残し、`outsideSpec` を付ける。`Spec` 用の読み込みは、その行を除く。`SourceModel` 用の読み込みは除かない。<br>- [Spec] で翌日着を表せるように改め、[Source] の `DateTimeParseException` を既知差異として登録するのは [backlog 0006](../backlog/0006-flight-search-usecase.md) である（プロジェクトオーナーの決定）。<br>- 運賃の計算は到着時刻を使わないので、0004 には影響しない |

### Consequences

* Good, because 例を `shared/` に 1 度だけ書き、`Spec` と `SourceModel` の両方で実行できる
* Good, because fixture が上流のシードから決定論的に生成され、版上げで差分が見える
* Good, because `SourceModel` が `Spec` の関数に依存せず、G4 を満たす
* Bad, because `source-model/` の期待値は、0013 までは原典の実行で確かめたものではない（[assurance.md](../spec/assurance.md) に記載する）
* Bad, because 翌日着の 2 行は、0006 まで `Spec` のマスタに入らない

### Confirmation

* `lake test` で、`spec/fare`・`shared/fare` を `Spec` で、`source-model/fare`・`shared/fare` を `SourceModel` で実行し、すべて合格する。
* 1430 円・30% の例で、`Spec` は 1100、`SourceModel` は 1000 になる。定理 `Spec.Fare.fare_1430_30`・`SourceModel.Fare.calculateFare_1430_30` で確かめる。
* `tools/ci/lean.sh` が `master_fixture.py --check` を実行する。

## More Information

* [ADR 0013](0013-conformance-test-vectors.md)、[ADR 0028](0028-clock-timezone-and-fixture-base-date.md)、[ADR 0036](0036-traceability-hash-as-deterministic-check-record.md)、[ADR 0039](0039-refinement-non-vacuity-obligations.md)
* [backlog 0004](../backlog/0004-fare-calculation-both-models.md)、[backlog 0006](../backlog/0006-flight-search-usecase.md)、[backlog 0013](../backlog/0013-java-oracle-harness.md)
