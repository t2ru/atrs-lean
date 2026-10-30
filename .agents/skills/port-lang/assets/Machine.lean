import Machine.Basic
import Machine.Concrete
import Machine.Refines
import Machine.Adequacy

/-!
# Machine

抽象機械と B メソッドのリファインメントの枠組み（port-lang スキルの assets。core のみに依存する）。
定義は ADR 0034（ATRS）と、スキルの `references/architecture.md#リファインメントb-メソッド` による。

| モジュール | 内容 |
| --- | --- |
| `Machine.Basic` | 抽象機械 `Machine.Machine`、`Spec` 自身の義務 `Sound`、前提型の差異 `restrict`・`restrictState`、純粋な計算 `Machine.pure` |
| `Machine.Concrete` | 具体機械 `Machine.Concrete`（正常終了でない結果を `Except ε` で持つ）、`ofFun`・`pure`、具体側の入力の制限 `Concrete.restrict`、`Machine.toConcrete` |
| `Machine.Refines` | 貼り合わせ `Glue`（`J`・`αi`・`αo`）、`Refines`（INIT・入力の全域性・適用可能性・正しさ）、制限・反射・推移の補題、`Refines.of_pure` |
| `Machine.Adequacy` | リファインメントの空虚化を防ぐ義務（ADR 0038）: 選択の像としての抽象機械 `Machine.ofChoice`・`FreeFrame`・`InitIs`、標準の貼り合わせ `Glue.ofStd`、入口の全域性 `TotalUnder`・`Refines.EnvWitness`、`Refines.Pinned`・`NoFaultReachable`・`InitSurj`・`StateSafe`、`Nontrivial`・`KernelIs`、1 歩の可換式 `Refines.complete`、複数歩の模倣 `Refines.run` |

R 課題の主定理は次の形をとる。`devA`・`devC` は前提型の差異の述語（抽象側の入力、具体側だけにある入力）、
`β`・`ai`・`ao` は標準の抽象化（`@[std_abs]`）、`obsJ`・`obsO` は観測型の差異の成分（無ければ省く）である。
述語・成分には、利用側で `@[deviation "D-NNN"]` などを付ける。貼り合わせは補助定義で包まず、型にそのまま書く。

```lean
theorem feature_refines :
    Machine.Refines (Spec.Feature.machine.restrict devA)
                    (SourceModel.Feature.machine.restrict devC)
                    (Machine.Glue.ofStd β Ic ai ao obsJ obsO)
```

付帯の義務（`Refines.InitSurj`・`Pinned`・`NoFaultReachable`・`EnvWitness`・`StateSafe`、`Machine.Sound`・`InitIs`・`TotalUnder`・`FreeFrame`、`Nontrivial`、`KernelIs`）は、
同じ機械と貼り合わせについて別の定理で示す（ADR 0038）。
-/
