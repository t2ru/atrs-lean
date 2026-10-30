---
type: Architecture Decision Record
title: "rehash・diff・impact の細部（検査の登録・注釈の書き換え・改名・出典の検査）を決める"
description: "ADR 0036 の rehash・diff・impact について、検査の登録（trace/checks.json）とそれが覆う定義、rehash の対象と手順、Lean の注釈の書き換え方、renames.json の検査、diff の分類と impact の伝播、文書の「出典:」のロケータの検査を決める。ADR 0040 を補う。"
tags: [adr, traceability, tooling]
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T06:36:39+09:00
---

# rehash・diff・impact の細部（検査の登録・注釈の書き換え・改名・出典の検査）を決める

## Context and Problem Statement

[ADR 0036](0036-traceability-hash-as-deterministic-check-record.md) は、次のことを定めた。

* 注釈のハッシュの更新は道具（`tools/trace rehash`）だけが行う。
* 更新は、対象の定義にかかる決定論的な検査がすべて合格したときに限る。
* 覆う検査が無い定義は更新しない。

ただし、次の点は決めていなかった。

* どの検査がどの定義を覆うかを、どこに書くか
* 注釈をどう書き換えるか（Lean のソースのどこを、どの範囲で書き換えるか）
* `renames.json` の検査
* `diff`・`impact` の入出力
* 文書の「出典:」をロケータ表記にしたあとの検査

[backlog 0024](../backlog/0024-trace-tooling.md) の第 2 段で、これらを決める必要がある。細部の多くは [ADR 0040](0040-trace-tooling-unresolved-details.md) が決めており、この ADR はそれを補う（置き換えない）。

## Decision Drivers

* 合格していない定義の注釈と記録を、道具が変えないこと（ADR 0036）
* どの検査がどの定義を覆うかが、機械で読めて、検査を足す backlog が自分で登録できること
* 書き換えが、関係の無い定義の注釈に及ばないこと
* 移植元ソースと移植先ソースを直接結ばないこと（影響分析は証明のグラフをたどる）

## Considered Options

* 検査の登録を `trace/checks.json` に置き、下表のとおり決める
* 検査を Lean の属性（定義ごとに検査の ID を書く）で表す
* 検査の対応を道具に埋め込む

## Decision Outcome

Chosen option: "検査の登録を `trace/checks.json` に置き、下表のとおり決める", because 検査の実行方法（コマンド）は Lean の外にあり、Lean の属性にすると、検査を足すたびにモデルの定義を変えることになるため。また、道具に埋め込むと、他の移植で再利用できないため。

