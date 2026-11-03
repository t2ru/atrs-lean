---
type: Specification
title: "構成: 層・名前空間・依存・リファインメント・正規性"
description: "層・Lean の名前空間・依存の向き・B メソッドのリファインメントと証明課題・空虚化を防ぐ義務・正規性の順位。"
tags: [architecture, refinement]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# 構成: 層・名前空間・依存・リファインメント・正規性

## 全体像

```
移植元ソース ⇔①⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔②⇔ 移植先ソース
```

- ① と ② は **追跡** と **決定論的な一致の確認** である。追跡はソースとモデルの対応を指す。一致の確認には、検証器・生成・原典実行・ベクタを使う（[traceability.md](traceability.md)、[verification.md](verification.md)）。
- `Abstraction` と `Refinement` は **証明** である。どちらも、モデルが `Spec` を B メソッドの意味でリファインすることを示す（[下記](#リファインメントb-メソッド)）。
- 移植元ソースと移植先ソースを直接つないではならない。

## 層

モデルと証明は、すべて Lean に置く。Lean のトップレベル名前空間は、次の 6 つだけとする。例外は 4 つある。
- `Machine`: 抽象機械とリファインメントの枠組み。アプリに依存しない
- `Trace`: 追跡属性の基盤
- `Tests`・`Tools`: 実行ファイル用。スキルの assets の検査は `Test.<ライブラリ>` に置き、`Tests` と同じ層として扱う（[ADR c08b](../decision/c08b-test-namespace-for-skill-asset-tests.md)）

| 名前空間 | 日本語名 | 内容 | 文書上の記号 |
| --- | --- | --- | --- |
| `LangSemantics.<lang>` | 言語意味論モデル | アプリに依存しない、言語・処理系の基本型と基本演算の意味。`<lang>` は UpperCamelCase（`Java`, `Sql`, `Rust` …） | — |
| `SourceModel` | 移植元モデル | 移植元ソースの観測可能な振る舞いを、移植元言語の意味論ごと写す。不具合も再現する | **[Source]** |
| `Spec` | 抽象モデル | 意図された業務規則。言語中立で、実行可能な抽象機械。**正規仕様** | **[Spec]** |
| `Abstraction` | 抽象化証明課題 | `SourceModel` が `Spec` をリファインする定理 | `ABS-NNN` |
| `TargetModel` | 移植先モデル | 移植先ソースの振る舞いを、移植先言語の意味論で写す | **[Target]** |
| `Refinement` | 具体化証明課題 | `TargetModel` が `Spec` をリファインする定理 | `REF-NNN` |

- 下位の名前空間は、層をまたいで同じ機能名を使う（`Spec.Fare` / `Abstraction.Fare` / `TargetModel.Fare` / `Refinement.Fare`。`SourceModel` は原典のソースツリーの形に並べ、機能の具体機械を `SourceModel.<機能>` に置く。言語パックの `layout.md`）。
- 宣言はモジュール名の下に置き、機能の証明課題は機能のモジュールに、補題は下位のモジュールに置く（[lean/rules.md](../lang/lean/rules.md#モジュールと名前空間)、[ADR 1a30](../decision/1a30-lean-module-namespace-layout.md)）。
- 移植先言語が複数ある場合は、`TargetModel.<lang>` / `Refinement.<lang>` と言語で分ける。移植元が複数ある場合も同様に分ける。

## 依存の向き

| モジュール | 依存してよいもの |
| --- | --- |
| `Trace` | なし |
| `Machine` | なし |
| `LangSemantics.Core` | なし（core だけ） |
| `LangSemantics.<lang>` | 同じ `<lang>`、`LangSemantics.Core`、`Trace` |
| `Spec` | `Spec`、`Machine`、`Trace` |
| `SourceModel` | `LangSemantics.<移植元>`、`LangSemantics.Core`、`Spec`（型の再利用）、`Machine`、`Trace` |
| `Abstraction` | `SourceModel`、`Spec`、`LangSemantics.<移植元>`、`LangSemantics.Core`、`Machine`、`Trace` |
| `TargetModel` | `LangSemantics.<移植先>`、`LangSemantics.Core`、`Spec`（型の再利用）、`Machine`、`Trace` |
| `Refinement` | `TargetModel`、`Spec`、`LangSemantics.<移植先>`、`LangSemantics.Core`、`Machine`、`Trace` |
| `ConformanceKit`（メタ層） | `LangSemantics`（どの言語も） |

**移植元側（`SourceModel`, `Abstraction`, 移植元の `LangSemantics`）と移植先側（`TargetModel`, `Refinement`, 移植先の `LangSemantics`）は、互いに依存してはならない。** CI で検査する。

## 二層化の理由

移植元ソースには、意図とは異なる偶発的な振る舞いがあることが多い。例は次のとおり。
- 浮動小数点による料金の丸め誤差
- 文字列長の単位（UTF-16）
- SQL の `ORDER BY` で、同順位の行の並び
- フレームワークの不具合による検証の抜け

これらを `Spec` に入れると、全移植先にその偶発性を強いることになる。そこで次のように分ける。

- `SourceModel` は、偶発性ごと再現する（原典実行で確認できる）。
- `Spec` は意図を表す。
- 差は既知差異 `D-NNN` として記録し、リファインメントの定理の中に名前付きで出す（[差異](#差異)）。

移植先側も対称にする。`TargetModel` と `Spec` の差は、既知差異 `T-NNN` とする。

## リファインメント（B メソッド）

### 抽象機械

`Spec` の各機能を、抽象機械として与える。

| 要素 | 内容 |
| --- | --- |
| 状態 σ | ユースケースは抽象状態 `World`。マスタ・設定は不変の入力とし、`World` に含めない。純粋な計算は、状態を変えない操作とみなす |
| 不変条件 INV | `World` の不変条件（在庫などの非負性）。マスタ・設定の制約は PRE に含める |
| 初期化 INIT | 初期状態の集合 |
| 操作 | 入力 ι、事前条件 PRE、事後の関係 `step : σ → ι → σ → ο → Prop`（非決定性を許す）、出力 ο |

- `Spec` は実行可能でなければならない。各操作に、関係 `step` と実行可能な **標準の選択** `run` を与え、`PRE → step s i (run s i)` を証明する。ベクタは `run` から生成する。
- `Spec` 自身の証明義務は次の 2 つである。
  - 初期化が INV を満たす。
  - PRE の下の操作が INV を保つ。
- 抽象化の課題一覧には、`Spec` 自身の証明課題（`SPEC-NNN`）として、少なくとも次を載せる。R 課題が INV を仮定してよいのは、これらが証明されているからである。

  | 課題 | 内容 |
  | --- | --- |
  | 標準の選択 | 各操作で、PRE の下の標準の選択 `run` の結果が、関係 `step` に含まれる |
  | 初期化 | 初期化（fixture の投入後の状態）が INV を満たす |
  | INV の保存 | PRE の下の各操作（環境の非決定性に固有の結果を含む）が INV を保つ |
  | 選択の像 | 各機能の基底の機械は `Machine.ofChoice` か `Machine.pure` で作り、選択の型の葉は登録した `@[nondet]` の型だけとする。自由な選択には `FreeFrame` を示す（TR-G で検査する） |
  | 入口の全域性 | 入口の R 課題の機械は、INV と環境の前提（`@[env_pre]`）の下で PRE が成り立つ（`TotalUnder`）。環境の前提には両向きの例と、外すと PRE が成り立たない入力があることを示す |
  | 初期状態 | 各機能の初期状態は 1 点である（`Machine.InitIs`） |
  | 標準の環境 | 標準の環境の下では、`f` が環境の非決定性に固有の結果を返さない |

  アプリ固有の性質（例: 衝突の結果で採番以外の状態が変わらない）は、プロジェクトが足す。
- 移植先の固定長整数に収まるよう値域を定める場合は、値域を PRE に含める。

### 具体機械とリファインメント

`SourceModel`・`TargetModel` の各機能を具体機械とし、次を与える。
- 貼り合わせ不変条件 `J : σ → τ → Prop`（抽象化関数 α/β を含む関係）
- 入力の対応 `αᵢ`
- 出力の対応 `αₒ`

| 証明義務 | 内容 |
| --- | --- |
| INIT | 具体側の任意の初期状態 t について、`J s t` を満たす抽象側の初期状態 s がある |
| 入力の全域性 | 具体側の任意の入力に `αᵢ` の像がある（前提型の差異で名前を付けて除外したものを除く）。これが無いと、像を持たない入力について他の義務が空虚に成り立つ |
| 適用可能性 | `INV s ∧ J s t ∧ αᵢ i_c i ∧ PRE s i` の下で、具体側の操作は結果を持ち、どの結果も正常終了である。正常終了でないものは、パニック・前提違反・算術の溢れによる誤り（溢れを誤りとする言語）・NaN・α/β の未定義である。業務エラー（例外として投げられ、α/β でエラー値に写るもの）は正常な結果に含まれる |
| 正しさ | 同じ仮定の下で、具体側の任意の正常終了 `(t', o_c)` について、`step s i s' o ∧ J s' t' ∧ αₒ o_c o` を満たす `(s', o)` がある |

- 具体側に非決定性があってもよい（例: 未規定の並び順）。ただし、正しさの義務は、具体側の **すべての** 分岐で成り立たなければならない。抽象側の非決定性は、具体側で減らしてよい。
- **具体側が抽象側より大きな非決定性を持ってはならない**。例: 順序不定の結果を、定順の `Spec` と比べる場合がこれに当たる。そうなる場合は、出力の対応を名前付きの差異成分（観測型）として明示する。
- PRE の外での具体側の振る舞いには、義務が無い。これは差異ではない。ただし、`Spec` がその入力に振る舞いを定めている場合は PRE の内である。
- 汎用の定義（`Machine.Machine`、`Machine.Refines`、各証明義務）は、`assets/lean/Machine/` に置く。`Machine` は core だけに依存する。

`Machine.Refines` は、B メソッドのリファインメントの証明義務を、入出力の対応 αᵢ・αₒ で一般化したものである（B refines A）。
B の記法では、M（INVARIANT I）を M'（INVARIANT J）がリファインし、操作 `PRE P THEN S` を `PRE P' THEN S'` にリファインする。

| B の証明義務 | 式 | `Refines` の成分 | 対応 |
| --- | --- | --- | --- |
| 初期化 | `[Init'] ¬[Init] ¬J` | `init` | 一致 |
| 操作: 事前条件 | `I ∧ J ∧ P ⇒ P'` | `applicable` の「どの結果も正常終了」 | 一致。`Concrete.ofMachine` が PRE の違反を誤りに写すので、「誤りにならない」が「P' が成り立ち、abort しない」に当たる |
| 操作: 停止 | `[S'] R` の trm(S') | `applicable` の「結果を持つ」 | 一致（やや強い）。wp の意味論では、奇跡（結果の無い S'）が義務を空虚に満たす。B は、実装（B0）が実行可能な代入だけを使うことでこれを排除する。具体機械は実装のモデルなので、結果を持つことを要求する |
| 操作: 正しさ | `I ∧ J ∧ P ⇒ [S'] ¬[S] ¬(J ∧ out' = out)` | `correct` | 一致 |
| （入力は同じ名前・型） | — | 入力の全域性と αᵢ・αₒ | 一般化。αᵢ・αₒ が等号なら B と同じ。入力の全域性は、像を持たない、制約の無い具体側の入力を生まないための条件である（B では入力が同一なので、自動的に成り立つ） |
| 抽象機械の無矛盾性 | M 自身の義務 | `Machine.Sound`（`Refines` の外） | B でもリファインメントの義務ではない |

`Refines` には、B に無い義務を足さない。空虚化を防ぐ義務（`Pinned`・`StateSafe` など）は、次節の `Machine.Preserves` に置く（[ADR 6b4b](../decision/6b4b-preserves-refines-abstracts.md)）。

### 空虚化を防ぐ義務

`Refines` が保証するのは「具体側の振る舞いが、抽象側の許す範囲に収まる」ことだけである。そのため、次の場合にも空虚に、または自明に成り立ってしまう。

- 抽象側の `step` が緩い（例: `True`）
- PRE が強すぎる（例: `False`）
- `αᵢ` が PRE の外へ写す
- `J`・`αₒ` が粗い
- 名前付きの成分が `True`・`False` である
- 名前付きの成分が要らない（外しても成り立つ。実在しない差異）
- 具体側の不具合が、抽象側の環境の非決定性（衝突・I/O の失敗）に紛れる

これを塞ぐため、次を課す。R 課題ごとの意味的な義務は、束 `Machine.Preserves`（A preserves B）にすべて入れる。`Preserves` は `Refines` を含まない。
両者の組が `Machine.Abstracts`（**A abstracts B = A preserves B ∧ B refines A**）である。`Abstracts` は B のリファインメントより厳密に強い（`Abstracts` ⇒ B refines A。逆は成り立たない）。
定義は `assets/lean/Machine/` の `Preserves`（`Machine.Preserves.Pred`・`Machine.{Machine,Glue,Refines}.Preserves`）と `Abstracts` にある（[ADR 6b4b](../decision/6b4b-preserves-refines-abstracts.md)）。

| 対象 | 義務 | Lean |
| --- | --- | --- |
| 抽象機械の形 | 基底の機械は、選択の像として作る。`step s i s' o ↔ ∃ c, f s i c = (s', o)`、`run s i = f s i (e₀, f₀)`。選択の型は環境の選択 E（衝突・I/O の失敗・配備の設定）と自由な選択 F（ハッシュ値など）の組で、葉の型に `@[nondet "N-NNN"]` を付け、種類（環境・自由）とともに登録簿に載せる。決定的な純粋計算は `Machine.pure` でよい | `Machine.ofChoice` |
| 自由な選択の枠 | 自由な選択が変えうる部分を、射影の核として示す | `Machine.FreeFrame` |
| 不変条件と初期化 | 基底の機械は `Sound` で、初期状態は fixture の 1 点である（INV が空にならない） | `Machine.Sound`・`Machine.InitIs` |
| 環境の固定 | 具体側も、環境（障害・衝突・配備の設定）とマスタ・設定を入力の成分として受ける。具体側の正常終了は、具体側の入力の環境の記述 `ce i_c` が許す環境の選択（`adm (ce i_c) e`）の `f` の結果で模倣される。`ce` は `@[std_abs]` の標準の抽象化、`adm` は `Spec` の層の定数か等号 `Machine.Preserves.sameEnv`（E を `ce i_c` に固定する）とする。障害の位置を具体側の入力が持ち、障害が実際に起きるかと起きるまでに進んだもの（採番など）が実行で決まるときは、`adm` で、障害の指定の無い成分には標準の選択だけを許す（[ADR 61e6](../decision/61e6-env-relation-and-state-env-pre.md)） | `Refines.Pinned` |
| 障害の無い環境での実現 | 抽象側の各入力は、`ce` が障害の指定の無い記述 `d₀` を返す具体側の入力でも実現される。`d₀` が許すのは標準の選択 `e₀` だけで、障害の無い環境では環境の非決定性を選べない | `Refines.NoFaultReachable`・束の `noFaultStd` |
| 貼り合わせの形 | `J`・`αᵢ`・`αₒ` は、標準の抽象化の **部分写像** β・aᵢ・aₒ（`Option` を返す。`none` は α/β の未定義）、具体側の不変条件 `Ic`、観測型の差異の成分 OJ・OO だけから作る。β・aᵢ・aₒ・OJ・OO には、属性を付けた定数そのものを渡す。補助定義で包まない | `Glue.ofStd` |
| 標準の抽象化 | 1 引数の関数とする。葉（α・β の表の行）には核（同一視するもの。等号か `@[kernel]` の関係）を定理で示す。定義域の上で単射な部分写像の核は、汎用の核 `Machine.Kernel.undefOrEq`（「どちらも定義されないか、等しい」。assets の `Machine.Kernel`）か汎用の `@[kernel]` の関係を、その葉自身に適用して書いてよい（`KernelIs f (Machine.Kernel.undefOrEq f)`。`kernelIs_undefOrEq` で示せる）。合成は、葉・構成子・射影・インスタンス・`Option.map/bind`・`List.map/mapM`・`Prod.map`・`Function.comp`・`id` だけで作り、分岐を含めない。aₒ と `FreeFrame` の射影には核の定理を課す | `KernelIs`、`Machine.Kernel.undefOrEq`、`@[std_abs]`、`@[kernel]` |
| 入口の全域性 | 外部からの入力を受ける入口の機械（画面・API・キューの受信など）では、INV と環境の前提（マスタ・設定の妥当性と入力の値域。入力の成分だけで書いた `@[env_pre]` の定数）の下で PRE が成り立つ。環境の前提は状態と入力の述語で、状態とマスタの対応（外部キー）や状態の前提も書ける。初期状態で環境の前提を満たす像を持つ具体側の入力がある（[ADR 61e6](../decision/61e6-env-relation-and-state-env-pre.md)） | `Machine.TotalUnder`・`Refines.EnvWitness` |
| 初期化 | 抽象側の初期状態に、対応する具体側の初期状態がある | `Refines.InitSurj` |
| 名前付きの成分 | 差異の述語・成分と環境の前提は、成り立つ例と成り立たない例を持つ（W 課題を両向きにする） | `Nontrivial`・`Nontrivial₂` |
| 成分の必要性 | R 課題で使う差異の ID ごとに、その差異を外した R 課題の命題が偽であることを示す（W 課題に含める）。<br>- 前提型: `restrict` の層を外す<br>- 観測型: 成分を `never` に替える（重なる観測型の差異は `anyOf` で並べ、葉ごとに替える）<br>- 否定する命題: `Refines`。基底が `ofChoice` なら `Refines ∧ Pinned`（束の `ce`・`adm`）でもよい（`Refines` だけでは、環境の非決定性が不具合を模倣して偽にならないことがある）<br>少なくとも 1 つの R 課題について示す。他の必要な差異 M に覆われる差異は、同じ R 課題で `Covers M d` を示す。差異の定数には ID を 1 つだけ付ける。環境の前提には、前提なしでは PRE が成り立たないこと（`¬ TotalUnder A always`）を示す。PRE が全域な機械は、環境の前提を置かず `TotalUnder A always` を示す | `always`・`anyOf`・`Covers`、`Refines.not_of_error`・`not_of_stuck`・`not_of_mismatch`・`Pinned.not_of_mismatch`、`Machine.TotalUnder.not_always` |
| 差異の前提の外の 1 歩 | 前提型の差異を「出力のみ」と「中断」に分けて登録する。出力のみの差異では、前提を破る 1 歩の後も状態は `J` を保つ。中断の差異では、前提を破った後の軌跡に保証が無く、保証の限界の文書に載せる | `Refines.StateSafe`・`StateSafeConcrete` |
| 同語反復の禁止 | 具体機械は `Concrete.ofMachine` と `Spec` の関数（型・構成子・射影・インスタンス以外）を参照しない | — |
| 束 | R 課題ごとに、上の義務のうち意味的なもの（下の表）を 1 つの主張 `Preserves A C g s₀ Env ch outs outsC` に束ね、R 課題と同じ課題 ID・同じ A・C・g の `@[obligation]` で示す。`Refines` は含めない。入口でない R 課題にも課す（環境の前提は、マスタ・設定の妥当性と入力の値域・差異の前提を、抽象側の入力の成分だけで書いた述語でよい。`@[env_pre]` は入口の機械に限る） | `Machine.Preserves`、`Machine.Abstracts` |

束 `Preserves` の成分は次のとおりである。条件付きの成分は、引数 `ch`（基底が `ofChoice` なら選択の像の材料 `some (Choice.mk E F P f ce e₀ m)`、`pure` なら `none`）と `outs`・`outsC`（「出力のみ」の差異の層 `⟨base, P⟩`）で渡す。当たらないとき（`none`・`[]`。既定値）は既定の証明で閉じる。

| 成分 | 条件 | 向き | 意味 | 塞ぐもの |
| --- | --- | --- | --- | --- |
| `sound` | 常に | 抽象のみ | 抽象側の INV が初期化で成り立ち、PRE の下の歩みで保たれる | 不健全な INV |
| `initIs` | 常に | 抽象のみ | 初期状態は fixture の 1 点（`sound` と合わせて、INV が空でない） | 仮定 INV が空で、Refines が空虚に成り立つこと |
| `initSurj` | 常に | 抽象→具体 | 抽象側の各初期状態に、`J` で結ばれる具体側の初期状態がある（`Refines` の INIT の逆向き） | 具体側の初期状態が空であること |
| `total` | 常に | 抽象のみ | INV と環境の前提（状態と入力の述語）の下で PRE が成り立つ | 強すぎる PRE |
| `envWitness` | 常に | 抽象→具体 | 初期状態で環境の前提を満たす抽象側の入力が、具体側の定義域の入力の像として実現される | αᵢ が PRE・環境の前提の外へ写すこと、定義域が空であること |
| `envNeeded` | 常に | 抽象のみ | 環境の前提は、置かないか、無ければ PRE が成り立たない | 不要な前提で主張の範囲を狭めること |
| `pinned` | 基底が `ofChoice` | 具体→抽象（模倣を絞る） | 具体側の正常終了は、環境の記述 `ce i_c` が許す（`adm`）環境の選択の `f` の結果で模倣される（`correct` より強い。B には無い） | 環境の非決定性が具体側の不具合を吸収すること |
| `noFault` | 基底が `ofChoice` | 抽象→具体 | 抽象側の入力の各像は、環境の記述が障害の指定の無い `d₀` の具体側の入力でも実現される | `ce` の悪用 |
| `noFaultStd` | 基底が `ofChoice` | 抽象のみ | 障害の指定の無い記述 `d₀` が許す環境の選択は、標準 `e₀` だけ | `adm` が障害の無い環境でも障害の選択を許すこと |
| `freeFrame` | 基底が `ofChoice` | 抽象のみ | 自由な選択が変えうるのは、射影 `m` が忘れる部分だけ | 自由な選択による結果の吸収 |
| `stateSafe`・`stateSafeC` | 「出力のみ」の差異ごと | 具体→抽象（模倣を広げる） | 差異の前提を破る入力でも、具体側の正常終了の後の状態は `J` を保つ | 差異の前提の外の 1 歩が状態を壊すこと |

`Abstracts` の外に残る義務は、課題をまたぐもの、定数ごとのもの、構文の条件である。obligation-check と文書の照合が扱う。

| 義務 | 規則 | 外に残す理由 |
| --- | --- | --- |
| 差異の必要性 | G9（W 課題） | 差異 ID ごとに、少なくとも 1 つの R 課題について課す。`Refines` の否定を含む |
| `Nontrivial`（`@[deviation]`・`@[env_pre]`）、`KernelIs`（`@[std_abs]` の葉、`Choice.m`） | G8・G7・G3 | 定数ごとの義務。核が等号か `@[kernel]` であることは構文の条件 |
| `ch`・`outs` が R 課題の構造に合うこと | G6 | 基底と「出力のみ」の区別は、構文と登録簿で決まる |
| 形と配置（閉じた型、`@[deviation]` の定数そのもの、`Glue.ofStd`、`ofChoice`/`pure`、同語反復の禁止、NS-1） | G0〜G5・G7、layout-check | 構文の条件 |
| `Spec` 自身の課題 | SPEC-NNN | 抽象機械だけの義務 |

- 具体側の状態の述語を前提とする差異は、`J` で対応する抽象側の状態の述語に書き直して `restrictState` で置く。
- 具体側の不変条件 `Ic` は仮定ではない。初期化で成り立ち、正しさの義務で `J` とともに保たれることを示すので、到達可能な状態についての証明済みの不変条件である。
- 標準の環境の下で、`f` が環境の非決定性に固有の結果（衝突・I/O の失敗）を返さないことを、`Spec` 自身の課題として示す。
- `Abstracts` から、1 歩の可換式 `Abstracts.complete`（`ch = some c` のとき。`Abstracts.complete_of` による）が導かれる。内容は、PRE の下で具体側は必ず正常終了し、その像は環境を固定した `f` の結果と一致する、というものである。出力が関数で決まる機械（`Machine.pure` とその制限）では、`Refines.complete_fun` が出力の等式を与える。
- `Abstracts` からは、初期状態からの複数歩の模倣（`Machine.Abstracts.run_init`。`Abstracts.run_of` による）と、環境の前提を満たす具体側の入力が正常終了し抽象側の歩みで模倣されること（`Machine.Abstracts.exists_ok`）が導かれる。
- 名前付きの成分の **広さ**（どこまでを差異・非決定性として許すか）は、形の制限・両向きの例・必要性・適合テストベクタの網羅（TR-V）を越えては、証明では確かめられない。仕様の変異テスト（成分を狭める変異体を作り、証明が通ったまま残るものを報告する）で兆候を探し、残りを保証の限界の文書に載せる。
- `Spec` の標準の選択 `run` が業務の意図どおりであること（仕様の妥当性）は、どの義務でも確かめられない。仕様文書の例を、`run` と独立に期待値を書いた検査（意図から書く例。[conformance.md](conformance.md#意図から書く例)）で確かめ、保証の限界の文書に載せる。
- R 課題は `Refines.trans` で合成できない（合成した貼り合わせは `Glue.ofStd` の形にならない）。主定理は、具体機械と `Spec` の間で直接に述べる。
- 機能の機械は並置（`Machine.sum`・`Concrete.sum`・`Glue.sum`。入力は和、状態は積）でトップレベルの機械にまとめる。並置はリファインメントと束を保つ（`Refines.sum`・`Preserves.sum`・`Abstracts.sum`）。トップレベルの主定理（[トップレベルの主定理](#トップレベルの主定理)）は、R 課題ごとの主定理と束をそれぞれ並置して示す（[ADR ab9e](../decision/ab9e-adequate-bundle-sum-and-side-staging.md)・[ADR 6b4b](../decision/6b4b-preserves-refines-abstracts.md)）。条件付きの成分を持つ束どうしの並置（`Choice` と層の並置）は、最初の `ofChoice`・「出力のみ」の R 課題を取り込むときに足す。
- 状態の成分を共有する機能（例: 状態を読む照会と、同じ成分を書く登録）は、`sum` でなく `alt`（`Machine.alt`・`Concrete.alt`・`Glue.alt`。同じ状態の上で入力と出力を和にする）で並置する。`sum` では、それぞれが状態の別の写しを持ってしまう。`Refines.alt` は 2 つの貼り合わせの `J` が等しいこと、`Preserves.alt` は抽象側の INV と具体側の初期状態が等しいことを仮定する。`alt` で並置した機能を、ほかの機能と `sum` で並べる（[ADR a303](../decision/a303-shared-state-machine-alt-and-transaction.md)）。

#### トップレベルの主定理

適用先の `Abstraction.lean`・`Refinement.lean` のトップレベル（下の名前空間ではなく、ファイルそのもの）に、次の 3 つを置く。
補題と R 課題ごとの定理は、機能ごとの下の名前空間に置く。

```lean
theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
theorem preserves : Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
theorem abstracts : Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
```

- `Spec.machine`・`SourceModel.machine`（`TargetModel.machine`）は、実装済みの範囲の機能の機械を同じ並びで並置したもの。入口の機械ができたら、入口の機械を並置に加える。
- `dev`・`devC`・`glue`・`env` は、R 課題ごとの前提型の差異・貼り合わせ・環境の前提を `sumPred`・`Glue.sum` で並置したもの。
- `refines` は R 課題の主定理を `Refines.sum` で、`preserves` は R 課題ごとの束を `Preserves.sum` で並べ、それぞれ `congrPre` で並置した制限に付け替えて示す。互いを使わない。`abstracts` は両者の組である。機能をまたぐので `@[obligation]` を付けない（形の検査は R 課題ごとに行う）。
- 機能を取り込んだら、その R 課題の主定理と束を並置に加える。主定理が `lake build` で通り続けることが、取り込みの条件である。

既存の研究との対応は次のとおりである。義務の名前を研究の用語に読み替えるときに使う。

| 研究 | 対応する義務 |
| --- | --- |
| Event-B の証明義務（FIS・GRD・INV・INI・DLF） | FIS は `ofChoice`、GRD・INV は適用可能性・正しさ・`Sound`、INI は INIT・`InitSurj`、DLF（相対的デッドロック自由）は `TotalUnder`・`Refines.complete` |
| refinement calculus の miracle・abort | miracle（偽の事前条件）は `Sound`・`InitIs`・`TotalUnder`、abort（何でも許す仕様）は `ofChoice`・`FreeFrame` |
| 前方シミュレーションと決定性（CompCert） | `Refines.complete` |
| vacuity detection（部分式を自明な値に替えると真理値が変わること）、冗長な仮定の検出 | 成分の必要性 |
| 仕様の sanity check（入力に依存しない・出力を制約しない仕様） | `ofChoice`・`FreeFrame`・aₒ の `KernelIs` |
| 仕様の変異テスト（IronSpec・mCoq） | 成分の広さ（変異テストの道具） |
| Spec-Testing Proofs（意図から書く正・負の例） | W 課題（Counterexample）と、意図から書く例 |

### 差異

| 種類 | 意味 | 定理での現れ方 |
| --- | --- | --- |
| 前提型 | ある前提の下では一致する | リファインメント定理の名前付きの仮定。述語に `@[deviation "D-NNN"]` / `@[deviation "T-NNN"]` を付ける。前提の述語は、次のどちらかの形をとる。<br>- 抽象側の入力・状態の述語: 抽象側の PRE を強める<br>- 具体側だけにある入力・環境の述語: 具体機械の入力・環境を制限する |
| 観測型 | 出力・状態の一部が常に異なる | J または αₒ の名前付きの成分として現れ、同じ属性を付ける。J と αₒ は、標準の抽象化（下表）と、名前付きの差異成分だけで組み立てる |
| モデル外 | `Spec` の外の規範（仕様文書）とソースが異なり、どのモデルにも現れない | 定理には現れない。これは抽象モデルとモデルの不一致ではない。登録簿に書き、保証の限界の文書に載せる。`Spec` で表現できる振る舞いの違いを、モデル外としてはならない |

- 差異の登録簿は Lean に置く。差異ごとに、型 `Trace.Gap` の宣言に `@[gap_entry]` を付け、種類・箇所（文書の節）・前提または成分・R 課題・W 課題・影響を値に、説明を docstring に書く。差異の生じる `Spec` と `SourceModel`（`TargetModel`）の定義には、箇所の印 `@[gap "D-NNN"]` を付ける。文書の表は道具が登録簿から生成する（[lean/trace-attributes.md](../lang/lean/trace-attributes.md#ギャップの登録簿)）。`Spec` の PRE の外での振る舞い（差異ではない）と、種類が未確定のものも、同じ登録簿に種類を分けて置く。
- ギャップは、リファインメントの証明の中で証明できない部分である。それを公理や `sorry` で仮定しない（ギャップが実在すれば、差異を外したリファインメントは偽なので矛盾する）。代わりに、ギャップごとに証明の状態（偽を証明済み・被覆・未証明・形式化していない・PRE の外）を登録簿の値に書き、状態を裏付ける宣言（否定の定理・被覆の定理・`opaque` の主張・前提の述語）に `@[gap]` を付ける。obligation-check がその対応を確かめる（[lean/trace-attributes.md](../lang/lean/trace-attributes.md#証明の状態evidence)）。
- 前提型・観測型の差異には、次の 3 つを必須とする。
  - Lean の名前
  - それを含むリファインメントの主定理（R 課題）
  - 差異の証拠（W 課題）。両向きの例と、差異の必要性を示す。
    - 前提型: 前提を満たす例と、前提を破って具体側と抽象側が一致しない例（必要性の証人になる）
    - 観測型: 成分が関係づける例（標準の抽象化では関係しないもの）と、関係づけない例
    - 必要性: 差異を外した R 課題の命題が偽である（[空虚化を防ぐ義務](#空虚化を防ぐ義務) の「成分の必要性」）。他の必要な差異に覆われる差異は、被覆を示す
- 主定理は閉じた命題とする（∀ の仮定を持たない）。前提型の差異の述語は、`restrict`・`restrictState`・`Concrete.restrict` で機械の中に置く。ポートの契約は仮定に置かず、モデルのポート実装が契約をリファインすることを別の R 課題で示す。
- `J`・`αᵢ`・`αₒ` は、標準の抽象化（下表）と名前付きの差異の成分だけで組み立てる（`Glue.ofStd`）。

### 証明課題の種類

| 種類 | 内容 | 必須か |
| --- | --- | --- |
| R | リファインメントの主定理（`Machine.Refines`。B refines A）と、束（`Machine.Preserves`。A preserves B。同じ課題 ID。`InitSurj`・基底が `ofChoice` なら `Pinned`・出力のみの差異の `StateSafe` などを成分に持つ） | 機能ごとに必須。モデルの公開操作（ポートの実装を含む）を、**入口の** R 課題ですべて覆う。他の R 課題の操作を含む場合は、その仮定・成分を引き継ぐ |
| W | 差異の証拠 | 前提型・観測型の差異ごとに必須 |
| C | 差異の特徴付け（差の向きと大きさなど） | 任意。R の代わりにはならない |
| L | 補題（同値、到達不能、溢れが無いこと、不変条件） | 任意 |

## 抽象化関数

| 関数 | 写す向き | 例 |
| --- | --- | --- |
| α | `SourceModel` の値 → `Spec` の値 | int32 → 整数、double → 有理数、UTF-16 文字列 → スカラ値の列、null 可能参照 → `Option`、業務エラーの例外 → エラー値、SQL の許される結果の集合 → 順列ごとに列へ写す関係 |
| β | `TargetModel` の値 → `Spec` の値 | `u64` → `Nat`、UTF-8 文字列 → スカラ値の列、`Result` → `Except` |

- α/β は、J・αᵢ・αₒ の部品である。Lean では部分写像（`Option` を返す関数）として書き、`@[std_abs]` を付ける。
- α/β の表には、各行が同一視するもの（核）を書く（例: double の +0 と −0）。核に当たる値の違いは、観測されない。
- α/β が定義されない値がある。例: NaN、不対サロゲート、パニック、前提違反。具体側がこれらに到達しないことは、適用可能性の証明義務で示す。到達しうる場合は、その入力が PRE の外であることを示すか、前提型の差異で除外する。
- 非決定的な具体側の結果（例: 未規定の並び順）は「許される結果の集合」として表す。正しさの義務は、集合のすべての要素について示す。

## 正規性の序列

1. Lean の `Spec`（型・関数・定理）
2. 仕様文書の **規範** 節（`Spec` で表現できない仕様）
3. 適合テストベクタ（モデルを実行して生成する）
4. `SourceModel` / `TargetModel` と、それぞれのソース
5. 移植元ソース（`SourceModel` を確かめるための原典実行）

`Spec` と矛盾する文書・ベクタ・ソースは、`Spec` を正として直す。`Spec` 自体を変えるのは、業務の意図が変わるときだけである（変更はプロジェクトの意思決定記録に記録する）。
この序列は仕様の正規性の序列であり、作業規約どうしの優先順位とは別のものである。

## 関数型コアとポート

- 業務ロジックは、純粋関数として `Spec` に書く。マスタ・設定・「今日」は引数で受け取る。
- 時刻・永続化・採番・ハッシュ・ファイル・キューはポートとする（`Spec.Port` に、関数レコード over `Monad m` として定義する）。ポートの契約は、リファインメント定理の仮定にしない。各モデルのポート実装が契約をリファインすることを証明する。モデルの外の実装（実際の時計・ハッシュ関数）が契約を満たすかは、保証の限界の文書に書く。
- ユースケースは、抽象状態 `World` 上の抽象機械の操作として意味を与える。各操作は原子的である。並行実行がどれかの逐次実行と一致すること（直列化可能性）は、仕様文書の規範節に書く。モデルとソースの境界で何を保証できるかは、保証の限界の文書に書く。
- 実行環境の都合で起こる失敗（例: 排他制御の衝突、I/O の失敗）を移植先に許す場合は、`Spec` の操作の非決定的な結果（環境の選択）として定める。`TargetModel` だけに許してはならない。具体側では環境を入力の成分として表し、`Refines.Pinned` で、障害の無い環境ではこの結果を選べないことを示す。それでも、環境が常に障害を示す配備では常に失敗しうる。活性はテストでしか確かめられないので、保証の限界の文書に載せる。
- エラーは値（直和型）で返す。移植元に安定したエラーコード（メッセージキー等）があれば、それをコードとして使う。
