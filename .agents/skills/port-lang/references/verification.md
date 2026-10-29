# 検証の使い分け

| 手段 | 何を保証するか | 対象 |
| --- | --- | --- |
| Lean の証明 | 全入力についての関係: `Abstraction`（`SourceModel` → `Spec`）、`Refinement`（`Spec` → `TargetModel`）、`Spec` の不変条件 | モデル間 |
| 適合テストベクタ | 各モデルとソースの振る舞いの一致を、言語中立な JSON で確認 | 移植元ソース ⇔ `SourceModel`、`TargetModel` ⇔ 移植先ソース、`Spec` 自身 |
| 移植元オラクル | 原典そのものを実行して `source-model/` の期待値を得る。版上げ時は新旧 2 版の差分を取る | 移植元ソース ⇔ `SourceModel` |
| 移植先の検証器 | 移植先ソースと、移植先言語で写した `TargetModel` の一致（例: Verus）、有界な安全性（例: Kani） | `TargetModel` ⇔ 移植先ソース |
| 性質テスト | 証明が未完の性質を、広い入力域で確認する（乱数は固定シード） | 補助 |
| 追跡の検査 | 網羅性・陳腐化・直接接続の禁止（[traceability.md](traceability.md)） | 両端 |

## 信頼の連鎖

```
移植元ソース ─(オラクル: source-model/ ベクタ)→ SourceModel ─(Lean 証明)→ Spec ←(Lean 証明)─ TargetModel ─(target-model/ ベクタ + 移植先の検証器)→ 移植先ソース
```

- 両端の対応（ソース ⇔ モデル）は **証明ではない**。オラクル・ベクタ・検証器・確認済みハッシュで担保する。
- 移植先言語でモデルを写したもの（例: Verus の spec 関数）は、ソースとの一致は証明できる。しかし、写しと Lean の `TargetModel` の一致は、同名・同構造の規約、確認済みハッシュ、ベクタによる担保に留まる。

## 適合テストベクタの運用

- 形式は [conformance.md](conformance.md)。
- 期待値の出所:

| ディレクトリ | 出所（`source`） |
| --- | --- |
| `spec/`, `shared/` | Lean `Spec` の実行（`lean-spec`） |
| `source-model/` | Lean `SourceModel` の実行（`lean-source-model`）と移植元オラクル（例: `java-oracle`） |
| `target-model/` | Lean `TargetModel` の実行（`lean-target-model`） |

- 手計算の例は、Lean 側のテストとして置く。生成値と手計算が食い違ったら、どちらが誤りかを調べてから直す。
- 生成したベクタはコミットする。モデルの変更でベクタが変わったら、その差分を **必ずレビュー** する。
- 移植先ソースの出力からベクタを作ってはならない。
- 「今日」はベクタに明示する。実行時の日付に依存するベクタを作ってはならない。
- 移植元オラクルの値と `SourceModel` の値が一致しなければ、`SourceModel` 側の不具合とみなす。

## 証明の運用

- 未完の定理を `sorry` で残してはならない。未完のものは作業項目に残し、定理自体をコミットしない。
- 新規の `axiom` を追加してはならない。CI で `#print axioms` を確認する。
- `native_decide` は有限な具体値の確認だけに使い、主定理には使わない。
- 移植先の検証器の `assume` / `admit` 相当は原則として禁止する。やむを得ず使う場合は、場所と理由を具体化の課題一覧に列挙する。