| 項目 | 決定 |
| --- | --- |
| 検査の登録 | `trace/checks.json`（手で書く）。検査ごとに `id`・`description`・`steps`・`covers` を持つ。<br>- `steps`: 作業ディレクトリ（`cwd`。リポジトリからの相対）と `argv` の並び<br>- `covers`: `names`（Lean の名前の glob）と `vectors`（適合テストベクタのファイルの glob） |
| 覆う定義 | `names` に当たる定義と、`vectors` に当たるファイルの `modelDef` から参照をたどって届く定義（参照の閉包） |
| 合格 | `steps` をこの順に実行し、すべての終了コードが 0 であること。処理系が無いので飛ばした場合（`tools/ci/jvm_table.sh`・`pg_table.sh` の終了コード 2）は不合格とする |
| 最初の登録 | 次の 3 つ。Verus・Kani・移植元のオラクル・SQL の差分実行は、それぞれの backlog が登録する。<br>- `lake-test`: 適合テストベクタの照合<br>- `jvm-table`: `LangSemantics.Java.*` を覆う<br>- `pg-table`: `LangSemantics.Sql.*` を覆う |
| `rehash` の対象 | `@[source]`・`@[target]` の各組（定義, ロケータ）のうち、次のどれかに当たるもの。<br>- ハッシュ（`dep:`・`lang:` は版）がインベントリ・宣言と違う<br>- 本文ハッシュと Merkle の組に、合格の記録が無い<br>- ロケータが `renames.json` の `old` に当たり、`new` がインベントリにある |
| `rehash` の手順 | 次の順に行う。<br>1. 対象を覆う検査を、それぞれ 1 回だけ実行する。<br>2. 覆う検査がすべて合格した組について、注釈を書き換え、manifest に記録（定義・ロケータ・本文ハッシュ・Merkle・合格した検査の ID）を書く。<br>3. manifest と、`traceability.md` の生成区画を作り直す。<br>覆う検査が無い組、合格しなかった組、解決できない注釈が 1 つでもあれば、終了コードを 1 にする。`--dry-run` は、対象と覆う検査を表示するだけで、何も実行しない |
| 注釈の書き換え | `trace-dump` の各定義に `module` を出力する。`rehash` は、そのモジュールのファイル（`lean/` と、スキルの `assets/lean/`）の中で、文字列 `"<ロケータ>@<旧>"` を `"<ロケータ>@<新>"` に置き換える。同じ文字列を注釈に持つ定義が同じモジュールに複数ある場合は、それらがすべて合格したときだけ置き換える。置き換えなかった定義は、記録もしない。Merkle は属性を含まないので、書き換えで変わらない |
| 記録の整理 | 現在の注釈に無い（定義, ロケータ）の記録は、`manifest` と `rehash` が捨てる |
| `renames.json` | `{"renames": [{"old", "new"}]}`。`check` は TR-R として、`old` が現在のインベントリに無いことと、`new` があることを確かめる。対応を受け入れる（注釈のロケータを書き換える）のは `rehash` だけで、検査に合格したときに限る（ADR 0036） |
| `diff` | `trace diff --old <ファイル|git:<rev>> [--side source|target] [--json]`。分類は port-lang の upgrade.md の手順 3 のとおり。<br>- 移動/改名: `renames.json` の対応、または、旧ロケータが消えて同じ本文ハッシュの新ロケータが 1 つだけ現れたもの（新旧どちらかでハッシュが一意でなければ、追加と削除とする）<br>- 版の変化: `git:<rev>` を指定したときに、宣言（`upstream.json`・`target.json`）の新旧を比べる |
| `impact` | `trace impact --dump … --obligations … [--diff <old>] <起点>…`。起点はロケータか Lean の名前で、`--diff` を付けると変化したロケータも起点になる。伝播は upgrade.md の手順 5 の順に、参照のグラフをたどる。<br>1. 起点 → 注釈を持つ定義 → 同じ側のモデル層で、それを参照する定義<br>2. → それを閉包に含む `Abstraction` の R 課題<br>3. → その閉包の `Spec`<br>4. → その `Spec` を閉包に含む `Refinement` の R 課題・`TargetModel`・`rust:` ロケータ。これは「`Spec` を変える場合」として分けて示す<br>移植先の起点は、`Refinement` の R 課題と `Spec` まで逆にたどる。`lang:java` のような起点は `lang:java#…` の注釈に当たる |
| 「出典:」の検査 | `docs/spec/*.md` の「出典:」の行で、バッククォートに囲まれたロケータ（種類で始まるもの）は、現在のインベントリ（`dep:`・`lang:` は宣言）になければならない（TR-R）。<br>- private のメソッドはインベントリの単位ではない（ADR 0040）。そのため、呼び出し元の公開メソッドで書き、private の名前は「（private の `…` を含む）」と補う。<br>- パス表記の行は検査しない。各機能の backlog で順次書き換える |

### Consequences

* Good, because 合格していない定義の注釈と記録を、道具が変えないことを `cargo test` で確かめられる
* Good, because 検査を足す backlog が、`checks.json` に登録するだけで `rehash` の対象を広げられる
* Good, because 版上げの手順 3・5 が、道具の出力でたどれる
* Bad, because `checks.json` の `covers` が広すぎると、実際には試していない定義まで「覆う」ことになる。ベクタの `modelDef` の閉包は、すべての分岐を試すことを意味しない。ベクタの十分さは、引き続き人が見直す（upgrade.md の手順 6）
* Bad, because 注釈の書き換えは文字列の置き換えなので、同じ文字列がコメントにあれば、それも書き換わる

### Confirmation

* `tools/trace` の `cargo test` で、次を確かめる。
  * 合格すれば注釈と記録が更新される。
  * 不合格・覆う検査なし・共有の注釈の一部だけ合格のときは、ファイルも manifest も変わらない。
  * 改名は、合格したときだけ受け入れる。
  * `diff` の各分類、`impact` の層の順序と区別、`renames.json` と「出典:」の参照切れを確かめる。
* CI（`tools/ci/lean.sh`）の `trace check` で、「出典:」と `renames.json` の参照切れを誤りにする。

## More Information

* [ADR 0036](0036-traceability-hash-as-deterministic-check-record.md)、[ADR 0040](0040-trace-tooling-unresolved-details.md)、[backlog 0024](../backlog/0024-trace-tooling.md)
* スキル port-lang の [traceability.md](../../.agents/skills/port-lang/references/traceability.md)、[upgrade.md](../../.agents/skills/port-lang/references/upgrade.md)
