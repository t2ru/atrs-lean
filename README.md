# atrs-lean

TERASOLUNA のサンプルアプリケーション **ATRS（Airline Ticket Reservation System、航空券予約システム）** の Thymeleaf 版を、
**Lean 4 で形式化したモデルと仕様** を介して **Rust** へ移植するプロジェクトです。
目標は、他のどの言語へも同じロジックを移植できる、**検証可能な仕様** を得ることにあります。

> **English summary.** atrs-lean ports the TERASOLUNA ATRS sample application (Java/Spring/MyBatis/PostgreSQL) to Rust
> through a Lean 4 formal specification. A Lean model of the original source (`SourceModel`) and a Lean model of the
> Rust port (`TargetModel`) are each proven to refine a language-neutral abstract specification (`Spec`) in the sense
> of the B method; every deviation is named in the theorems and documented. Sources and models are linked by
> deterministic traceability checks, conformance vectors, and runs of the original program. The porting method is
> packaged as an application-independent Agent Skill, [spec-pivot](.agents/skills/spec-pivot/SKILL.md).
> Documentation is mostly in Japanese.

## 仕組み

```
移植元ソース ⇔trace⇔ SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel ⇔trace⇔ 移植先ソース
(Java/SQL)           (Lean)                       (Lean)            (Lean)                 (Rust)
```

| 層 | 内容 |
| --- | --- |
| `Spec` | 言語に依存しない正規仕様（Lean）。数値は任意精度の整数で、浮動小数点数を使わない |
| `SourceModel` | 移植元（Java/SQL）の振る舞いを、Java・SQL の意味論のモデル（`LangSemantics`）の上で写したもの。原典の Java のソースツリーと同じ形に並べる |
| `TargetModel` | 移植先（Rust）の振る舞いを写したもの。Verus の写しをここから生成し、Rust との一致を Verus で証明する（予定） |
| `Abstraction`・`Refinement` | `SourceModel`・`TargetModel` が `Spec` を B メソッドの意味でリファインすることの証明 |

基本原則（[ADR c336](docs/decision/c336-foundational-principles.md)）:

1. ソースとモデルの一致を、決定論的な検証または変換で確かめ、トレーサビリティを保つ。
2. 抽象モデルと移植元・移植先のモデルの間に、B メソッドのリファインメントを証明する。
3. 一致しない点（既知差異 `D-NNN`・`T-NNN`）は、すべて定理の名前付きの仮定と文書の両方で明示する。

リファインメントが空虚・自明に成り立たないための義務（[ADR 70eb](docs/decision/70eb-refinement-non-vacuity-obligations.md)）も課しており、
手段の届かない部分（保証の限界）は [docs/spec/assurance.md](docs/spec/assurance.md) にすべて列挙しています。

トップレベルの主定理は [`lean/Abstraction.lean`](lean/Abstraction.lean) の `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts` です。

## 現在の状態

- 完了: Lean の雛形と CI、Java・SQL の意味論、リファインメントの枠組み `Machine`、追跡の道具、Java の原典実行のハーネス。
- 移植元側の証明（`SourceModel` が `Spec` をリファインする）: マスタ・設定・コードリストの読み込み、運賃計算、空席照会。
- 進行中: 予約。
- 未着手: 会員・認証・予約履歴レポート、`TargetModel` と Rust のコード。

進捗の詳細は [docs/backlog/README.md](docs/backlog/README.md) を参照してください。

## 必要なもの

