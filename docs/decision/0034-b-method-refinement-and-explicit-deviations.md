---
type: Architecture Decision Record
title: "抽象モデルと移植元/先モデルの関係を B メソッドのリファインメントとし、差異を名前付きの前提・観測成分として明示する"
description: "SourceModel と TargetModel がそれぞれ Spec を B メソッドの意味でリファインすることを、貼り合わせ不変条件と証明義務（初期化・適用可能性・正しさ）で証明する。差異は前提型・観測型・モデル外に分類し、D-NNN / T-NNN として文書と Lean の @[deviation] の両方に置く。ADR 0004 を置き換える。"
tags: [adr, model, abstraction, refinement, proof]
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:30:00+09:00
sources:
  - id: atrs-upstream
    resource: https://github.com/terasolunaorg/atrs/tree/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf
    title: TERASOLUNA ATRS (JavaConfig-Thymeleaf)
  - id: abrial-bbook
    resource: https://doi.org/10.1017/CBO9780511624162
    title: "J.-R. Abrial, The B-Book: Assigning Programs to Meanings (1996)"
---

# 抽象モデルと移植元/先モデルの関係を B メソッドのリファインメントとし、差異を名前付きの前提・観測成分として明示する

## Context and Problem Statement

[ADR 0004](0004-two-layer-model-java-faithful-and-abstract.md) では、移植元モデル [Source] と抽象モデル [Spec] を分けた。両者の関係は次の 3 種類の定理で示すとした。
- 一致: `α(Source(x)) = Spec(α(x))`
- 差異の特徴付け
- 安全性

[ADR 0033](0033-foundational-principles.md) の原則 2 は、抽象モデルと移植元/先モデルの間に、**B メソッドでいうリファインメント** が証明されていることを求める。原則 3 は、不一致を証明と文書の両方で明示することを求める。
既存の定義は次の点でこれを満たさない。

* 関数の可換性だけでは、状態・不変条件・初期化・事前条件を扱えない。
* 具体側の非決定性（SQL の未規定順序、検証エラーの順序）の向きが規定されていない。
* α/β が部分関数である（パニック → β 未定義、NaN → α 未定義）。
* 「差異の特徴付け」「包含」「同値」など、リファインメントでない課題が主定理の代わりになっている。
* 証明課題の無い差異（D-008, D-016 など）がある。
* 移植先側の差異の登録簿が無い。

## Decision Drivers

* 原則 2・3 を、Lean で検査できる形にすること
* [Source] で原典の偶発的な振る舞いを再現し、[Spec] で意図を表す、という二層の利点を保つこと
* 差異が「証明の仮定」と「文書の行」の両方に、1 対 1 で現れること

## Considered Options

* B メソッドの抽象機械とリファインメント（貼り合わせ不変条件と証明義務）で定め、差異を名前付きの仮定と観測成分にする
* 関数の可換性（ADR 0004）のまま、差異の文書化だけを強める
* 差異を織り込んだ中間の抽象機械を置き、[Source] はそれをリファインする

## Decision Outcome

Chosen option: "B メソッドの抽象機械とリファインメントで定め、差異を名前付きの仮定と観測成分にする", because 原則 2 を文字どおり満たし、差異がリファインメント定理の型に現れるため、証明と文書の対応を機械的に検査できるため。

### 二層モデル（ADR 0004 から引き継ぐ）

* **[Source] 移植元モデル**（Lean: `SourceModel`）: 原典の観測可能な振る舞いを、Java の意味論（int32 の折り返し、0 方向切捨て除算、IEEE 754 binary64、`BigDecimal` の丸め、UTF-16 長、`Assert` の失敗）ごと再現する。原典の不具合も再現する。Java の基本演算は [ADR 0005](0005-java-primitive-semantics.md) による。
* **[Spec] 抽象モデル**（Lean: `Spec`）: 意図された業務規則を、任意精度の整数で定義する（[ADR 0006](0006-exact-integer-arithmetic-in-abstract-model.md)）。
* **[Target] 移植先モデル**（Lean: `TargetModel`）: 移植先ソースの振る舞いを、移植先言語の意味論で写す（[ADR 0035](0035-generate-verus-mirror-from-target-model.md)）。
* 仕様の各定義は [Spec]/[Source] を併記する（[port-lang/spec-documents.md](../../.agents/skills/port-lang/references/spec-documents.md)）。

