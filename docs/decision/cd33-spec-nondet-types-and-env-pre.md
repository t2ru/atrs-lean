---
type: Architecture Decision Record
title: "[Spec] の非決定性の選択の型と、入口の環境の前提・シードの検査を決める"
description: "backlog 0fdf として、非決定性 N-001〜N-005 の選択の型（@[nondet]）の形、各機能の機械での組み合わせ方、入口の環境の前提（@[env_pre]）をマスタ・設定の妥当性に限ること、シードのマスタ・設定が前提を満たすことを生成したリテラルと真偽値の検査関数の定理で示すことを決める。"
tags: [adr, spec, lean, refinement]
id: "cd3384c8-3697-4138-ba80-54e5d8da43f4"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T18:24:54+09:00
---

# [Spec] の非決定性の選択の型と、入口の環境の前提・シードの検査を決める

## Context and Problem Statement

[ADR 70eb](70eb-refinement-non-vacuity-obligations.md) は、[Spec] の非決定性を `Machine.ofChoice` の選択の型の葉（`@[nondet]`）としてだけ許し（SPEC-005）、入口の機械には環境の前提（`@[env_pre]`）の下での全域性を課す（SPEC-006）。
[backlog 0fdf](../backlog/0fdf-spec-nondet-and-entry-env.md) は、状態を持つ機能（予約・会員・認証・レポート）の抽象機械より先に、これらを定義する。

決めることは、次の 4 つである。

* 選択の型の形。特に、レポート要求の配信（N-003）とパスワードのハッシュ（N-005）をどう表すか。
* 選択の組（`E × F`）を、どこで作るか。
* 環境の前提に、入力の値域まで含めるか。入口の機械はまだ無く、入力の型は機能ごとに違う。
* シード（空港 51・区間 20・便マスタ 126・機材 1399 件）が環境の前提を満たすことを、どう示すか。
  * 文字列の述語（`String.all`・`String.any`）は、カーネルの評価で進まない。
  * 機材の一意性を定義どおりに確かめると、カーネルの評価で約 2 分 40 秒かかる。

## Decision Drivers

* 原則 1: 一致は決定論的な検査で確かめる（シードの値は生成し、CI で最新であることを確かめる）
* SPEC-005: [Spec] の非決定性は登録簿のものだけにする
* `sorry`・公理・`native_decide` を使わない
* ビルドの時間を抑える

## Considered Options

* 下表のとおり決める
* 選択の組を 1 つの型（全機能の共通の `EnvChoice`・`FreeChoice`）として定義する
* シードの妥当性を `lake test` の `#guard`（実行時の評価）で確かめる

## Decision Outcome

Chosen option: "下表のとおり決める", because 理由は次の 2 つである。

* 葉の型だけを置き、各機能が必要な成分を組めば、機能に無関係な選択が機械に入らない。
* 定理で示せば、シードの妥当性が入口の全域性（`EnvWitness`）の証拠としてそのまま使える（プロジェクトオーナーの決定）。

| 項目 | 決定 |
| --- | --- |
| 選択の型（`Spec.Nondet`） | 葉の型を 5 つ置き、それぞれに `@[nondet]` を付ける。標準の値は `std` とする。<br>- N-001 `ConflictChoice`: `none`／`conflict`<br>- N-002 `IoFailureChoice`: `none`／`failure`<br>- N-003 `ReportDeliveryChoice`: 再配信の上限 `retryLimit`（1 以上）、次に配信する待ち行列の位置 `next`、重複配信 `duplicate`。標準は 10・先頭・なし<br>- N-004 `InvalidRequestDetail`: `override : Option String`。`none` は [Spec] の定義の詳細<br>- N-005 `PasswordHashChoice`: 単射なハッシュ関数。`matches` の契約を単射性で表す。標準は参照の符号化 `"{test}" ++ raw`（[ADR 2d1f](2d1f-password-hashing-port.md)） |
| 選択の組 | 各機能の機械が、使う葉だけを積で組む（例: 予約確定は `ConflictChoice × IoFailureChoice` と `Unit`）。標準の値は各葉の `std` の組とする |
| 環境の前提（`Spec.EnvPre`） | `masterConfigOk : Config × MasterData → Prop`（設定の不変条件と MD-1〜MD-8）だけを置き、`@[env_pre]` と `Nontrivial` を付ける。入力の値域の述語は、入口の機械を作る各機能の backlog で、その入力の型に合わせて置く（プロジェクトオーナーの決定） |
| シードの値（`Spec.Seed`） | `tools/conformance/seed_lean.py` が `conformance/fixtures` から生成し、CI が `--check` で最新であることを確かめる。`outsideSpec` の行（到着時刻 2415 の便マスタ 2 行）は、`Tests.ConformanceFare` と同じく除く（[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)。[Spec] の改訂は backlog 0be7） |
| シードの検査 | 真偽値の検査関数 `EnvPre.validB` と、その正しさ `validB_sound` を書き、カーネルの評価（`decide +kernel`）で `seed_env` を示す。<br>- 文字列は `toList` で見る。<br>- 一意性は、鍵（文字の符号の位取り）が真に増加していれば線形時間で確かめ、そうでなければ定義どおりに確かめる。正しさは、写した列の一意性から元の列の一意性が従うことによる。<br>- ビルドは約 30 秒長くなる |

### Consequences

* Good, because OB-N2 の警告が消え、各機能の機械が `@[nondet]` の葉を使えるようになる
* Good, because シードの妥当性が定理になり、入口の R 課題の `EnvWitness` に使える
* Bad, because N-003・N-005 の形は、レポート（ac71）・会員（4e0e）の機械を作るときに見直すことがありうる
* Bad, because シードの [Spec] の値から、到着時刻 2415 の便マスタ 2 行が抜けている（backlog 0be7 で [Spec] を改めるまで）

### Confirmation

* `obligation-check` と `check_obligations.py` で、OB-N1・N2・N3 と G8 に誤りが無い。
* `Spec.EnvPre.seed_env`・`masterConfigOk_nontrivial` が、`sorry`・公理なしでビルドされる。
* `Tests.SpecChecks` で、選択の型の標準の値と、環境の前提の両向きの例を確かめる。

## More Information

* [ADR 70eb](70eb-refinement-non-vacuity-obligations.md)、[ADR e56e](e56e-conflict-as-spec-nondeterminism.md)、[ADR 90f5](90f5-report-queue-at-least-once-delivery.md)、[ADR 2d1f](2d1f-password-hashing-port.md)
* [abstraction.md](../spec/abstraction.md#spec-の非決定性n-nnn)、[`Spec.Port`](../../lean/Spec/Port.lean)
