---
type: Architecture Decision Record
title: "アプリに依存しない道具と Lean のライブラリをスキル port-lang へ移し、ATRS 固有の値を trace/project.json に集める"
description: "tools/ の汎用の道具（追跡の CLI・Lean の静的検査・課題一覧との突き合わせ・上流の版の検査・突き合わせ表の検査・ID の道具）をスキルの scripts/ へ移し、ATRS 固有の値を trace/project.json から読ませる。Abstraction・Tests に混ざっていた汎用の Lean コードを、スキルの assets（Machine.Kernel・LangSemantics.Core（新設）・LangSemantics.Java/Sql・ConformanceKit（新設））へ移す。汎用の方法を文書でもスキルへ移し、スキルに紛れた ATRS 固有の記述を外す。"
tags: [adr, skill, tooling, lean, traceability]
id: "edc8d903-dc72-461c-9101-ba470ea63ad7"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:30:00+09:00
---

# アプリに依存しない道具と Lean のライブラリをスキル port-lang へ移し、ATRS 固有の値を trace/project.json に集める

## Context and Problem Statement

ATRS の ADR f4e1 は、移植の方法をアプリに依存しないスキルに、ATRS 固有の情報を `docs/` に置くと決めた。
[ADR 7fe4](7fe4-move-trace-attributes-to-skill.md) で追跡属性の仕組み（`Trace`）を移した。
しかし、調査すると、汎用の要素がまだ ATRS 側に残っていた。

* **道具**: `tools/trace`（追跡の CLI）・`check_lean.py`・`check_obligations.py`・`check_upstream.py`・`with_postgres.sh`・`jvm_table.sh`・`pg_table.sh`・`ids.py`。どれも中身は汎用である。ATRS 固有の部分は、次の小さな集合に限られる。
  * crate 名 `atrs`
  * 上流の配置（`upstream/atrs/JavaConfig-Thymeleaf/atrs`、`atrs-initdb`）
  * 文書のパス
  * 言語の組（Java・SQL → Rust）
  * Lean のルート
* **Lean**: `Abstraction` に汎用の補題が混ざっていた。
  * 部分写像の核 `undefOrEq`
  * 列・`mapM`・整列・結合の補題
  * double の百分率の因子の比較
  * `JResult`・`JHashMap` の補題

  `Tests` には、適合テストの実行器の骨格も混ざっていた。
* **文書**: 汎用の方法が ATRS の文書にだけ書かれていた。
  * 道具が読むファイルの形
  * 道具が読む見出しの文字列
  * α/β の核の列
  * SPEC 課題の一覧
  * 保証の限界の必須項目
  * 版上げの例
  * ベクタの比較の規則

  逆に、スキルに ATRS 固有の記述が紛れていた。
  * 実際の D-001・D-002 を例にしている
  * assets のコメントが ATRS の ADR を根拠として引いている
  * `rust:atrs::`

## Decision Drivers

* ATRS の ADR f4e1 の分け方を、道具・Lean のライブラリ・文書のすべてに及ぼす
* 他のアプリへ移植するときに、写さずに使える
* 移動の前後で、検査の結果と追跡のハッシュを変えない
* スキルの依存の規則（`references/lean/rules.md`・`architecture.md#依存の向き`）を、必要な分だけ広げる

## Considered Options

* 道具の置き場所
  * スキル直下の `scripts/`（Agent Skills の慣例）
  * スキルの `assets/tools/`
* プロジェクト固有の値の渡し方
  * 設定ファイル `trace/project.json` に集める
  * 道具ごとの引数で渡す
* Lean の汎用コードの移し先
  * 既存の層（`Machine`・`LangSemantics.<lang>`）に足し、純粋な列・`Option` の補題のために `LangSemantics.Core` を新設する
  * それに加えて、`Spec` の基本演算とフレームワークのモデルも、スキルのライブラリへ移す

## Decision Outcome

採択した選択肢は次の 3 つである（いずれもプロジェクトオーナーが選んだ）。

* 道具は `scripts/` に置く。
* 設定は `trace/project.json` に集める。
* Lean のコードは既存の層と `LangSemantics.Core` に移す。

### 道具（`scripts/`）

| 移す元（ATRS） | 移す先（スキル） |
| --- | --- |
| `tools/trace/` | `scripts/trace/` |
| `tools/ci/check_lean.py`・`check_obligations.py`・`check_upstream.py`・`with_postgres.sh`・`jvm_table.sh`・`pg_table.sh` と自己テストの fixtures | `scripts/ci/` |
| `tools/docs/ids.py` | `scripts/docs/ids.py` |

* 道具は、作業ディレクトリから上にたどって `trace/project.json` があるところを、リポジトリのルートとする。
  * crate 名・移植元/移植先の配置・文書のパス・言語の組・Lean のルート・ID の道具の設定は、このファイルから読む。
  * 言語ごとのロケータの種類と `LangSemantics` の層は、言語パックの既定から引く。
* 道具が読む日本語の見出しと値は、設定にせず、スキルの `references/spec-documents.md#道具が読む見出しと値` で文字列を固定する。
* ATRS 固有のまま残すものは次のとおり。
  * `tools/ci/lean.sh`（スキルの道具を呼ぶ）
  * `tools/ci/master_sql.sh`
  * `tools/conformance/*`
  * `tools/docs/legacy-ids.json`

### Lean（`assets/lean`）

