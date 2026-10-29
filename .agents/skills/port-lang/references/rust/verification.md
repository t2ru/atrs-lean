# Rust: 検証器（Verus・Kani）

## 移植先として

| 手段 | 置き場所 | 何を確かめるか |
| --- | --- | --- |
| Verus | 業務機能の `ensures` と `proof/` | 実行コード ＝ `model/`（Lean `TargetModel` の写し）。全入力、オーバーフロー無し |
| Kani | `kani/` | `verus!` の外のコード（変換・JSON）、アダプタの契約、パニック・未定義動作が無いこと（有界） |
| 照合テスト | `tests/` | Rust の結果 ＝ Lean `TargetModel` の結果（[harness.md](harness.md)） |
| 結合テスト | `tests/` | トランザクション・HTTP の契約 |

- Verus の `assume`・`admit`・`#[verifier::external_body]` を業務機能と `proof/` で使ってはならない。やむを得ず使う場合は意思決定として記録し、具体化の課題一覧に列挙する。
- Kani のハーネスには、境界（`kani::any()` の範囲・ループの展開数）と、何を保証しないかをコメントに書く。
- `model/` と Lean `TargetModel` の一致は証明ではない。同名・同構造の規約、追跡タグのハッシュ、照合テストで担保する。

### 既知の不確実性

- Verus は特定の Rust 版を要求する。ツールチェーンは Verus のリリースに合わせて固定する。
- `verus!` で書いたコードに Kani をそのまま当てられるかは、版の組み合わせに依存する。プロジェクトの最初に、小さな関数で併用を確かめる。併用できなければ、Kani の対象を `verus!` の外のコードに限る。

## 移植元として

原典に検証器を当てる必要は無い。原典と `SourceModel` の対応は、オラクル（[harness.md](harness.md)）と追跡注釈で確認する。
原典にすでに Verus・Kani の検証がある場合は、その事後条件を `SourceModel` の定理の仮定として使ってよい（どの定理が依存しているかを記録する）。

## 品質

- `cargo fmt`、`cargo clippy -- -D warnings`。
- CI は Verus、`cargo kani`、`cargo test`、追跡の検査を実行する。