### 抽象機械

`Spec` の各機能を、次の要素からなる抽象機械として与える。

| 要素 | 内容 |
| --- | --- |
| 状態 σ | ユースケースは抽象状態 `World`。マスタ・設定は `World` に含めず、不変の入力とする。純粋な計算は状態を変えない操作とみなす |
| 不変条件 INV | `World` の不変条件。例: `vacantNum ≥ 0` |
| 初期化 INIT | 初期状態の集合（fixture の投入後の状態など） |
| 操作 | 入力 ι（マスタ・設定を含む）・事前条件 PRE・事後の関係 `step : σ → ι → σ → ο → Prop`（非決定性を許す）・出力 ο |

* `Spec` は実行可能でなければならない（ベクタ生成のため）。そこで各操作に、関係 `step` と実行可能な **標準の選択** `run` の組を与える。両者には定理 `PRE → step s i (run s i)` を持たせる。
* `Spec` 自身の証明義務は 2 つある。1 つは初期化が INV を満たすこと、もう 1 つは PRE の下の各操作が INV を保つことである。
* 値域（[domain-model.md](../spec/domain-model.md#値域)）と、マスタ・設定の制約 MD-1〜MD-8（[master-data.md](../spec/master-data.md#不変条件spec)）は、各操作の PRE に含める。

### リファインメント（具体機械が抽象機械をリファインする）

`SourceModel` と `TargetModel` の各機能を具体機械（状態 τ・初期化・操作）とし、次を与える。

* 貼り合わせ不変条件 `J : σ → τ → Prop`（抽象化関数 α/β を含む関係）
* 入力の対応 `αᵢ` と出力の対応 `αₒ`（いずれも関係）。`αᵢ`・`αₒ`・`J` は、標準の抽象化（登録簿の α/β の表）と、名前付きの差異の成分だけで組み立てる

証明義務（PO）は次の 3 つとする（B-Book の初期化と操作の PO に、具体側の失敗の扱いを加えたもの）。

| PO | 内容 |
| --- | --- |
| INIT | 具体側の任意の初期状態 t について、`J s t` を満たす抽象側の初期状態 s がある |
| 入力の全域性 | 具体側の任意の入力 i_c について、`αᵢ i_c i` を満たす i がある。ただし、前提型の差異（具体側の入力の述語）で名前を付けて除外したものを除く。これが無いと、像を持たない入力について他の PO が空虚に成り立ってしまう |
| 適用可能性 | `INV s ∧ J s t ∧ αᵢ i_c i ∧ PRE s i` の下で、具体側の操作は結果を持ち、どの結果も正常終了である。正常終了でないものは、パニック・前提違反・算術の溢れによる誤り（溢れを誤りとする言語）・NaN・α/β の未定義である。業務エラー（例外として投げられ、α/β でエラー値に写るもの）は正常な結果に含まれる |
| 正しさ | 同じ仮定の下で、具体側の任意の正常終了 `(t', o_c)` について、`step s i s' o ∧ J s' t' ∧ αₒ o_c o` を満たす `(s', o)` がある |

* 具体側に非決定性があってもよい（例: SQL の未規定順序）。ただし、正しさの PO は具体側の **すべての** 分岐について成り立たなければならない。抽象側の非決定性（例: `Conflict`。[ADR 0037](0037-conflict-as-spec-nondeterminism.md)）は、具体側で減らしてよい。
* PRE の外（例: `Spec` の型で表せない入力、INV を破るマスタ）での具体側の振る舞いには、義務が無い。これは差異ではない。原典の `PreconditionViolation` の多くはこれに当たる。ただし [Spec] がその入力に振る舞いを定めている場合は PRE の内であり、違えば差異である（例: D-020）。
* 汎用の定義（抽象機械、`Refines`、PO）は、アプリに依存しない Lean ライブラリ `Machine` に置く。トップレベル名前空間の例外として扱い（[ADR 0035](0035-generate-verus-mirror-from-target-model.md)）、スキル port-lang の `assets/lean/Machine/` に置く（[backlog 0027](../backlog/0027-machine-refinement-framework.md)）。

### 差異

`Spec` とモデルが一致しない点を **差異** とし、次の 3 種類に分ける。

| 種類 | 意味 | 証明での現れ方 |
| --- | --- | --- |
| 前提型 | ある前提の下では一致し、前提が破れると具体側が異なる | リファインメント定理の **名前付きの仮定** として現れ、仮定の述語に `@[deviation "D-NNN"]` を付ける。前提は次の 2 つの形のどちらかである。<br>- 抽象側の入力・状態の述語: 抽象側の PRE を強める（`Machine.Machine.restrict`・`restrictState`）<br>- 具体側だけにある入力・環境の述語（例: 具体側にだけある要求ヘッダ）: 具体機械の入力・環境を制限する（`Machine.Concrete.restrict`。環境は入力の成分として表す） |
| 観測型 | 出力・状態の一部が常に（または前提と無関係に）異なる | 貼り合わせ関係 J または出力の対応 αₒ の **名前付きの成分** として現れる。成分に `@[deviation "D-NNN"]` を付ける。J と αₒ は、文書の α の表にある標準の抽象化と、名前付きの差異成分だけから組み立てる |
| モデル外 | `Spec` の外の規範節（[ADR 0021](0021-lean-spec-as-normative-source.md)）とソースが異なり、Lean のどのモデルにも現れない（並行実行・セッション・Cookie など） | 証明には現れない。抽象モデルと移植元/先モデルの不一致ではない（[ADR 0033](0033-foundational-principles.md)）。登録簿に種類「モデル外」として書き、[spec/assurance.md](../spec/assurance.md) に限界として載せる |

* 移植元側の差異は `D-NNN`（[spec/abstraction.md](../spec/abstraction.md#既知差異)）、移植先側の差異は `T-NNN`（[spec/refinement.md](../spec/refinement.md#既知差異t-nnn)）とする。
* 前提型・観測型の差異は、次の 3 点を **すべて** 持たなければならない。
  1. Lean の名前（`@[deviation]` 付きの仮定の述語、または J/αₒ の成分）
  2. それを仮定または成分に含むリファインメントの主定理（R 課題）
  3. 差異の **証拠**（W 課題）。前提型では、前提を破る具体的な入力で、具体側と抽象側が一致しない例を示す。観測型では、標準の抽象化だけでは関係しない出力を、差異の成分が関係づける例を示す。証拠が見つからず、差異が無いと証明できた場合は、差異の登録を取り消す
* 差異が見つかったときは、意図の判断を伴えば ADR も書く。ただし ADR だけに記録してはならない。
* `Spec` の PRE・INV の外での原典の振る舞いは差異ではない。参考として、[spec/abstraction.md](../spec/abstraction.md) の別表に記録してよい。

### 証明課題の種類

| 種類 | 内容 | 必須か |
| --- | --- | --- |
| R | リファインメントの主定理（`Machine.Refines` の形。INIT・適用可能性・正しさ） | 機能ごとに必須。`SourceModel`・`TargetModel` の公開操作（ポートの実装を含む）は、どれかの R 課題で覆う。他の R 課題の操作を含む R 課題は、その仮定・成分を引き継ぐ |
| SPEC | `Spec` 自身の義務（標準の選択が関係に含まれること、INIT ⇒ INV、INV の保存） | 機能ごとに必須 |
| W | 差異の証拠（ID は `ABS-1NN` が `D-0NN` に、`REF-1NN` が `T-0NN` に対応） | 前提型・観測型の差異ごとに必須 |
| C | 差異の特徴付け（例: 差の向きと大きさ） | 任意。R の代わりにはならない |
| L | 補題（同値、到達不能、溢れが無いこと、不変条件など） | 任意。R の証明に使う |

### 追跡の検査

* 新しい検査 TR-D は、次の 3 つを確かめる（[ADR 0036](0036-traceability-hash-as-deterministic-check-record.md)）。
  * 文書の前提型・観測型の D/T と、Lean の `@[deviation]` が 1 対 1 で対応すること
  * 各 `@[deviation]` が、ある R 課題の定理の型に現れること
  * 各 D/T に W 課題があること
* 機能ごとの主定理は、仮定に `@[deviation]` 付きの述語、PRE・INV だけを持たなければならない。無名の仮定を加えてはならない。
* ポートの契約は仮定に置かない。モデルのポート実装（`SourceModel`・`TargetModel` のもの）が契約をリファインすることを、別の R 課題で証明する。ユースケースの主定理は、ポート実装を含む具体機械について述べる。

### Consequences

* Good, because 原則 2 の「リファインメント」と原則 3 の「証明の中での明示」が、Lean の定理の型として検査できる
* Good, because 状態を持つユースケース・非決定性・失敗を、同じ枠組みで扱える
* Good, because 抽象側の非決定性（`Conflict`、実装に委ねる上限など）を、仕様にない振る舞いを許すことなく表せる
* Bad, because 抽象機械とリファインメントの枠組み（`Machine`）を実装する必要がある
* Bad, because 差異ごとに証拠の定理が必要になる
* Bad, because [Source] の double を証明可能にするため、IEEE 754 の部分的なソフトウェアモデルが引き続き必要である（[ADR 0005](0005-java-primitive-semantics.md)）

### Confirmation

* `Spec` が `SourceModel`・`TargetModel` に依存していないことを、ビルド構成で確認する。
* [abstraction.md](../spec/abstraction.md) と [refinement.md](../spec/refinement.md) の全課題に対応する Lean 定理が、`sorry` 無しで存在することを CI で確認する。
* R 課題の定理が `Machine.Refines` の形であることを CI で確認する。
* TR-D を CI で検査する。

## Pros and Cons of the Options

### B メソッドのリファインメント＋名前付きの差異

* Good, because 原則どおりで、検査可能
* Bad, because 枠組みと証拠の定理の工数がかかる

### 関数の可換性のまま

* Good, because 既存の課題をそのまま使える
* Bad, because 状態・非決定性・失敗を扱えず、原則 2 を満たさない

### 中間の抽象機械

* Good, because [Source] の証明が中間機械に対しては無条件になる
* Bad, because 中間機械と `Spec` の関係はリファインメントにならない（差異があるため）。差異が定理の型ではなく中間機械の定義に埋もれ、検査しにくい

## More Information

* 本 ADR は [ADR 0004](0004-two-layer-model-java-faithful-and-abstract.md) を置き換える。二層モデルの決定と、運賃の double による差異の調査結果は引き継ぐ。調査結果は次のとおり。
  * シードの範囲では、最終運賃の差異は 0 件である。
  * 基本運賃を 0〜1,000,000 の任意の整数とすると、差異は 188 件ある（最小例は 1430 円・30%）。
* リファインメントが空虚・自明に成り立つことを防ぐ付帯の義務と検査を、[ADR 0039](0039-refinement-non-vacuity-obligations.md) で加えた（本 ADR の決定は変えない）。`J`・`αᵢ`・`αₒ` の標準の部分は部分写像のグラフとし、主定理は閉じた命題として差異を `restrict` で機械の中に置く。
* [ADR 0033](0033-foundational-principles.md)（基本原則）, [ADR 0035](0035-generate-verus-mirror-from-target-model.md), [ADR 0036](0036-traceability-hash-as-deterministic-check-record.md), [ADR 0037](0037-conflict-as-spec-nondeterminism.md)
* [spec/abstraction.md](../spec/abstraction.md), [spec/refinement.md](../spec/refinement.md), スキル port-lang の [architecture.md](../../.agents/skills/port-lang/references/architecture.md#リファインメントb-メソッド)
