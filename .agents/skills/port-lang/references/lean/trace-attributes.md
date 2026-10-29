# Lean の追跡属性と trace-dump

追跡の考え方は [traceability.md](../traceability.md)。ここでは Lean 側の実装を定める。

## 属性

`Trace` 名前空間（どのモデルにも依存しない基盤）に、次の属性を定義する。
引数は文字列リテラルの並びとする。属性は環境拡張（`registerParametricAttribute` 等）に記録し、`trace-dump` が読み出せるようにする。

| 属性 | 付ける対象 | 引数 |
| --- | --- | --- |
| `@[source "<locator>@<hash>", …]` | `SourceModel`、移植元の `LangSemantics` の定義 | 移植元ロケータと検査済みの本文ハッシュ（`dep:`・`lang:` は版） |
| `@[target "<locator>@<hash>", …]` | `TargetModel`、移植先の `LangSemantics` の定義 | 移植先ロケータと検査済みの本文ハッシュ |
| `@[obligation "<ID>"]` | `Abstraction`・`Refinement` の主定理と補題、`Spec` 自身の証明課題の定理 | `ABS-NNN` / `REF-NNN` / `SPEC-NNN` |
| `@[deviation "<ID>"]` | 既知差異の前提の述語（前提型）、または貼り合わせ関係・出力の対応の成分（観測型） | `D-NNN` / `T-NNN` |
| `@[nondet "<ID>"]` | `Spec` の非決定性の選択の型（`Machine.ofChoice` の選択の型の葉） | `N-NNN` |
| `@[std_abs "<path>#<anchor>"]` | 標準の抽象化 α/β の部分写像（`Glue.ofStd` の β・aᵢ・aₒ と、その部品） | α・β の表の節 |
| `@[spec_doc "<path>#<anchor>"]` | `Spec` の公開定義 | 仕様文書の節 |
| `@[no_source "<理由>"]` | 移植元に対応の無い `Spec` の定義 | 理由 |

例:

```lean
@[source "java:com.example.FareService#basicFare(int,int)@9c1e…", "lang:java#JLS-15.17.1@java-21"]
def basicFare (routeFare extra : Int32) : JResult Int32 := ...
```

- 属性の付け忘れは検査 TR-S1 / TR-T1 で、ロケータの誤りは TR-R で、差異の付け忘れ・余分は TR-D で検出される。
- `@[nondet]` の付け忘れ・余分と、`@[std_abs]` の付け忘れは、TR-N・TR-G で検出される。
- `@[source]` / `@[target]` のハッシュは、決定論的な検査が合格したときに道具（`rehash`）が書き込む。手で書き換えてはならない（[traceability.md](../traceability.md#検査済みハッシュ)）。
- 移植元側の層に `@[target]` を、移植先側の層に `@[source]` を付けてはならない（TR-X）。

## trace-dump

`lake exe trace-dump` は、全定義について次を JSON で出力する。

```json
{
  "name": "TargetModel.Fare.basicFare",
  "layer": "TargetModel",
  "attributes": { "target": ["rust:app::fare::basic_fare@41d0…"] },
  "merkle": "77ab…",
  "references": ["LangSemantics.Rust.U64.add", "TargetModel.Fare.ratio"]
}
```

- `references`: 定義の型と本体に現れる定数。`Abstraction`・`Refinement` の定理については、これからモデル間の対応を自動導出する（どの `SourceModel` / `TargetModel` 定義がどの `Spec` 定義と結ばれているか）。
- `merkle`: 定義の型と本体の `Expr` のハッシュに、`references` のうち **同じ層と、その層が依存する `LangSemantics`・`Machine`** の定数の `merkle` を名前順に合成したもの。`LangSemantics` の変更でも、写しのハッシュがずれるようにするためである。依存する定義が変わっても値が変わる。循環参照（相互再帰）は、強連結成分ごとにまとめて計算する。
- ハッシュは処理系の内部表現に依存しうる。Lean の版を上げると、全定義の `merkle` が変わることがある。そのため版上げでは、移植先の写しを一括で再生成し、移植先の検証器を再実行する。
