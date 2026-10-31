---
type: Reference
title: "Rust: 検証器（Verus・Kani）"
description: "Rust のソースとモデルの一致を確かめる検証器（Verus・Kani）と、その保証の限界。"
tags: [rust, language-pack, verification]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Rust: 検証器（Verus・Kani）

## 移植先として

| 手段 | 置き場所 | 何を確かめるか | 保証の限界 |
| --- | --- | --- | --- |
| 写しの生成 | `model/`（`lake exe gen-verus` の出力） | `model/` が Lean `TargetModel` と同じ定義であること（決定論的な変換。CI で再生成し、差分が無いことを確認する） | 生成器と、`LangSemantics.Rust` から Verus への対応表（`model_prelude.rs`）を信頼する |
| Verus | 業務機能・インメモリのアダプタの状態遷移の `ensures` と `proof/` | 実行コード ＝ `model/`。全入力で、オーバーフロー無し | `verus!` の中のコードに限る。Verus・vstd・Rust コンパイラの意味論を信頼する |
| SQL の差分実行 | `tests/` | DB アダプタの SQL と、`TargetModel.Adapter` の `LangSemantics.Sql` の式の一致 | 照合したデータの外 |
| Kani | `kani/` | `verus!` の外のコード（変換・JSON・HTTP の接続）について、パニック・未定義動作が無いこと | 有界（`kani::any()` の範囲・ループの展開数） |
| 照合テスト | `tests/` | Rust の結果 ＝ Lean `TargetModel` の結果（[harness.md](harness.md)） | ベクタの入力の外 |
| 結合テスト | `tests/` | DB・ファイル・時計・HTTP のアダプタが、`TargetModel.Adapter` と HTTP の契約に一致すること（固定フィクスチャ） | テストした入力と実行順の外。DB エンジンの分離レベルの実装を信頼する |
| 禁止 API の検査 | `clippy.toml` の `disallowed-methods` / `disallowed-types` | 業務機能が `std::time`・浮動小数点型などの暗黙の副作用を使わないこと | 検査対象の一覧に載ったものに限る |

- `#[verifier::external]` は、次の 2 か所に限って使ってよい。その一覧は保証の限界の文書に載せる。
  - インメモリのアダプタの状態を `Mutex` で包む薄い層
  - DB・ファイル・時計・HTTP のアダプタ
- Verus の `assume`・`admit`・`#[verifier::external_body]`・`assume_specification`・`external_fn_specification` を、業務機能・インメモリのアダプタ・`proof/` で使ってはならない。やむを得ず使う場合は、次の 3 つを満たす。
  - 意思決定として記録する。
  - 保証の限界の文書に、場所と理由を列挙する。
  - 具体化の課題一覧からリンクする。
- Kani のハーネスには、境界（`kani::any()` の範囲・ループの展開数）と、何を保証しないかをコメントに書く。境界は、保証の限界の文書にも載せる。
- `model/` を手で編集してはならない。

### 確認の課題の一覧

具体化の課題一覧（meta）の「移植先ソースの確認」には、少なくとも次を ID 付きで載せる（ID はプロジェクトで決める）。

| 課題 | 内容 | 手段 |
| --- | --- | --- |
| ベクタ | 移植先が `target-model/` と `shared/` の全ベクタを通す | 照合テスト |
| 写し | `model/` が `TargetModel` から生成したものと一致する | 再生成で差分が無いこと |
| 実行コード | 純粋な部分とインメモリのアダプタの状態遷移が `model/` と全入力で一致し、算術が溢れない。各関数が `requires pre_x(..)`・`ensures r == model::x(..)` の形を持つ | Verus、契約の形の検査 |
| 写しの外 | `verus!` の外のコード（排他の層・変換・JSON・HTTP の接続）にパニック・未定義動作が無い | Kani |
| アダプタ | DB・ファイル・時計のアダプタが `TargetModel.Adapter` と一致し、状態変更の原子性・直列化可能性を満たす | インメモリは排他の下で 1 つずつ実行、DB は分離レベルと再試行、結合テスト |
| 外部契約 | HTTP などの外部の契約（ステータス・遷移先・JSON の形・規範節） | 外部契約のベクタによる結合テスト |
| 追跡 | TR-T1・TR-T2・TR-P・TR-D・TR-X が通り、公開項目が `@[target]` で覆われ、検査済みハッシュが現在の本文と一致する | `trace check`・`trace rehash` |
| 禁止 API | 業務機能が時計・浮動小数点型などの暗黙の副作用を使わない | `clippy.toml` の `disallowed-methods` / `disallowed-types` |
| SQL | DB アダプタの SQL が、`TargetModel.Adapter` の `LangSemantics.Sql` の式と一致する | SQL の差分実行（[sql/harness.md](../sql/harness.md#差分実行の結果)） |

### 既知の不確実性

- Verus は特定の Rust 版を要求する。ツールチェーンは Verus のリリースに合わせて固定する。
- `verus!` で書いたコードに Kani をそのまま当てられるかは、版の組み合わせに依存する。プロジェクトの最初に、小さな関数で併用を確かめる。併用できなければ、Kani の対象を `verus!` の外のコードに限る。

## 移植元として

原典と `SourceModel` の一致は、オラクル（[harness.md](harness.md)）で `source-model/` のベクタと照合して確認する（限界: ベクタの入力の外）。
原典にすでに Verus の検証があっても、その事後条件をリファインメント定理の仮定として使ってはならない（主定理の仮定は PRE・INV・`@[deviation]` だけである）。既存の検証は補助の手段として扱い、その範囲を保証の限界の文書に書く。

## 品質

- `cargo fmt`、`cargo clippy -- -D warnings`。
- CI は Verus、`cargo kani`、`cargo test`、追跡の検査を実行する。
