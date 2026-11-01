---
type: Architecture Decision Record
title: "この方法を Spec Pivot と名付け、スキルの名前を spec-pivot に改める"
description: "Lean の正規仕様 Spec を軸に、移植元と移植先を両側からリファインメントで結ぶこの方法を Spec Pivot と名付ける。スキルの識別子（ディレクトリ名と frontmatter の name）を port-lang から spec-pivot に改める。"
tags: [adr, skill, naming]
id: "cfad2920-0410-4e2c-9375-a59adfaf9a73"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T14:50:00+09:00
---

# この方法を Spec Pivot と名付け、スキルの名前を spec-pivot に改める

## Context and Problem Statement

このスキルの方法には名前が無かった。スキルの識別子 `port-lang`（言語間移植）は、扱う作業を表すだけで、方法の特徴を表さない。
方法の特徴は次の 4 つである。

* 正規仕様 `Spec` を中心に置く。
* 移植元と移植先は、それぞれ B メソッドのリファインメントで `Spec` に結ぶ。両者を直接はつながない。
* 両端は決定論的な検査で確かめ、差異はすべて名前を付けて明示する。
* `Spec` は、ほかの言語へも移せる仕様として残る。

プロジェクトオーナーから、方法に名前を付け、スキルの名前もそれに改めるよう指示があった。

## Decision Drivers

* 方法の構造（`Spec` を軸に、両側から結ぶ）を表すこと
* 形式手法の既存の道具・言語と名前が衝突しないこと
* 短く、英語でも日本語の文書でもそのまま使えること

## Considered Options

* Spec Pivot
* Hourglass（砂時計。細いくびれの `Spec` を通って多言語へ広がる）
* Etalon（原器。どの実装も正規仕様に照らして測る）
* Keystone（要石。アーチの両側が要石に寄りかかる）
* LEAP（Lean-mediated, Evidence-Anchored Porting）
* 名前を付けない

## Decision Outcome

Chosen option: "Spec Pivot", because 機械翻訳のピボット言語（A → 中間 → B）と同じく、移植元と移植先を `Spec` だけを介してつなぐ構造を、短く直接に表すため。プロジェクトオーナーが選んだ。副題は付けない。

* 方法の名前を **Spec Pivot** とする。
* スキルの識別子を `spec-pivot` とする。ディレクトリ `.agents/skills/spec-pivot/`、frontmatter の `name`、文書のバンドルの規則のファイル `scripts/docs/profiles/spec-pivot.json` がこれに当たる。
* Lean のパッケージ名 `langSemantics`、モジュール名、名前空間は変えない。追跡のハッシュ（Lean の Merkle ハッシュは `Expr` の構造だけから作る）も変わらない。
* 過去の変更履歴（`log.md`）の文は、来歴として旧名のまま残す。パスとリンクは新しい名前に直す。

### Consequences

* Good, because 方法を名前で指せる。適用先や他の方法との比較でも、何を指すかがはっきりする。
* Bad, because 適用先は、スキルのパス（Lake の `require`、CI、追跡の設定）を書き換える必要がある。

### Confirmation

* スキルの道具（`ids.py check`・`okf_check.py`）と、適用先の CI が、新しいパスで通ること。

## Pros and Cons of the Options

### Spec Pivot

* Good, because 構造（軸と両側）を直接に表す。衝突する著名な道具が無い。
* Bad, because 一般語の組み合わせで、検索では埋もれやすい。

### Hourglass

* Good, because 「どの言語へも」を強く表す。階層の仕様についての理論（hourglass model）とも対応する。
* Bad, because 両側のリファインメントを表さない。

### Etalon

* Good, because 正規仕様と差異の明示を正確に表す。
* Bad, because 語が広く知られていない。

### Keystone

* Good, because 両側が要石に寄りかかる構造を表す。
* Bad, because TEE の Keystone Enclave・OpenStack の Keystone と同名である。

### LEAP

* Good, because Lean と証拠を明示する。
* Bad, because 方法の名前に道具（Lean）が固定される。検証器の Leap と同名である。

### 名前を付けない

* Good, because 変更が要らない。
* Bad, because 方法を名前で指せない。

## More Information

* 検討では、PRISM（確率モデル検査器）・Rosetta（仕様記述言語、Apple の Rosetta）・Janus（可逆プログラミング言語）を、既存の形式手法・言語と衝突するので外した。
* 来歴: 適用先 ATRS の ADR fa26（スキルの改名の適用先への影響）。
