---
type: Architecture Decision Record
title: "両端の追跡をロケータとモデル側注釈で表し、確認済みハッシュを決定論的な検査の合格記録とする"
description: "ADR 0023 の追跡方式を引き継ぎ、確認済みハッシュの意味を人の確認から決定論的な検査の合格記録に改め、TR 検査の例外と恒久的な警告をなくし、差異の対応を検査する TR-D とテンプレートのロケータ tmpl: を加える。ADR 0023 を置き換える。"
tags: [adr, traceability]
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 両端の追跡をロケータとモデル側注釈で表し、確認済みハッシュを決定論的な検査の合格記録とする

## Context and Problem Statement

[ADR 0023](0023-cross-language-traceability.md) は、両端の追跡を次の 4 つで行うと決めた。
- 記号的なロケータ
- モデル側の注釈（確認済みハッシュ付き）
- 生成した manifest
- CI の検査

ただし、[ADR 0033](0033-foundational-principles.md) の原則 1 から見て、次の弱点がある。

* 「確認済みハッシュ」は、人が相手側を再確認したことを表していた。人の確認は、一致の根拠として決定論的ではない。
* TR-S1・TR-T1・TR-P を警告にとどめる期限が無い。TR-P には「理由付きの例外」がある。
* 差異（[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)）と、Lean の仮定の対応を検査する手段が無い。
* 原典のテンプレート（Thymeleaf）にロケータが無い。そのため、テンプレート由来の差異（D-019）の出所を追跡できない。

## Decision Drivers

* 上流のファイル構成・行番号が変わっても壊れにくいこと（ADR 0023 から引き継ぐ）
* リンクの正を一か所に置き、二重管理しないこと（同）
* 「確認した」という主張を、決定論的な検査の合格に結びつけること
* 網羅性、直接つながない規則、差異の対応を、CI で検査できること

## Considered Options

* ADR 0023 の方式を引き継ぎ、ハッシュを決定論的な検査の合格記録に改め、検査を強める
* ADR 0023 のまま（ハッシュは人の確認の記録）

## Decision Outcome

Chosen option: "ADR 0023 の方式を引き継ぎ、ハッシュを決定論的な検査の合格記録に改め、検査を強める", because 追跡の各リンクが、機械が実行した検査に裏づけられるため。

### ロケータ

