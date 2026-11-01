---
type: Architecture Decision Record
title: "lake test の分割をやめ、長い検査の段 long-tests を無くす"
description: "ADR 9c1c で lake test から実行ファイル long-tests（mise の lean:test-long）に分けた節を、すべて lake test に戻し、long-tests・lean:test-long・その範囲を無くす。シードの DB を使う SourceModel の照合と空席照会の SQL の結果は、遅い原因（SQL の写しの結合が直積の全件を作っていた）を証明付きの @[csimp] で除いて CI で 1 s 未満になり、残る暦日の全日と double の総当たりも CI で約 7 s で、どれも 20 秒の基準を下回るため。"
tags: [adr, ci, tests, verification]
id: "aaf84832-21a0-4260-bbd2-d77aa8744d86"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T00:30:00+09:00
---

# lake test の分割をやめ、長い検査の段 long-tests を無くす

## Context and Problem Statement

[ADR 9c1c](9c1c-check-tiers-and-change-scoped-long-checks.md) は、CI で 20 秒以上かかる節を `lake test` から実行ファイル `long-tests`（mise の `lean:test-long`。変更時の段）に分けた。
分けた節は、シードの DB を使う SourceModel の適合ベクタ（`shared/master-data`・`shared/flight-search`・`source-model/flight-search`）、空席照会の SQL の結果の照合、暦日の全日、double の総当たりである。
`long-tests` は CI で約 6 分かかり、9c1c は「照合そのものを速くすることは別の作業とする」としていた。

遅い原因を調べると、シードの DB の作り直しやインタプリタでの実行ではなかった。
- 適合ベクタのケースは小さな `flights` を持ち、`seedFlightDb` は閉じた項として起動時に 1 度だけ作られる。
- 原因は、SourceModel の SQL の写し（`FlightRepository.findAllFlightMaster`・`FlightRepository.vacantSeatRows`・`RouteRepository.findAll`）が、直積の全件を作ってから選んでいたことだった。`findAllFlightMaster` は 1 回で約 650 万組（便マスタ 126 × 区間 20 × 空港 51 × 空港 51）になる。
- 照合はケースごとに起動時の読み込み（`MasterQuery.standardOrder`・`load`）と空席照会の文を評価するので、そのたびにこれが走った。

条件を各段の直積に押し下げた結合（スキルの `Bag.crossWhere`）が元の定義と行の並びも含めて等しいことを定理にし、`@[csimp]` でコンパイル後のコードだけを差し替えた（[スキルの ADR b187](../../.agents/skills/spec-pivot/references/docs/decision/b187-proven-csimp-for-evaluating-models.md)）。
定義・`@[source]`・証明は変えず、テストは同じ関数を呼ぶ。検査の結果の行（検査とケースの数）は、差し替えの前と同じである。

| 節 | CI（前。run 41309054977） | CI（後。run 41314658541） | 手元（前） | 手元（後） |
| --- | --- | --- | --- | --- |
| `source-model/flight-search`（83 件） | 176 s | 0.15 s | 274 s | 0.33 s |
| 空席照会の SQL の結果（15 文とシードの照合） | 138 s | 0.71 s | 254 s | 1.3 s |
| `shared/master-data`（SourceModel） | 30 s | 0.04 s | 48 s | 0.07 s |
| `shared/flight-search`（SourceModel） | 15 s | 0.02 s | 26 s | 0.03 s |
| マスタの SQL の結果（`lake test` の既存の節） | — | 0.05 s | 3.5 s | 0.07 s |

手元は 4 コアの同じ環境での前と後である。この後、`long-tests` に残るのは暦日の全日と double の総当たりだけで、CI で約 7 s（手元で 20 s）だった。
どの節も 20 秒の基準（[checks.md](../rules/checks.md#長い段の基準と範囲)）を下回るので、変更時の段として分けておく理由が無い。

## Decision Drivers

* 20 秒未満の段は常時の段に入れる、という規約（[checks.md](../rules/checks.md#長い段の基準と範囲)）に従うこと
* どの変更でも、適合ベクタ・SQL の結果・暦日の全日・double の総当たりのすべてを確かめること（範囲の宣言の漏れで飛ばされる余地を無くす）
* 実行ファイル・タスク・範囲・layout-check の組を減らし、設定を単純にすること

## Considered Options

* すべての節を `lake test` に戻し、`long-tests` の段を無くす
* シードの DB を使う節だけを戻し、暦日の全日と double の総当たりは `long-tests` に残す

## Decision Outcome

Chosen option: "すべての節を `lake test` に戻し、`long-tests` の段を無くす", because 残る 2 つの節も CI で約 7 s で基準を下回り、段を残すと、範囲の宣言と実行ファイルと layout-check の組を保守し続けることになるため。

### 構成

* `lean/Tests/Main.lean`（`lake test`）が、暦日の全日（`Tests.DateExhaustive`）と double の総当たり（`Tests.JavaDouble`）を含む、すべての節を実行する。`Tests` が両方のモジュールを import する。
* 削除したもの: `lean/Tests/Long.lean`・`lean/Tests/LongMain.lean`、`lean/lakefile.lean` の `lean_exe «long-tests»`、mise の `lean:test-long`（`ci` の depends と `workspace:setup-file` の `wait_for` からも除く）、`tools/ci/check-scopes.toml` の `[scopes."lean:test-long"]`、`trace/checks.json` の各検査の `lean:test-long` の段。
* `lake exe layout-check` の組から `Tests.Long` と `Tests.LongMain` を除き、5 組にした（[スキルの ADR 89f2](../../.agents/skills/spec-pivot/references/docs/decision/89f2-layout-check-one-process-per-group.md) の組ごとのプロセスはそのまま）。
* ADR 9c1c の、層・範囲・選択・CI の起動の決定は変えない。変わるのは、変更時の段から `lean:test-long` が無くなることだけである。

### Consequences

* Good, because `lake test` がすべての Lean のテストを実行し、どの変更でも全件を確かめる。
* Good, because 実行ファイル・タスク・範囲・layout-check の組が 1 つずつ減る。
* Bad, because `lake test` は暦日の全日と double の総当たりの分（CI で約 7 s）だけ長くなる。
* Bad, because 暦日の全日と double の総当たりは、閉じた項としてモジュールの初期化で評価されるため、節の `time` は 0 ms と表示される。時間は実行全体で見る。

### Confirmation

* `lake test` の結果の行（検査とケースの数）が、前の `lake test` と `long-tests` を合わせたものと同じである。
* `static:check-scopes` が通る（`ci` の depends と範囲の整合）。
* PR の CI と `mise run ci`（全数）が通る。

## Pros and Cons of the Options

### シードの DB を使う節だけを戻し、暦日の全日と double の総当たりは残す

* Good, because `lake test` が約 7 s 短い。
* Bad, because 基準を下回る段を変更時の段に残すことになり、規約に合わない。範囲の宣言の漏れがあれば、その分だけ PR で飛ばされうる。

## More Information

* 補う記録: [ADR 9c1c](9c1c-check-tiers-and-change-scoped-long-checks.md)（検査の層。`lake test` の分割はこの ADR で廃止）、[スキルの ADR b187](../../.agents/skills/spec-pivot/references/docs/decision/b187-proven-csimp-for-evaluating-models.md)（評価を速くする実装を、証明付きの `@[csimp]` で与える）
* 規則: [checks.md](../rules/checks.md)