| 道具 | 用途 |
| --- | --- |
| [elan](https://github.com/leanprover/elan)（Lean 4 と Lake。版は [`lean-toolchain`](lean-toolchain)） | モデル・仕様・証明・適合テスト |
| [mise](https://mise.jdx.dev/) | 検査のタスク。mise は [uv](https://docs.astral.sh/uv/) だけを管理し、Python の道具は uv で実行する |
| JDK 17 と Maven（任意） | Java の原典実行 |
| PostgreSQL 16（任意） | SQL の差分実行 |

JDK・PostgreSQL が無い場合、それらを使う段はローカルでは飛ばされます。

## 使い方

上流のソースは git submodule です。

```bash
git clone --recurse-submodules https://github.com/t2ru/atrs-lean.git
```

```bash
cd atrs-lean && mise install
```

Lean のビルドとテスト:

```bash
cd lean && lake build && lake test
```

検査（コミット前。常時の段と、変更に関係する長い段）:

```bash
mise run check
```

全数の検査:

```bash
mise run ci
```

タスクの一覧は `mise tasks`、検査の層と実行の時点は [docs/rules/checks.md](docs/rules/checks.md) にあります。

## ディレクトリ

| パス | 内容 |
| --- | --- |
| [`lean/`](lean/) | Lean のプロジェクト（`Spec`・`SourceModel`・`Abstraction`・`TargetModel`・`Refinement`・`Tests`・`Tools`） |
| [`conformance/`](conformance/) | 言語に依存しない適合テストベクタ（JSON） |
| [`trace/`](trace/) | 追跡の設定・インベントリ・manifest |
| [`tools/`](tools/) | ATRS 固有の道具（Java の原典実行、ベクタの生成器など） |
| [`docs/`](docs/index.md) | 文書（OKF v0.2 のバンドル）。意思決定記録（ADR）・仕様・バックログ・規約 |
| [`.agents/skills/`](.agents/skills/) | アプリに依存しないスキル（下記） |
| `upstream/atrs` | 移植元ソース（submodule。commit 固定） |
| `rust/`（予定） | 移植先ソース |

## スキル

移植の方法と文書管理の方法は、ATRS に依存しない [Agent Skills](https://agentskills.io/) として切り出してあり、他のアプリケーションの移植にも使えます。

| スキル | 内容 |
| --- | --- |
| [spec-pivot](.agents/skills/spec-pivot/SKILL.md) | Lean を介した言語間移植の方法。言語ごとの情報（Java・SQL・Rust・Lean）、Lean のライブラリ（`LangSemantics`・`Machine`・`Trace`・`ConformanceKit`）、追跡の道具 |
| [okf-bundle](.agents/skills/okf-bundle/SKILL.md) | OKF（Open Knowledge Format）v0.2 の文書バンドルの管理と検査 |
| [work-records](.agents/skills/work-records/SKILL.md) | 意思決定記録（ADR）と作業項目（backlog）の管理 |

## 文書

- [docs/index.md](docs/index.md): 文書の索引
- [AGENTS.md](AGENTS.md): 作業者（人・AI エージェント）向けの案内と規則の要約
- [docs/rules/README.md](docs/rules/README.md): 運用規約
- [docs/spec/](docs/spec/README.md): Lean の `Spec` で表せない仕様、既知差異の表、保証の限界

## 上流

- リポジトリ: <https://github.com/terasolunaorg/atrs> の `JavaConfig-Thymeleaf/`
- branch `release/5.11.0.RELEASE` / commit `f4bfbf0615eb91805546c9c780d4761be92ce17e`

本プロジェクトは NTT 株式会社・株式会社 NTT データグループとは関係がなく、両社の承認を受けたものではありません。

## ライセンス

次のいずれかを選んで利用できます（デュアルライセンス。[ADR 1add](docs/decision/1add-license-mit-or-apache-2-0.md)）。

- Apache License, Version 2.0（[LICENSE-APACHE](LICENSE-APACHE)）
- MIT License（[LICENSE-MIT](LICENSE-MIT)）

SPDX: `MIT OR Apache-2.0`

ただし、submodule `upstream/atrs` は本リポジトリのライセンスの対象外で、上流のライセンス（Apache License 2.0）に従います。
`SourceModel`・共有入力・原典実行の採取結果など、上流のソースから派生した部分の再配布には、上流の Apache License 2.0 の条件（著作権表示の保持、変更の明示など）もかかります。
詳しくは [NOTICE](NOTICE) を参照してください。

### 貢献

特に明示しない限り、あなたが本プロジェクトに意図して提出した貢献は、Apache License 2.0 の定義に従い、追加の条件なしに上記のデュアルライセンスで提供されるものとします。

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this work by you,
as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
