---
type: Architecture Decision Record
title: "Spec とモデルのギャップの登録簿を Lean の属性に置き、文書の表を生成する"
description: "既知差異（前提型・観測型・モデル外）、Spec の PRE の外での振る舞い、未確定の差異を、ID ごとの Lean の宣言（@[gap_entry]、型 Trace.Gap）として登録し、これを正とする。差異の生じる Spec・SourceModel・TargetModel の定義に箇所の印 @[gap] を付ける。文書の表は trace-dump から生成し、検査は Markdown の解析をやめて JSON から行う。"
tags: [adr, lean, traceability, abstraction, refinement]
id: "cc2483fe-868c-4030-a891-5a674e631733"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T16:30:00+09:00
---

# Spec とモデルのギャップの登録簿を Lean の属性に置き、文書の表を生成する

## Context and Problem Statement

基本原則 3 は、抽象モデルと移植元・移植先のモデルの不一致を、証明の中と文書の両方ですべて明示することを求める（[ADR c336](c336-foundational-principles.md)）。
[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) は、差異を `D-NNN`・`T-NNN` として登録し、前提型・観測型の差異を `@[deviation]` 付きの述語・成分として定理に置くと決めた。

ただし、この変更の前は、登録簿の正が `docs/spec/abstraction.md` の 4 つの表であった。

| 表 | 内容 |
| --- | --- |
| 既知差異 | 前提型・観測型・モデル外の差異 |
| 前提型の差異の影響 | 前提型の差異ごとの「出力のみ」「中断」 |
| PRE の外の振る舞い | [Spec] の前提の外での [Source] の振る舞い（差異ではない） |
| 未確定の差異 | 種類を確かめる作業が残っている違い |

この形には、次の問題があった。

* Python の `check_obligations.py` と Rust の `tools/trace` が、どちらも Markdown の表を独自に解析していた。表の書式が変わると、検査が黙って行を落としうる。
* Lean に現れていたのは、前提型・観測型のうち、すでに述語・成分を書いたもの（D-027）だけだった。モデル外・PRE の外・未確定のギャップは、機械では扱えなかった。
* ギャップが **どの定義で** 生じるかは、文書の「箇所」の列（仕様文書の節）にしか無かった。上流の版上げで `SourceModel` の定義が変わっても、見直すべきギャップを道具では出せなかった。
* PRE の外の表には、ID の無い行が 2 つあり、参照できなかった。

## Decision Drivers

* 原則 1: 一致は決定論的な検査で確かめる。Markdown を人と道具の両方の正にしない
* 原則 3: 不一致は、証明の中と文書の両方にすべて明示する
* 上流の版上げへの追従（[ADR 3f36](3f36-following-upstream-releases.md)）で、見直すギャップを影響分析から出せる
* 登録の誤り（種類と欄の矛盾）を、書いた時点で検出する

## Considered Options

* **Lean を正とし、文書の表を生成する**: ID ごとの宣言に構造化した値と説明を置き、表は道具が書く
* **Lean は構造だけを持ち、説明は文書に残して照合する**: ID・種類・関係を Lean に置き、文書の表と突き合わせる
* **現状のまま**: Markdown の表を正とし、解析を続ける

## Decision Outcome

採択: **Lean を正とし、文書の表を生成する**。対象は 4 種類すべて（前提型・観測型・モデル外・PRE の外・未確定）とする。照合案は、同じ情報を 2 か所に書き続けることになるので採らない。

### 登録の宣言（`@[gap_entry]`）

* ギャップごとに、型 `Trace.Gap` の定数を 1 つ置き、`@[gap_entry]` を付ける。`D-NNN` は `Abstraction.Gap`（`lean/Abstraction/Gap.lean`）、`T-NNN` は `Refinement.Gap`（`lean/Refinement/Gap.lean`）に置く。
* 値の欄は次のとおりである。
  * 種類（`pre`・`preConcreteInput`・`preConcreteState`・`preConcreteEnv`・`observational`・`outOfModel`・`outsidePre`・`undetermined`）
  * 箇所（文書の節。1 つ以上）
  * 前提・成分・理由（種類ごとの本文）
  * R 課題・W 課題
  * 前提型の影響と理由
  * 確定させる作業（未確定だけ）
  * Lean 側を完了させる backlog
