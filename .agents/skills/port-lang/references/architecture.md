# 構成: 層・名前空間・依存・正規性

## 全体像

```
移植元ソース ⇔①⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔②⇔ 移植先ソース
```

- ① と ② は **追跡**（ソースとモデルの対応。[traceability.md](traceability.md)）。
- `Abstraction` と `Refinement` は **証明**（モデル間の関係）。
- 移植元ソースと移植先ソースを直接つないではならない。

## 層

モデルと証明はすべて Lean に置く。Lean のトップレベル名前空間は次の 6 つだけとする。例外は 3 つで、追跡属性の基盤 `Trace` と、実行ファイル用の `Tests`・`Tools` である。

| 名前空間 | 日本語名 | 内容 | 文書上の記号 |
| --- | --- | --- | --- |
| `LangSemantics.<lang>` | 言語意味論モデル | アプリに依存しない、言語・処理系の基本型と基本演算の意味。`<lang>` は UpperCamelCase（`Java`, `Sql`, `Rust` …） | — |
| `SourceModel` | 移植元モデル | 移植元ソースの観測可能な振る舞いを、移植元言語の意味論ごと写す。不具合も再現する | **[Source]** |
| `Spec` | 抽象モデル | 意図された業務規則。言語中立で、実行可能。**正規仕様** | **[Spec]** |
| `Abstraction` | 抽象化証明課題 | `SourceModel` → `Spec` の定理 | `ABS-NNN` |
| `TargetModel` | 移植先モデル | 移植先ソースの振る舞いを、移植先言語の意味論で写す | **[Target]** |
| `Refinement` | 具体化証明課題 | `Spec` → `TargetModel` の定理 | `REF-NNN` |

- 下位の名前空間は、層をまたいで同じ機能名を使う（`SourceModel.Fare` / `Spec.Fare` / `Abstraction.Fare` / `TargetModel.Fare` / `Refinement.Fare`）。
- 移植先言語が複数ある場合は、`TargetModel.<lang>` / `Refinement.<lang>` と言語で分ける。移植元が複数ある場合も同様に分ける。

## 依存の向き

| モジュール | 依存してよいもの |
| --- | --- |
| `Trace` | なし |
| `LangSemantics.<lang>` | 同じ `<lang>`、`Trace` |
| `Spec` | `Spec`、`Trace` |
| `SourceModel` | `LangSemantics.<移植元>`、`Spec`（型の再利用）、`Trace` |
| `Abstraction` | `SourceModel`、`Spec`、`LangSemantics.<移植元>`、`Trace` |
| `TargetModel` | `LangSemantics.<移植先>`、`Spec`（型の再利用）、`Trace` |
| `Refinement` | `TargetModel`、`Spec`、`LangSemantics.<移植先>`、`Trace` |

**移植元側（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と移植先側（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）は互いに依存してはならない。** CI で検査する。

## 二層化の理由

移植元ソースには、意図とは異なる偶発的な振る舞いがあることが多い。例は次のとおり。
- 浮動小数点による料金の丸め誤差
- 文字列長の単位（UTF-16）
- SQL の `ORDER BY` で同順位の行の並び
- フレームワークの不具合による検証の抜け

これらを `Spec` に入れると、全移植先にその偶発性を強いることになる。そこで次のように分ける。

- `SourceModel` は偶発性ごと再現する（移植元オラクルで確認できる）。
- `Spec` は意図を表す。
- 差は既知差異 `D-NNN` として記録する。`Abstraction` で次の 3 種類の定理を証明する。
  1. **一致**: 前提 P の下で `α(Source(x)) = Spec(α(x))`
  2. **差異の特徴付け**: 一般の入力での差の向きと大きさ
  3. **安全性**: 前提の下で、移植元の固定長整数の溢れや前提違反が起きない

移植先側も対称にする。`Refinement` で `β(Target(x)) = Spec(β(x))` と、移植先固有の安全性（溢れ・パニックが無い）を証明する。

## 抽象化関数

| 関数 | 写す向き | 例 |
| --- | --- | --- |
| α | `SourceModel` の値 → `Spec` の値 | int32 → 整数、double → 有理数、UTF-16 文字列 → スカラ値の列、null 可能参照 → `Option`、例外 → エラー値、SQL の許される結果の集合 → 列（一意な場合だけ） |
| β | `TargetModel` の値 → `Spec` の値 | `u64` → `Nat`、UTF-8 文字列 → スカラ値の列、`Result` → `Except`、パニック → 未定義 |

非決定的な移植元の結果（例: 未規定の並び順）は「許される結果の集合」として表し、一致定理は「集合のすべての要素が α で同じ値に写る」形にする。

## 正規性の序列

1. Lean の `Spec`（型・関数・定理）
2. 仕様文書の **規範** 節（`Spec` で表現できない仕様）
3. 適合テストベクタ（モデルを実行して生成する）
4. `SourceModel` / `TargetModel` と、それぞれのソース
5. 移植元ソース（`SourceModel` を確かめるためのオラクル）

`Spec` と矛盾する文書・ベクタ・ソースは、`Spec` を正として直す。`Spec` 自体を変えるのは、業務の意図が変わるときだけである（変更の記録はプロジェクトの意思決定記録で行う）。

## 関数型コアとポート

- 業務ロジックは純粋関数として `Spec` に書く。マスタ・設定・「今日」は引数で受け取る。
- 時刻・永続化・採番・ハッシュ・ファイル・キューはポートとする（`Spec.Port` に関数レコード over `Monad m` として定義）。
- ユースケースは抽象状態 `World` 上の状態遷移として意味を与え、原子性・直列化可能性の要件は仕様文書の規範節に書く。
- エラーは値（直和型）で返す。移植元の安定したエラーコード（メッセージキー等）があれば、それをコードとして使う。
