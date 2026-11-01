import Machine.Machine
import Machine.Concrete
import Machine.Glue
import Machine.Refines
import Machine.Preserves.Pred
import Machine.Machine.Preserves
import Machine.Machine.Run
import Machine.Concrete.Run
import Machine.Glue.Preserves
import Machine.Refines.Preserves
import Machine.Preserves
import Machine.Abstracts
import Machine.Sum
import Machine.Machine.Sum
import Machine.Concrete.Sum
import Machine.Glue.Sum
import Machine.Refines.Sum
import Machine.Preserves.Sum
import Machine.Abstracts.Sum
import Machine.Alt
import Machine.Machine.Alt
import Machine.Concrete.Alt
import Machine.Glue.Alt
import Machine.Refines.Alt
import Machine.Preserves.Alt
import Machine.Kernel

/-!
# Machine

抽象機械と B メソッドのリファインメントの枠組み（spec-pivot スキルの assets。core のみに依存する）。
定義は スキルの `references/docs/spec/architecture.md#リファインメントb-メソッド` による。

| モジュール | 内容 |
| --- | --- |
| `Machine.Machine` | 抽象機械 `Machine.Machine`、`Spec` 自身の義務 `Sound`、前提型の差異 `restrict`・`restrictState`、純粋な計算 `Machine.pure` |
| `Machine.Concrete` | 具体機械 `Machine.Concrete`（正常終了でない結果を `Except ε` で持つ）、`ofFun`・`pure`、具体側の入力の制限 `Concrete.restrict`、`Concrete.ofMachine` |
| `Machine.Glue` | 貼り合わせ `Glue`（`J`・`αi`・`αo`）、恒等・純粋・合成、各点で同値な貼り合わせ `Glue.Equiv` |
| `Machine.Refines` | **B refines A**: B メソッドのリファインメント `Refines`（INIT・入力の全域性・適用可能性・正しさ。入出力の対応 αi・αo で一般化したもの）、制限・反射・推移の補題、`Refines.of_pure`、系 `congr`・`complete_fun`、否定 `not_of_error`・`not_of_stuck`・`not_of_mismatch` |
| `Machine.Sum` | 機械の並置 `Machine.sum`・`Concrete.sum`・`Glue.sum`・`sumPred`。並置はリファインメントと束を保つ（`Refines.sum`・`Preserves.sum`・`Abstracts.sum`）。トップレベルの主定理（`Spec.machine` と `SourceModel.machine` の `Refines`・`Preserves`・`Abstracts`）を各機能の R 課題から組み立てる |
| `Machine.Kernel` | 標準の抽象化の汎用の核 `undefOrEq`（部分写像が「どちらも定義されないか、等しい」）と `kernelIs_undefOrEq`・`inj_of_kernel` |
| `Machine.Preserves` | **A preserves B**: R 課題の、リファインメントの空虚化を防ぐ意味的な義務のすべての束 `Preserves`（references/docs/spec/architecture.md#空虚化を防ぐ義務。`Refines` を含まない）。成分の述語は `Machine.Preserves.Pred`（`never`・`always`・`Nontrivial`・`KernelIs` など）、`Machine.Machine.Preserves`（`ofChoice`・`FreeFrame`・`InitIs`・`TotalUnder`）、`Machine.Glue.Preserves`（`Glue.ofStd`）、`Machine.Refines.Preserves`（`InitSurj`・`EnvWitness`・`NoFaultReachable`・`Pinned`・`StateSafe`） |
| `Machine.Abstracts` | **A abstracts B = A preserves B ∧ B refines A**: 束 `Abstracts` と、その系（複数歩の模倣 `run`・`run_init`、具体側の正常終了の実在 `exists_ok`、1 歩の可換式 `complete`）。歩みの列は `Machine.Machine.Run`・`Machine.Concrete.Run` |

R 課題の主定理は次の形をとる。`devA`・`devC` は前提型の差異の述語（抽象側の入力、具体側だけにある入力）、
`β`・`ai`・`ao` は標準の抽象化（`@[std_abs]`）、`obsJ`・`obsO` は観測型の差異の成分（無ければ省く）である。
述語・成分には、利用側で `@[deviation "D-NNN"]` などを付ける。貼り合わせは補助定義で包まず、型にそのまま書く。

```lean
theorem feature_refines :
    Machine.Refines (Spec.Feature.machine.restrict devA)
                    (SourceModel.Feature.machine.restrict devC)
                    (Machine.Glue.ofStd β Ic ai ao obsJ obsO)
```

各 R 課題は、主定理 `Machine.Refines A C g`（B refines A）と、同じ課題 ID の `@[obligation]` を付けた束
`Machine.Preserves A C g s₀ Env ch outs outsC`（A preserves B）を示す。両者を合わせたものが `Machine.Abstracts`
（A abstracts B）である。トップレベルの主定理は、機能の機械を並置した機械（`Machine.Sum`）について
`Refines`・`Preserves`・`Abstracts` を示す。

束の外に残る義務（差異の必要性、定数ごとの `Nontrivial`・`KernelIs`、束の `ch`・`outs` が R 課題の構造に合うこと、形）は、
obligation-check が照合する（references/docs/spec/architecture.md#空虚化を防ぐ義務）。
-/