* 説明（表の「差異」「振る舞い」「状況」の列）は docstring に書く。
* `@[gap_entry]` は、付けた時点で値を読み、種類ごとの必須の欄と書かない欄を検査する。
* 値は評価せずに式から読む（定義の展開だけで構築子と文字列リテラルになる式に限る）。

### 箇所の印（`@[gap]`）

* ギャップの生じる定義に `@[gap "D-NNN"]` を付ける。対象は、`Spec` と `SourceModel`（`T-NNN` なら `TargetModel`）の定義である。
* 前提型・観測型・PRE の外のギャップには、両側の印が必要である（TR-K）。モデル外のギャップは、どのモデルにも現れないので、印も `@[deviation]` も持たない。
* 印は `merkle` に含まれないので、付けても `@[source]` の再検査は要らない。
* `tools/trace impact` は、影響を受ける定義に印のあるギャップを「見直すギャップ」として出す。

### 文書と検査

* `docs/spec/abstraction.md` の 4 つの表と、`refinement.md` の 2 つの表は、`tools/trace manifest` が `trace-dump` の `gaps` から書く生成区画にする。CI は `--check` で最新であることを確かめる。
* `tools/trace check` の TR-D と、`check_obligations.py` の OB-D1・OB-D2・OB-S1・OB-S2 は、`gaps` から判定する。Markdown の差異の表の解析はやめる。
* 新しい検査を置く。
  * TR-K（`tools/trace`）: 箇所の印と種類の整合を見る。印の不足は、登録の backlog が完了するまで警告にする。
  * GK（`obligation-check`）: 宣言の層・docstring・ID の重複・印の層と ID を見る。

### ID の割り当て

* 未確定の差異（ログイン時の状態更新）に **D-028** を割り当てる。
* PRE の外の表の ID の無かった 2 行に、**D-029**（空港コード `NOP`）と **D-030**（値域の外の int32 の折り返し）を割り当てる。
* 移行は 1 回きりの変換スクリプトで表から生成した。生成した表を元の表と行ごとに比べ、内容の差が無いことを確かめた。差は 2 つだけで、どちらも意図したものである。
  * 新しく採番した行
  * D-006 の箇所の区切り（`、` を `・` に揃えた）

### Consequences

* Good: ギャップの登録・箇所・定理の仮定が、すべて Lean で機械的に結びつく。原則 3 の「証明の中」に、モデル外・PRE の外・未確定のギャップも名前で現れる。
* Good: 表の書式と検査の解析が食い違う余地が無くなる。
* Good: 上流の版上げで、見直すギャップが影響分析から出る。
* Bad: 説明を直すときに、Lean を書き換えて表を再生成する手順が要る（`lake build`・`trace-dump`・`trace manifest`）。
* Neutral: [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) の「文書の登録簿」は、生成した表として残る。01d4 の決定（差異を名前付きの仮定・成分と文書の両方に置く）は変わらない。

### Confirmation

* `TraceTest/GapErrors` で、種類と欄の矛盾、読めない値、型の誤りが、付けた時点でエラーになる。
* `TraceTest/ObligationFixture` で、GK の各規則を検出する。
* `tools/trace` の自己テストで、TR-K の各規則と表の生成を確かめる。
* `tools/ci/lean.sh` で、表が最新であることと TR-D・TR-K を確かめる。

## More Information

* 実装の置き場所は、スキル port-lang の `assets/lean/Trace/Gap.lean` である（[ADR 7fe4](7fe4-move-trace-attributes-to-skill.md)）。書き方は、スキルの [trace-attributes.md](../../.agents/skills/port-lang/references/lean/trace-attributes.md#ギャップの登録簿) にある。
* 作業項目: [backlog 114a](../backlog/114a-gap-attributes-and-trace-in-skill.md)