| 移す元（ATRS） | 移す先（スキル） |
| --- | --- |
| `Abstraction.Prim.undefOrEq`・`kernelIs_undefOrEq`、`Abstraction.MasterData.inj_of_kernel` | `Machine.Kernel`（`Machine.Kernel.undefOrEq` ほか） |
| `Abstraction.Prim` の列・`mapM` の補題、`append_sep_inj`・`string_any_toList`・`mapM_some_getD` | `LangSemantics.Core`（新設） |
| 結合（`filter_cross`）と `ORDER BY` の許される順列の補題、`allowed_perm` | `LangSemantics.Sql.QueryLemmas` |
| `ok_bind`・`mapM_ok`・`forIn_ok`、`get_ofList_perm`、`Abstraction.Fare.Double` と `Factors` の汎用部 | `LangSemantics.Java`（`ResultLemmas`・`HashMap.Lemmas`・`JDouble.Compare`） |
| main の ATRS の backlog bbcc 第 3 段で `Abstraction.Fare.Loop` などに足された汎用の補題（`Forall₂`・`forall₂_of_mapM`・`mapM_eq_map_getD`・`mapM_length`・`sum_map_le`、値域内の `int` の演算と `for` 文の和・計数 `forIn_sum_eq`・`forIn_count_eq`） | `LangSemantics.Core`、`LangSemantics.Java.IntLemmas`（取り込みのときに移した） |
| `Tests.Conformance` の実行器の骨格、`Tests.MasterSql` の表の読み取り | `ConformanceKit`（新設のメタ層） |

* `LangSemantics.Core` は core だけに依存する。どの言語パックからも、移植元側・移植先側のどの層からも import してよい。
* obligation-check の G7 は、`Machine.Kernel.undefOrEq` を葉に適用した核を、`@[kernel]` の定数と同じく受け付ける。
* `Spec` の基本演算（`floorDiv`・暦日など）とフレームワークのモデル（Spring の `Assert`、terasoluna のコードリスト、MyBatis の型の対応）は、ATRS に残す。スキルの規則どおり、プロジェクトの `Spec`・`SourceModel` に置く。
* SQL の列の等号 `eqText`・`eqInt` も `SourceModel` に残す。`@[source]` を持つ Mapper の文の定義が参照しているので、移すと、その定義の検査済みハッシュを決定論的な検査で取り直すことになる。移しても、それに見合う利点が無い。

### 文書

* スキルに足すもの
  * 道具の置き場所と使い方（`scripts/README.md`）
  * `trace/project.json` と手書きのファイルの形
  * 道具が読む見出しの文字列
  * 式の書き方
  * α/β の核の列
  * SQL の差分実行の結果の形
  * 移植先の確認の課題の一覧
  * SPEC 課題の一覧
  * 保証の限界の必須項目の不足分
  * 版上げの例（架空）
  * ベクタの比較の規則（多重集合での比較・基準日・参照実装）
  * ADR を書く契機
* スキルから外すもの（ATRS 固有の記述）
  * 実際の D-001・D-002 を使った例は、架空の例に替える。
  * assets・scripts のコメントで ATRS の ADR を引いていた箇所は、スキルの `references/*.md` を引くように替える。
  * `rust:atrs::` は `rust:app::` に替える。
* スキルの版を 0.6 に上げる。

### Consequences

* Good: 他のアプリは、`trace/project.json` を書くだけで、道具と Lean のライブラリを写さずに使える。
* Good: ATRS の `Abstraction`・`Tests` には、ATRS の業務の型に関わるものだけが残る。
* Neutral: 移動の前後で結果が同じであることを確かめた。
  * 移動の前後で同じだったもの
    * `trace check` の誤り・警告の一覧（`--verbose`）
    * `check_obligations.py` の出力
    * `obligation-check` の R 課題の判定
    * `lake test` の検査の一覧
  * merkle が変わったもの: 移した補題を参照する `Abstraction` の定義だけ（`@[source]` を持つ定義は変わらない）
  * 文字だけが変わったもの: 生成区画の注記（「`tools/trace manifest` が生成する」→「`trace manifest` が生成する」）
* Bad: ATRS の CI は、スキルの道具のパス（`.agents/skills/port-lang/scripts/…`）に依存する。

### Confirmation

* `tools/ci/lean.sh` が全段通る。
* スキルの assets で `lake build` が通り、`ConformanceKitTest` と `TraceTest`（`Machine.Kernel.undefOrEq` の正例・違反例を含む）を確かめる。
* `scripts/trace` の `cargo test` が通る。
* `check_lean.py --self-test` が通る（`LangSemantics.Core` の依存の正例・違反例を含む）。
* `check_obligations.py --self-test` が通る。
* スキルの中に、ATRS 固有の語（`atrs`・`ATRS`・ATRS の ADR の ID）が残っていない。

## More Information

* 来歴: ATRS の `docs/decision` で決めた記録を、[ADR 87b9](87b9-skill-docs-as-okf-bundle.md) でこのバンドルへ移した。ATRS へのリンクは、リンク無しの来歴の文に直した。
* ATRS の ADR f4e1・[ADR 7fe4](7fe4-move-trace-attributes-to-skill.md) の続きである。
* ATRS の ADR e9bc が「比較の定理（ATRS）」と書いた層は、汎用部をスキルの `LangSemantics.Java.JDouble.Compare` に移した。ATRS の `Abstraction.Fare.Factors` には、因子の表と差異の条件が残る。
* 作業項目: ATRS の backlog 38fb
