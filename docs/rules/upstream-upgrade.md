---
type: Guideline
title: "移植元の版上げ手順"
description: "上流 ATRS の版を上げるときの手順。インベントリ差分・差分オラクル・影響一覧・層ごとの判断・ベクタ再生成・タグ付け。移植先側の版上げも同じ手順に従う。"
tags: [rules, upstream, versioning, traceability]
status: draft
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# 移植元の版上げ手順

方針は [ADR 0024](../decision/0024-following-upstream-releases.md)、追跡の仕組みは [ADR 0023](../decision/0023-cross-language-traceability.md)。
本規約は道具（[backlog 0024](../backlog/0024-trace-tooling.md)〜[0026](../backlog/0026-differential-oracle.md)）がそろうまで `status: draft` とする。

## 前提

- `SourceModel` は追従中の **最新版 1 つ** だけを表す。旧版は git タグ `upstream-<release>` で参照する。
- 作業は専用の backlog 項目として起票し、1 回の版上げを 1 つの作業単位とする。

## 手順

### 1. 版上げの ADR を作る

旧 release・新 release・上げる理由を書く。`decision_status: proposed` で作り、手順 8 で `accepted` にする。

### 2. 上流を上げる

- `upstream/atrs`（submodule）を新しい commit に上げる。Windows では `git -c core.longpaths=true` を使う。
- `trace/upstream.json` を更新する（release、commit、`pom.xml` から抽出した依存の版、Java・PostgreSQL の版）。

### 3. インベントリ差分を取る

`tools/trace inventory source` で新しいインベントリを作り、`tools/trace diff` で旧版と比べる。ロケータごとに次のどれかに分類される。

| 分類 | 判定 |
| --- | --- |
| 不変 | 本文ハッシュが同じ |
| 本文変更 | 同じロケータで本文ハッシュが違う |
| 移動/改名 | 旧ロケータが消え、同じ本文ハッシュの新ロケータが現れた |
| 追加 / 削除 | 上記以外で、新版にだけ / 旧版にだけある |
| 版の変化 | `dep:`・`lang:` の版文字列が違う |

本文ハッシュで判別できない改名は、`trace/renames.json` に `{ "old": "<ロケータ>", "new": "<ロケータ>" }` として手で書く。設定値・メッセージ文言の変化は「本文変更」として現れる。

### 4. 差分オラクルを実行する

`conformance/source-model/` の全ベクタ入力を、旧版と新版の Java で実行して出力を比べる（[backlog 0026](../backlog/0026-differential-oracle.md)）。
出力が変わったケースは「振る舞いの変化」であり、コード差分の有無にかかわらず手順 6 の判断対象になる。

### 5. 影響一覧を生成する

`tools/trace impact` を実行して `trace/upgrade-impact.md` を作る。手順 3 で変化したロケータと手順 4 で出力が変わったケースを起点に、次の順で影響を伝播させる。

1. `@[source]` が変化したロケータを含む `SourceModel`・`LangSemantics.Java/Sql` の定義
2. それを使う `Abstraction` の定理
3. その定理に現れる `Spec` の定義
4. その `Spec` を使う `Refinement` の定理と `TargetModel` の定義（`Spec` を変える場合だけ）

移植元ソースから移植先ソースへの直接の対応表は作らない（[ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)）。

### 6. 層ごとに判断する

| 状況 | 対応 |
| --- | --- |
| 本文変更・版の変化があるが、差分オラクルに変化が無く、`SourceModel` の定義も変わらない | 確認したうえで `@[source]` のハッシュだけを更新する |
| 移植元の振る舞いが変化した | `SourceModel` を直し、`Abstraction` を再証明する。続けて次のどちらかを選ぶ |
| └ `Spec` が追従する（業務の意図が変わった） | ADR を作り `Spec` を変える。`Refinement` → `TargetModel` → Rust の順に直す（Rust の写しはハッシュずれで自動的に要再確認になる） |
| └ `Spec` は維持する | 既知差異 `D-NNN` を [abstraction.md](../spec/abstraction.md) に追加し、`Abstraction` の一致定理の前提を改める |
| 追加 | 通常の移植手順（[porting.md](porting.md)）で扱う。対象外とするなら理由を対象外一覧に書く |
| 削除 | `SourceModel` から外す。`Spec` に残すかを ADR で決める |
| 移動/改名 | `@[source]` のロケータを書き換える（ハッシュは同じ） |

### 7. ベクタを再生成する

- `conformance/source-model/` を新版の Java オラクルで再生成する（`upstream` キーを新版にする）。
- `Spec` を変えた場合は、`conformance/spec/` と `conformance/target-model/` を Lean から再生成する。
- 差分をレビューする（[testing.md](testing.md)）。

### 8. 完了する

1. TR 検査（`tools/trace check`）、Lean と Rust の全検証を通す。
2. 版上げ ADR を `accepted` にし、[docs/log.md](../log.md) に記録する。
3. 旧版の最後のコミットに `git tag upstream-<旧 release>` を付けてから、版上げを commit する（push しない。[version-control.md](version-control.md)）。

## 移植先側の版上げ

Rust ツールチェーン・Verus・Kani・依存クレートの版上げも同じ流れで扱う。

1. `trace/target.json` を更新する。
2. `dep:`/`lang:` の版が変わった `@[target]` を持つ `TargetModel`・`LangSemantics.Rust` の定義を確認する。
3. Verus と Kani を再実行し、`conformance/target-model/` を通す。

## 例: 依存フレームワークの挙動変化（架空）

Spring の版上げで `StringTrimmerEditor.setAsText` が `trim()`（U+0000–U+0020 を除去）から `strip()`（Unicode の空白を除去）に変わった、と仮定する。

1. 手順 3: `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText` が「版の変化」になる。ATRS 本体のコードは不変。
2. 手順 4: 全角空白（U+3000）で始まる氏名を入力するベクタで、旧版は「全角カタカナでない」エラー、新版は合格になり、差分が出る。
3. 手順 5: `@[source]` にこの `dep:` を持つ入力検証の前処理（`SourceModel.Validation.trimInput`）→ ABS-030 → `Spec.Validation` が影響一覧に出る。
4. 手順 6: 業務の意図は変わらないので `Spec` は維持する。`SourceModel` の前処理を `strip()` に合わせて直し、既知差異 `D-NNN`（Unicode 空白の扱い）を追加し、ABS-030 の前提に「入力の前後に、U+0020 以下以外の Unicode 空白（U+3000 など）を含まない」を加える。
5. `Spec` を変えていないので、`Refinement`・`TargetModel`・Rust は影響を受けない（影響一覧にも出ない）。
