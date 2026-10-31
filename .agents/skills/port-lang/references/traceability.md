# 両端の追跡（トレーサビリティ）

```
移植元ソース ⇔①⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔②⇔ 移植先ソース
```

- 追跡は ①（移植元ソース ⇔ `SourceModel`）と ②（`TargetModel` ⇔ 移植先ソース）の **2 本だけ** である。
- 内側は追跡ではなく **証明**（B メソッドのリファインメント。[architecture.md](architecture.md#リファインメントb-メソッド)）でつながる。
- 追跡は「どこがどこに対応するか」を示す。「一致すること」は、決定論的な検査で示す（[verification.md](verification.md)）。両者は検査済みハッシュで結びつく。
- 移植元ソースと移植先ソースを直接つないではならない。影響分析は証明グラフをたどって行う。
- ① と ② は同じ仕組みを使う。違いは、使う言語パック（移植元の言語か、移植先の言語か）と、注釈の名前（`@[source]` / `@[target]`）だけである。

## ロケータ

ソースの位置は、版に依存しない記号的なロケータで指す。行番号は道具が版ごとに解決し、permalink を生成する。

```
locator = kind ":" body
```

- `kind` と `body` の文法は言語パックの `locators.md` が定める（例: Java の `java:`、SQL の `sql:`、Rust の `rust:`）。言語パックのロケータは、その言語が移植元・移植先のどちらでも同じ文法で使う。
- 全言語共通の kind が 2 つある。

| kind | 形式 | 例 |
| --- | --- | --- |
| `dep` | `<パッケージ座標>#<シンボル>`（フレームワーク・ライブラリ） | `dep:org.springframework:spring-beans#StringTrimmerEditor.setAsText`, `dep:serde_json#from_str` |
| `lang` | `<言語>#<仕様の節>`（言語・処理系そのもの） | `lang:java#JLS-5.1.3`, `lang:rust#integer-overflow` |

- フレームワーク・処理系の挙動に依存するモデル定義は、`dep`・`lang` ロケータを **必ず** 含める。依存の版が変わると、影響する定義が自動で出る。

## 版の宣言とインベントリ

| ファイル | 内容 |
| --- | --- |
| `trace/upstream.json` | 移植元: repo・variant・release・commit、依存の版、言語・処理系の版 |
| `trace/target.json` | 移植先: ツールチェーン・検証器・依存の版 |
| `trace/source-inventory.json` | 移植元ソースを走査した、ロケータ・ファイル・行範囲・**正規化した本文ハッシュ** |
| `trace/target-inventory.json` | 移植先ソースを走査した、同じ形式の一覧 |
| `trace/manifest.json` | 全ノードと型付きのリンク（生成） |
| `trace/renames.json` | 版上げ時の、ハッシュで判別できない改名の対応（手書き） |
| `trace/checks.json` | `rehash` が実行する決定論的な検査と、それが覆うモデルの定義（手書き。検査を足すたびに登録する） |
| `trace/out-of-scope.json` | 追跡の対象外とするロケータと、根拠の意思決定記録（移植の範囲外としたもの。手書き） |

- インベントリの取り方（パーサ・正規化の規則）は言語パックの `locators.md` が定める。
- `dep`・`lang` の項目は、本文ハッシュの代わりに版文字列を持つ。

## 注釈（リンクの正はモデル側）

| 置き場所 | 注釈 | リンク |
| --- | --- | --- |
| `SourceModel`, 移植元の `LangSemantics` | `@[source "<ロケータ>@<検査済みハッシュ>", …]` | ① |
| `TargetModel`, 移植先の `LangSemantics` | `@[target "<ロケータ>@<検査済みハッシュ>", …]` | ② |
| 移植先ソース内のモデルの写し（例: Verus の spec 関数。生成物） | `trace: models <TargetModel の完全名> @<Lean Merkle ハッシュ>`（生成器が書く。書き方は言語パックの `layout.md`） | ②（逆向きの確認） |
| `Abstraction`, `Refinement` | `@[obligation "ABS-NNN" / "REF-NNN"]`。モデル間の対応は定理の型から自動導出する | 内側（証明） |
| 差異の述語・成分 | `@[deviation "D-NNN" / "T-NNN"]` | 内側（差異） |
| `Spec` | `@[spec_doc "<仕様文書#アンカー>"]`、`@[no_source "<理由>"]` | 文書 |
| ベクタ | `modelDef`, `upstream`（[conformance.md](conformance.md)） | テスト |

属性の定義と `trace-dump` は [lean/trace-attributes.md](lean/trace-attributes.md)。

### 検査済みハッシュ

注釈のハッシュは、**その版で、その定義を対象とする決定論的な検査が合格したこと** の記録である。対象となる検査は、ベクタの照合・オラクル・差分オラクル・検証器の証明・処理系の差分実行である。
現在の値とずれたら「要再検査」とし、検査を失敗させる。

- ハッシュの更新は道具（`rehash`）だけが行う。道具は、対象の定義にかかる決定論的な検査を実行し、すべて合格したときに限って書き換える。合格しなければ、モデルかソースを直す。
- 人や LLM の判断だけでハッシュを書き換えてはならない。
- 対象の定義を覆う検査が 1 つも無ければ、ハッシュは更新できない。先に検査を足す。
- どの検査が合格したかを、ソースの本文ハッシュとモデルの定義の Merkle ハッシュの組に対して manifest に記録する。どちらが変わっても再検査が必要になる。
- 写しのハッシュ（`trace: models`）は、生成器が書く。
- `renames.json` の改名の対応も、`rehash` が新しいロケータについて決定論的な検査を実行し、合格したときに限って受け入れる。
- 追跡の道具自身（パーサと本文の正規化）は、信頼の基盤である。正規化では、文字列リテラルの中身を保つ。

| 境界 | ずれる契機 |
| --- | --- |
| 移植元ソース → `SourceModel` | 移植元の版上げ、依存・処理系の版の変化 |
| 移植先ソース → `TargetModel` | 移植先ソースの変更 |
| `TargetModel` → 移植先ソース内の写し | Lean `TargetModel` の変更 |

### 直接接続の禁止

- 移植元側の層（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と、どちらの側にも属さない `Spec` に、移植先の言語のロケータ（移植先の言語パックが定めるすべての kind）を書いてはならない。
- 移植先側の層（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）と移植先ソースに、移植元の言語のロケータ（移植元の言語パックが定めるすべての kind）を書いてはならない。
- 同じ言語が移植元と移植先の両方になる場合（例: Java から Java への移植）は、ロケータにリポジトリの区別を付ける（`java@source:` / `java@target:`）。

### 対象外

- `out-of-scope.json` に載せてよいのは、移植の範囲外とする意思決定がされたものだけである。各項目に、その意思決定記録を書く。
- 移植の範囲外のソースでも、移植元モデルの振る舞いに影響するもの（既知差異の出所になるものなど）は、対象外にしてはならない。例: 画面テンプレートの書式処理。

## 検査

| ID | 失敗条件 |
| --- | --- |
| TR-S1 | スコープ内の `source-inventory` の項目が `@[source]` で覆われず、`out-of-scope.json` にも無い |
| TR-S2 | `@[source]` のハッシュが `source-inventory` と一致しない。または、定義の Merkle ハッシュが最後に検査が合格したときから変わっている（モデル側だけを直した場合も再検査を求める） |
| TR-T1 | `TargetModel` の公開定義に `@[target]` が無い。または `target-inventory` の公開項目が覆われず、対象外でもない。生成した写しは対象外とする（再生成と TR-T2 で確かめる） |
| TR-T2 | `@[target]` のハッシュが `target-inventory` と、写しのハッシュが Lean の Merkle ハッシュと一致しない。または、定義の Merkle ハッシュが最後に検査が合格したときから変わっている |
| TR-P | `SourceModel` の公開操作が、どの R 課題（`Abstraction`）の定理にも現れない。または、`TargetModel` の公開操作が、どの R 課題（`Refinement`）の定理にも現れない。例外は無い |
| TR-PE | `SourceModel`・`TargetModel` の公開操作が、どの **入口の** R 課題の具体機械（定義の参照の閉包）にも含まれない。入口でない R 課題（ポート実装・内部の計算）だけに現れる操作は、入口からの到達が示されていない |
| TR-D | 次のどれかに当たる。<br>- 登録簿の前提型・観測型の差異（`D-NNN` / `T-NNN`）と `@[deviation]` が 1 対 1 でない<br>- `@[deviation]` が、どの R 課題の定理の型にも現れない<br>- 差異に W 課題が無い<br>- R 課題の定理に、`@[deviation]`・PRE・INV 以外の仮定がある |
| TR-G | R 課題（型の結論が `Machine.Refines` の `@[obligation]` 定理）が、空虚化を防ぐ形と付帯の義務（[architecture.md](architecture.md#空虚化を防ぐ義務)）を備えていない。判定する規則は次の 10 個である。<br>- G0: 追跡属性を付けた定数がモデルの層にある。`Refines` を含む課題の結論が `Refines` か、必要性の形（G9）である<br>- G1: 型が閉じている<br>- G2: 制限の述語が `@[deviation]` の定数そのもので、基底が名前付きの定数<br>- G3: 抽象側の基底（と `Spec` のすべての機械）が `ofChoice`/`pure` で、選択の型の葉が `@[nondet]`。自由な選択には `FreeFrame`<br>- G4: 具体側の基底が `Dom` を設定せず、`toConcrete` と `Spec` の関数を参照しない<br>- G5: 貼り合わせが `Glue.ofStd` の形で、β・aᵢ・aₒ が `@[std_abs]` の定数そのもの、OJ・OO が `never` か `@[deviation]` の定数そのもの<br>- G6: `InitSurj`・基底の `Sound`・`InitIs`、`ofChoice` なら `Pinned`（`ce` は `@[std_abs]`）と `NoFaultReachable` がある（式全体で照合する）<br>- G7: `@[std_abs]` が 1 引数の関数で、核の定理（K は等号か `@[kernel]`）のある葉か、許可した構成の合成である。aₒ と `FreeFrame` の射影は核の定理を持つ<br>- G8: `@[deviation]`・`@[env_pre]` に `Nontrivial` がある<br>- G9: R 課題で使う `@[deviation]` に、それを外した R 課題の命題の否定（基底が `ofChoice` なら `¬ (Refines ∧ Pinned)`、`pure` なら `¬ Refines`）が、少なくとも 1 つの R 課題についてある。`TotalUnder` で使う `@[env_pre]` に、その機械の `¬ TotalUnder A always` がある<br>あわせて、文書と次を照合する。<br>- 環境・自由の種類<br>- 種類 R の課題の形<br>- 入口の R 課題の `TotalUnder`（`@[env_pre]`）と `EnvWitness`<br>- 「出力のみ」の差異の `StateSafe`<br>- 前提型の差異の影響の登録<br>- `@[deviation]` の登録 |
| TR-N | 登録簿の `Spec` の非決定性（`N-NNN`）と `@[nondet]` が 1 対 1 でない |
| TR-V | 適合テストベクタのうち、次のどれかを満たさないものに、外に落ちる理由のラベルが無い。または、ラベルがあるのに外に落ちない。<br>- 具体側の定義域<br>- 具体側の不変条件<br>- 基底の PRE<br>- 制限した PRE（差異の前提）<br>ラベルは差異 ID か `PRE`・`INV` で、付け方は [conformance.md](conformance.md) による |
| TR-X | 直接接続の禁止に違反している |
| TR-R | 存在しない Lean 名・ロケータ・課題 ID・差異 ID への参照がある |

段階導入（TR-G・TR-N）: 登録簿（非決定性・入口の R 課題・前提型の差異の影響）の各行に、Lean 側を整える作業項目を書く。その項目が完了するまでは「登録簿にあって Lean にまだ無い」ことを警告にし、完了したら失敗にする。

段階導入: TR-S1・TR-T1・TR-P・TR-D を警告にしてよいのは、該当する機能の作業項目が完了していない間だけである。完了を宣言する時点で、その機能について全検査が失敗扱いで通っていなければならない。他の検査は最初から失敗とする。

## 道具

専用の CLI（例: `tools/trace/`）に次の機能を持たせる。言語ごとの部分（パーサ）は言語パックの `locators.md` に従う。

| サブコマンド | 機能 |
| --- | --- |
| `inventory source` / `inventory target` | インベントリの生成 |
| `ingest-lean` | `lake exe trace-dump` の出力の取り込み（`manifest`・`check` の入力として渡してもよい） |
| `manifest` | manifest と、仕様文書の生成区画（① と ② の 2 本の表）の生成 |
| `check` | TR 検査 |
| `rehash` | 決定論的な検査を実行し、合格した定義だけハッシュを更新する |
| `diff` | 新旧インベントリの分類（[upgrade.md](upgrade.md)） |
| `impact` | 証明グラフに沿った影響一覧 |

既定の細部（プロジェクトの ADR で変えてよい）:

- 本文ハッシュは、正規化した本文の SHA-256 の先頭 16 桁（Lean の Merkle ハッシュと同じ長さ）とする。
- 正規化は、構文解析器のトークン列（コメントを除く）を空白 1 つでつないだものとする。空白の違いは無視し、文字列リテラルの中身は保つ。
- 注釈の `"<ロケータ>@<ハッシュ>"` は、最後の `@` で分ける（ロケータ自身が `@` を含むことがあるため）。
- 段階導入の「機能」は、機能ごとに作業項目・ロケータの glob・モデルの名前空間・R 課題を並べた対応表で決める。どの機能にも属さない項目は失敗とする（表の抜けで指摘が消えないように）。
- 検査の登録（`checks.json`）は、検査ごとに実行するコマンドと、覆う定義（名前の glob と、ベクタの `modelDef` から参照をたどって届く定義）を持つ。終了コードが 0 なら合格とする。処理系が無くて飛ばした場合は不合格とする。
- `rehash` は、定義のモジュールのファイルの中で、注釈の文字列 `"<ロケータ>@<旧>"` を置き換える（`trace-dump` が定義のモジュールを出力する）。同じ文字列を注釈に持つ定義が同じモジュールに複数あれば、すべてが合格したときだけ置き換える。合格した組は manifest に記録する。
- 仕様文書の「出典:」に書いたロケータは、インベントリになければ失敗とする。private のメソッドはインベントリの単位ではないので、呼び出し元の公開メソッドで書く。
- 「R 課題に現れる」（TR-P・TR-PE）は、R 課題の定理から参照をたどって届く定義の集合に含まれることとする。

生成区画は `<!-- BEGIN GENERATED: source-trace -->` / `<!-- END GENERATED: source-trace -->`（② は `target-trace`）で区切る。区画の中を手で編集してはならない。
