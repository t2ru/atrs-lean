---
type: Specification
title: "具体化証明課題（Refinement）と移植先ソースの確認"
description: "TargetModel が Spec を B メソッドの意味でリファインすることの証明課題 REF-NNN、移植先の既知差異 T-NNN、TargetModel ⇔ Rust ソースを決定論的に確認する課題 SRC-NNN（写しの生成・Verus・Kani・適合テスト）。"
tags: [spec, refinement, proof, rust]
status: draft
spec_role: meta
models: [spec, target]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T16:30:00+09:00
---

# 具体化証明課題（Refinement）と移植先ソースの確認

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 61bc](../decision/61bc-lean-spec-as-normative-source.md)）。

構成は [ADR 0bd3](../decision/0bd3-generate-verus-mirror-from-target-model.md) による。関係の定義は [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md) による。

```
Spec ←Refinement（Lean の定理: REF-NNN）─ TargetModel ─(生成: gen-verus)→ rust/src/model/ ─(Verus の証明)→ Rust の実行コード
                                                       └─(target-model/ ベクタ・Kani・結合テスト)→ Rust ソース
```

- **REF**: `TargetModel` が `Spec` を B メソッドの意味でリファインすることを示す。Lean の `Refinement` で **証明** する。
- **SRC**: `TargetModel` と Rust ソースの一致を、決定論的な手段で **確認** する（スキル port-lang の [verification.md](../../.agents/skills/port-lang/references/verification.md) と [rust/verification.md](../../.agents/skills/port-lang/references/rust/verification.md)）。手段の届かない部分は [assurance.md](assurance.md#targetmodel--移植先ソース) に列挙する。

本書は、ATRS の課題の一覧と状況を定める。

## リファインメントの形

機能ごとに、次を与える。

- 貼り合わせ不変条件 `J`
- 入力の対応 `αᵢ`
- 出力の対応 `αₒ`

そのうえで、`Machine.Refines` の 4 つの証明義務（INIT・入力の全域性・適用可能性・正しさ）と、空虚化を防ぐ付帯の義務（`Glue.ofStd` の形、`InitSurj`、`Sound`・`InitIs`、`Pinned`・`NoFaultReachable`、出力のみの差異の `StateSafe`、入口の全域性 `TotalUnder`・`EnvWitness`、差異の必要性）を示す。形は [abstraction.md](abstraction.md#リファインメントの形) と同じである（[ADR 70eb](../decision/70eb-refinement-non-vacuity-obligations.md)・[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）。
`TargetModel` の各操作も、マスタ・設定と環境（衝突・I/O の失敗・配備の設定）を入力の成分として受ける。

抽象化関数 β の標準の抽象化:

| `TargetModel` の値（`LangSemantics.Rust`） | β | 同一視するもの（核） |
| --- | --- | --- |
| `U64` などの固定長整数 | `Nat` / `Int` | なし（単射） |
| `RString` | スカラ値の列 | なし（単射） |
| `Result` | `Except` | なし（単射） |
| `Panic` | β を定義しない（`none`）。PRE の下で到達しないことを、適用可能性の義務で示す | — |

各行は Lean では `@[std_abs]` を付けた部分写像（葉）とし、核を L 課題 REF-012 の `KernelIs` で示す。

- 主定理は閉じた命題とし、前提として持ってよいのは PRE（値域とマスタ・設定の制約を含む）・INV・`T-NNN` の述語だけとする。`T-NNN` の述語は `restrict` で機械の中に置く。ポートの契約は、ポート実装の R 課題（REF-008・REF-009）で証明する。値域は [Spec] の PRE である（[domain-model.md](domain-model.md#値域)）。そのため「値域内」は差異ではない。
- [Spec] の非決定的な結果 `Conflict`（[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)）は、`TargetModel` で選んでも選ばなくてもよい。ただし、選べるのは入力の環境が衝突を示すときだけである（`Pinned`・`NoFaultReachable`。[Spec の非決定性](abstraction.md#spec-の非決定性n-nnn) の N-001）。I/O の失敗（N-002）も同じである。

## 既知差異（T-NNN）

[Spec] と [Target] が一致しない点である。種類は [ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#差異) による。前提型・観測型には、R 課題と W 課題（`REF-1NN` が `T-0NN` の証拠）が必須である。

登録簿の正は Lean の `Refinement.Gap`（`@[gap_entry]` の宣言）であり、下の表はそこから生成する（[ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)）。移植先は [Spec] をそのまま実装する方針であり、現在は登録が無い。差異が必要になったら、意思決定を記録したうえで、`Refinement.Gap` に登録し、`TargetModel` の該当する定義と [Spec] の定義に `@[gap "T-NNN"]` を付ける。

<!-- BEGIN GENERATED: gaps-known -->
`tools/trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。

| ID | 種類 | 箇所 | 差異 | 前提（前提型）／成分（観測型） | R 課題 | W 課題 |
| --- | --- | --- | --- | --- | --- | --- |

（現在なし）
<!-- END GENERATED: gaps-known -->

W 課題は、[abstraction.md](abstraction.md#既知差異) と同じく両向きの例と、差異の必要性（差異を外した R 課題の命題が偽であること。[ADR 9ac6](../decision/9ac6-vacuity-literature-necessity-and-mutation.md)）を示す。前提型の差異は、[abstraction.md](abstraction.md#前提型の差異の影響) と同じく「出力のみ」「中断」に分類する。

### 前提型の差異の影響

<!-- BEGIN GENERATED: gaps-impact -->
`tools/trace manifest` が Lean の登録簿（`@[gap_entry]`）から生成する（手で編集しない）。

| ID | 影響 | 理由 | backlog |
| --- | --- | --- | --- |

（現在なし）
<!-- END GENERATED: gaps-impact -->

## REF: TargetModel が Spec をリファインする（Lean で証明）

種類は次の 4 つである（[ADR 01d4](../decision/01d4-b-method-refinement-and-explicit-deviations.md#証明課題の種類)）。

- R: 主定理と、その付帯の義務（[abstraction.md](abstraction.md#空虚化を防ぐ義務) と同じ）
- W: 証拠（両向きの例と、差異の必要性）
- C: 特徴付け
- L: 補題

| ID | 種類 | 内容 |
| --- | --- | --- |
| REF-001 | R | 純粋な計算（運賃計算・空席照会・入力検証・CSV 生成・書式）: 状態を変えない操作として、`TargetModel` が `Spec` をリファインする |
| REF-002 | R | ユースケース（予約・会員・認証・レポート）: `World` 上の状態遷移として、`TargetModel` が `Spec` をリファインする。`Conflict` の結果を含む |
| REF-003 | L | PRE（値域）の下で、`TargetModel` の算術が溢れず、パニック（`Panic` 値）に到達しない（REF-001・002・007 の適用可能性に使う） |
| REF-004 | R | 基本運賃・運賃・合計金額（REF-001 の運賃部分。最初に着手する） |
| REF-005 | L | 文字列長・文字クラスを、`RString` の `chars` 上のスカラ値で判定すると、`Spec` と一致する（REF-001 の入力検証に使う） |
| REF-006 | L | `TargetModel` の操作は、「今日」「現在日時」を入力（Clock ポートの値）としてだけ受け取る（型による。Rust 側は SRC-009 で確認する） |
| REF-007 | R | HTTP の画面・API: `TargetModel.Http` が `Spec.Http` をリファインする |
| REF-008 | R | インメモリのポート実装（採番・リポジトリ・キュー・ストア・パスワード）: `TargetModel` の実装が、[ports.md](ports.md) のポートの契約をリファインする |
| REF-009 | R | DB・ファイル・時計のアダプタ（`TargetModel.Adapter.*`。DB は `LangSemantics.Sql` の式）: ポートの契約をリファインする。I/O の失敗は、[Spec] の非決定的な結果 `System` で模倣する |
| REF-010 | R | マスタ・設定の読み込み（fixture・設定ファイルから `MasterData`・設定を作る `TargetModel` の操作）が、[Spec] の `MasterData`・設定をリファインする |
| REF-011 | R | レポート要求の受信（入口）: `TargetModel` のキューの受信が、[Spec] の要求の受信をリファインする（REF-002 のレポートの部分を、入口の機械として述べる） |
| REF-012 | L | 抽象化関数 β の表の各行（`@[std_abs]` の葉）について、核が表の「同一視するもの」と一致する（`KernelIs`） |

### 入口の R 課題

`TargetModel` の公開操作の網羅（TR-P）は、次の R 課題の具体機械で数える。入口の機械の [Spec] には SPEC-006（入口の全域性）を課す（[abstraction.md](abstraction.md#入口の-r-課題)）。

| ID | 入口 | backlog |
| --- | --- | --- |
| REF-007 | HTTP の画面・REST（`Spec.Http`） | a89ec8f0-4d15-46a6-86fa-a640e4df0b44 |
| REF-011 | レポート要求の受信と生成（キューからの配信） | 26c57ac3-b6b7-440a-aca5-994943bd7ebd |

## SRC: TargetModel ⇔ Rust ソース（決定論的な確認）

| ID | 内容 | 手段 | 保証の限界 |
| --- | --- | --- | --- |
| SRC-001 | Rust が `conformance/target-model/` と `conformance/shared/` の全ベクタを通す | 適合テスト（`rust/tests/`） | ベクタの入力の外 |
| SRC-002 | `rust/src/model/` が Lean `TargetModel` から生成したものと一致する | `lake exe gen-verus` の再生成で差分が無いこと（CI） | 生成器と `rust/src/model_prelude.rs` の対応表を信頼する |
| SRC-003 | Rust の実行コード（純粋な部分とインメモリのアダプタの状態遷移）が `model/` と全入力で一致し、算術が溢れない。各関数が `requires pre_x(..)`・`ensures r == model::x(..)` の形を持つ | Verus（`ensures`, `rust/src/proof/`）、`gen-verus --check-contracts`（CI） | `verus!` の中に限る。Verus・vstd・rustc を信頼する |
| SRC-004 | `verus!` の外のコード（`Mutex` の層・変換・JSON・HTTP の接続）に、パニック・未定義動作が無い | Kani（`rust/kani/`） | ハーネスに書いた境界の内に限る |
| SRC-005 | 次の 2 つを確かめる。<br>- DB・ファイル・時計のアダプタが `TargetModel.Adapter.*` と一致する<br>- 状態変更の原子性・直列化可能性（[ports.md](ports.md#トランザクション) の規範節）を満たす | 次の 3 つで確認する。<br>- インメモリ: 操作を `Mutex` の下で 1 つずつ実行する（状態遷移は SRC-003、`Mutex` の層は SRC-004）<br>- DB: SERIALIZABLE を指定し、直列化の失敗は再試行し、吸収できなければ `Conflict` を返す。照会は `READ ONLY DEFERRABLE` で実行する<br>- 固定の実行順と固定フィクスチャの結合テスト | テストしていない実行順。PostgreSQL の分離レベルの実装と、Rust 標準の `Mutex` を信頼する |
| SRC-006 | HTTP 契約（[http-contract.md](http-contract.md)）のステータス・遷移先・JSON の形・規範節（セッション・Cookie・CSRF） | HTTP レベルのベクタによる結合テスト | ベクタの入力の外 |
| SRC-007 | 追跡の検査 TR-T1・TR-T2・TR-P・TR-D・TR-X が通る | `tools/trace check` | — |
| SRC-008 | Rust の公開項目が `@[target]` で覆われ、検査済みハッシュが現在の本文と一致する | `tools/trace check`、`tools/trace rehash` | — |
| SRC-009 | 業務機能が `std::time`・浮動小数点型などの暗黙の副作用・禁止 API を使わない | `clippy.toml` の `disallowed-methods` / `disallowed-types`（CI） | 一覧に載せた API に限る |
| SRC-010 | DB アダプタの SQL が、`TargetModel.Adapter` の `LangSemantics.Sql` の式と一致する | SQL の差分実行（PostgreSQL） | 照合したデータの外 |

SRC-007・SRC-008 は、Rust を変更する各 backlog 項目の完了条件で確かめる。道具は [backlog ffdc](../backlog/ffdc-trace-tooling.md) で作る。

## 状況

| ID | 状況 |
| --- | --- |
| REF-001〜012 | 未着手 |
| SRC-001〜010 | 未着手 |

「状況」は、課題を充足した定理・関数・ハーネス・テストへのリンクで更新する。

## 未証明の前提

Verus の `assume`・`admit`・`external_body`・`assume_specification`・`external_fn_specification` を、業務機能・インメモリのアダプタ・`proof/` で使ってはならない。`#[verifier::external]` は、[assurance.md](assurance.md#verifierexternal-の一覧) の一覧に載せた境界にだけ付けてよい。やむを得ず使う場合は、次の 3 つを満たす。

- 意思決定を記録する。
- ここに、場所と理由を列挙する。
- [assurance.md](assurance.md) に、限界として載せる（[rust/verification.md](../../.agents/skills/port-lang/references/rust/verification.md)）。

（現在なし）
