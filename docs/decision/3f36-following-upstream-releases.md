---
type: Architecture Decision Record
title: "移植元の版上げに追従する。SourceModel は最新版のみ保持し、差分オラクルで振る舞いの変化を検出する"
description: "上流を submodule で固定し、版上げ時はインベントリ差分と新旧 2 版の差分オラクルで影響を洗い出し、証明グラフに沿って各層を更新する。旧版は git タグで参照する。"
tags: [adr, upstream, versioning, traceability]
id: "3f36f0b6-9a74-46a9-a75a-66fd601b538d"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 移植元の版上げに追従する。SourceModel は最新版のみ保持し、差分オラクルで振る舞いの変化を検出する

## Context and Problem Statement

移植元（TERASOLUNA ATRS）は今後も版が上がる（現在は `release/5.11.0.RELEASE`）。
版上げは振る舞いに 3 種類の変化をもたらしうる。

* ATRS 本体のコード（Java・SQL・設定・メッセージ）の変化
* 依存フレームワーク（Spring・Hibernate Validator・Jackson・MyBatis）の挙動の変化。例: 空白除去が `trim()` から `strip()` に変わる
* 処理系（Java・PostgreSQL）の版の変化

これらを見落とさず、移植元モデルから移植先ソースまでを追従させる方式を決める。
プロジェクトオーナーは `SourceModel` を最新版だけ保持する方針を選んだ。

## Decision Drivers

* コード差分に現れない振る舞いの変化（依存の挙動）も検出すること
* 変化を `Spec` に反映するか（追従）、既知差異として残すかを、明示的に判断させること
* モデルと証明の量を版の数に比例させないこと

## Considered Options

* `SourceModel` は最新版のみ。版上げ時にインベントリ差分と差分オラクルを取り、証明グラフに沿って更新する。旧版は git タグ
* `SourceModel` を版ごとに並存させる（`SourceModel.V5_11` 等）
* 版上げのたびに、手作業で差分を読んで判断する

## Decision Outcome

Chosen option: "最新版のみ ＋ インベントリ差分 ＋ 差分オラクル ＋ git タグ", because 構造を単純に保ちつつ、コードと振る舞いの両面から変化を機械的に洗い出せるため。

* 上流は `upstream/atrs` に **git submodule** として取り込み、commit を固定する。追従中の版は `trace/upstream.json` に 1 か所で宣言する（[ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md)）。
* 依存フレームワーク・処理系の挙動に依存する `SourceModel`・`LangSemantics.Java/Sql` の定義は、`dep:`・`lang:` ロケータを **必ず** `@[source]` に含める。依存の版が変わると、影響する定義が自動で出る。
* **差分オラクル**: Java オラクルハーネス（[backlog f18c](../backlog/f18c-java-oracle-harness.md)）を拡張し、`conformance/source-model/` の全ベクタ入力を旧版と新版の両方で実行して出力を比べる（[backlog 773f](../backlog/773f-differential-oracle.md)）。
* 手順は [spec-pivot/upgrade.md](../../.agents/skills/spec-pivot/references/docs/guide/upgrade.md) に定める。要点は次のとおり。
  1. 版上げの ADR を作る。
  2. submodule を上げる。
  3. インベントリ差分を取る（不変・本文変更・追加・削除・移動/改名）。
  4. 差分オラクルを実行する。
  5. 影響一覧を生成する。
  6. 層ごとに判断する。振る舞いが不変ならハッシュの更新だけ。変化したら `SourceModel` を修正し、`Spec` が追従するか（ADR）、既知差異 `D-NNN` として残すかを決める。
  7. ベクタを再生成する。
  8. 検査が通ったら commit し、旧版を `upstream-<旧 release>` タグにする。
* `Spec` は業務の意図が変わるときだけ変える。移植元の挙動変化をそのまま `Spec` に流してはならない。
* 移植先側の版上げ（Rust ツールチェーン・Verus・Kani・クレート）も同じ仕組みで扱う。`trace/target.json` と `dep:`/`lang:` のずれから、`LangSemantics.Rust`・`TargetModel` の再確認と Verus/Kani の再実行を求める。

### Consequences

* Good, because 依存フレームワークの挙動変化のようなコード差分に出ない変化も、差分オラクルで検出できる
* Good, because 版上げの判断（追従するか、差異として残すか）が ADR と既知差異として記録される
* Bad, because 差分オラクルのために、新旧 2 版の Java 実行環境を一時的に用意する必要がある
* Bad, because 旧版の `SourceModel` は git の履歴でしか参照できず、旧版との関係は証明の対象にならない

### Confirmation

* 版上げのコミットに、版上げ ADR・更新された `trace/upstream.json`・影響一覧・差分オラクルの結果が含まれていることをレビューで確認する。
* 版上げ後に TR 検査（[ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md)）がすべて通る。

## Pros and Cons of the Options

### 最新版のみ ＋ 差分

* Good, because 単純で、変化を機械的に洗い出せる
* Bad, because 旧版との互換性を証明できない

### 版ごとに並存

* Good, because 旧版との関係も証明できる
* Bad, because モデルと証明が版の数だけ増える

### 手作業

* Good, because 道具が不要
* Bad, because 見落としが避けられず、依存の挙動変化はほぼ検出できない

## More Information

* [spec-pivot/upgrade.md](../../.agents/skills/spec-pivot/references/docs/guide/upgrade.md)
* [backlog 455f](../backlog/455f-upstream-submodule-and-inventory.md), [backlog 773f](../backlog/773f-differential-oracle.md)
* （補足 2026-10-30）差分オラクルが比べるのはベクタの入力だけであり、その外での振る舞いの変化は検出できない。これは保証の限界として [spec/assurance.md](../spec/assurance.md) に記載する。`@[source]` のハッシュの更新は、[ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) の `tools/trace rehash` が、決定論的な検査が合格したときに限って行う。