ソース側の位置は、版に依存しない記号で指す。行番号は道具が版ごとに解決し、permalink を生成する。文法は [port-lang/traceability.md](../../.agents/skills/port-lang/references/traceability.md#ロケータ) に定義する。

| 側 | 種別 |
| --- | --- |
| 移植元 | `java:<FQCN>#<method>(<引数型>)`, `sql:<namespace>#<id>`, `ddl:<file>#<object>`, `seed:<file>#<row>`, `prop:<file>#<key>`, `msg:<file>#<key>`, `http:<METHOD> <path>?<param>`, `xml:<file>#<要素パス>`, `tmpl:<テンプレートのパス>#<要素の id または th: 式の位置>`（文法は言語パックの `locators.md`） |
| 移植先 | `rust:<crate>::<path>` |
| 両側 | `dep:<座標>#<シンボル>`（フレームワーク・クレート）、`lang:<言語>#<節>`（処理系） |

### インベントリ

* `trace/source-inventory.json`（上流を走査）と `trace/target-inventory.json`（`rust/` を走査）を道具で生成し、コミットする。
* 各項目は、ロケータ・ファイル・行範囲・**正規化した本文ハッシュ** を持つ。ハッシュは空白とコメントを除いて計算するが、文字列リテラルの中身は保つ。`dep:`・`lang:` は、ハッシュの代わりに版文字列を使う。
* 版の宣言は `trace/upstream.json` と `trace/target.json` に置く。

### 注釈（リンクの正はモデル側）

| 置き場所 | 注釈 |
| --- | --- |
| Lean `SourceModel`, `LangSemantics.Java/Sql` | `@[source "<移植元ロケータ>@<検査済み本文ハッシュ>", …]` |
| Lean `TargetModel`, `LangSemantics.Rust` | `@[target "<移植先ロケータ>@<検査済み本文ハッシュ>", …]` |
| Rust `model/`（生成した Verus の写し） | `/// trace: models <TargetModel の完全名> @<Lean Merkle ハッシュ>`（生成器が書く） |
| Lean `Abstraction`, `Refinement` | `@[obligation "ABS-NNN"]` / `@[obligation "REF-NNN"]`。モデル間の対応は、定理の型に現れる定数から自動で導出する |
| Lean の差異の述語・成分 | `@[deviation "D-NNN"]` / `@[deviation "T-NNN"]`（[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)） |
| Lean `Spec` | `@[spec_doc "docs/spec/…#…"]`、移植元に対応の無い定義は `@[no_source "<理由>"]` |
| 適合テストベクタ | `modelDef`（試すモデル定義の完全名）。`source-model/` には `upstream`（release と commit） |

### 検査済みハッシュ

* 注釈のハッシュは、**そのハッシュの版で、その定義を対象とする決定論的な検査が合格したこと** の記録である。対象となる検査は、ベクタの照合・オラクル・差分オラクル・Verus の証明・SQL の差分実行である。
* ハッシュが現在の値とずれたら「要再検査」とし、TR-S2・TR-T2 を失敗させる。
* ハッシュの更新は、道具（`tools/trace rehash`）だけが行う。道具は、対象の定義にかかる決定論的な検査を実行し、すべて合格したときに限ってハッシュを書き換える。
  * 合格しなければ、モデルかソースを直す。
  * 人や LLM の判断だけで、ハッシュを書き換えてはならない。
* 対象の定義を覆う検査が 1 つも無い場合、道具はハッシュを更新してはならない。その定義には、まず検査（ベクタなど）を追加する。
* どの検査が合格したかを、`trace/manifest.json` に記録する。記録は、ソースの本文ハッシュと、モデルの定義の Lean Merkle ハッシュの組に対して行う。どちらが変わっても、再検査が必要になる。
* ハッシュで判別できない改名（`trace/renames.json` に手で書く対応）も、同じ扱いとする。`rehash` は、新しいロケータについて決定論的な検査を実行し、合格したときに限って対応を受け入れる。手で書いた対応表だけでは、リンクは成立しない。

### 直接接続の禁止（ADR 0023 から引き継ぐ）

* `SourceModel`・`LangSemantics.Java/Sql`・`Abstraction`・`Spec` に、移植先のロケータ（`rust:`）を書いてはならない。
* `TargetModel`・`LangSemantics.Rust`・`Refinement` と `rust/` に、移植元のロケータを書いてはならない。移植元のロケータとは、移植元の言語パックが定めるすべての kind（`java:` `sql:` `ddl:` `seed:` `prop:` `msg:` `http:` `xml:` `tmpl:` など）と、移植元側の `dep:` をいう。
* 移植元ソースと移植先ソースを直接対応づける表・ファイルを、作ってはならない。影響分析は、証明グラフ（`SourceModel` → `Abstraction` → `Spec` → `Refinement` → `TargetModel`）をたどって行う。

### 生成物と検査

* `trace/manifest.json`（生成し、コミットする）は、全ノード・型付きのリンク・合格した検査を持つ。
* [traceability.md](../spec/traceability.md) の 2 本の表は、manifest から生成する。2 本とは、移植元ソース ⇔ `SourceModel` と、`TargetModel` ⇔ 移植先ソースである。

| ID | 失敗条件 |
| --- | --- |
| TR-S1 | スコープ内の上流インベントリの項目が `@[source]` で覆われず、対象外一覧にも無い |
| TR-S2 | 次のどちらかに当たる。<br>- `@[source]` の検査済みハッシュが、上流インベントリと一致しない<br>- 定義の Lean Merkle ハッシュが、最後に検査が合格したとき（manifest に記録）から変わっている。モデル側だけを直した場合も、再検査を求める |
| TR-T1 | 次のどちらかに当たる。<br>- `TargetModel` の公開定義に `@[target]` が無い<br>- スコープ内の Rust の公開項目が `@[target]` で覆われず、対象外一覧にも無い。生成物 `rust/src/model/` は対象外とする（SRC-002 の再生成と TR-T2 で確かめる）。`model_prelude.rs` はスキルの assets から写したものなので対象外とし、その `/// trace: models LangSemantics.Rust.…` タグを TR-T2 で確かめる |
| TR-T2 | 次のどれかに当たる。<br>- `@[target]` のハッシュが Rust インベントリと一致しない<br>- 定義の Lean Merkle ハッシュが、最後に検査が合格したときから変わっている<br>- `/// trace: models` のハッシュが Lean の Merkle ハッシュと一致しない |
| TR-P | `SourceModel` の公開操作が、どの R 課題（`Abstraction`）の定理にも現れない。または、`TargetModel` の公開操作が、どの R 課題（`Refinement`）の定理にも現れない。例外は無い |
| TR-D | 次のどれかに当たる。<br>- 文書の前提型・観測型の D/T と、Lean の `@[deviation]` が 1 対 1 でない<br>- `@[deviation]` が、どの R 課題の定理の型にも現れない<br>- D/T に W 課題が無い<br>- R 課題の定理に、`@[deviation]`・PRE・INV 以外の仮定がある |
| TR-X | 直接接続の禁止に違反している |
| TR-R | 参照切れがある（存在しない Lean 名・ロケータ・課題 ID・差異 ID） |

* 対象外一覧 `trace/out-of-scope.json` に載せてよいのは、[ADR 0002](0002-porting-scope.md) で移植の範囲外としたものだけである。各項目には、ADR の該当節を書く。
  * 範囲外のソースでも、[Source] の振る舞いに影響する（差異の出所になる）ものは、対象外にしてはならない。例: D-019 のテンプレート。
* 段階導入: TR-S1・TR-T1・TR-P・TR-D を警告にしてよいのは、該当する機能の backlog 項目が `done` になっていない間だけである。項目を `done` にする時点で、その機能について全検査が失敗扱いで通っていなければならない。それ以外の検査は、最初から失敗扱いとする。

### 道具

* `tools/trace/` に、Rust の独立した Cargo プロジェクト（stable ツールチェーン）を置く。`tools/` は、名前空間の規則の例外とする。
* サブコマンド:
  * `inventory source|target`
  * `ingest-lean`
  * `manifest`
  * `check`（TR 検査）
  * `rehash`（決定論的な検査を実行し、合格した定義だけハッシュを更新する）
  * `diff`
  * `impact`

### Consequences

* Good, because 追跡の各リンクと「確認した」という記録が、機械が実行した検査に結びつく
* Good, because 差異が文書と Lean の両方にあることを、CI で強制できる
* Bad, because ハッシュの更新のたびに、関係する検査を実行する時間がかかる
* Bad, because 検査で覆われていない定義は、ハッシュを更新できない（先に検査を書く必要がある）

### Confirmation

* CI で `tools/trace check` を実行する。
* [traceability.md](../spec/traceability.md) の例（運賃計算の 1 系統）で、各検査の判定を確かめられる。

## Pros and Cons of the Options

### 引き継いで強める

* Good, because 原則 1・3 を機械的に保てる
* Bad, because 道具の機能が増える

### ADR 0023 のまま

* Good, because 道具が単純
* Bad, because ハッシュが人の確認の記録にとどまり、原則 1 を満たさない

## More Information

* 本 ADR は [ADR 0023](0023-cross-language-traceability.md) を置き換える。
* [ADR 0033](0033-foundational-principles.md), [ADR 0034](0034-b-method-refinement-and-explicit-deviations.md), [ADR 0035](0035-generate-verus-mirror-from-target-model.md), [ADR 0024](0024-following-upstream-releases.md)
* [backlog 0024](../backlog/0024-trace-tooling.md)
