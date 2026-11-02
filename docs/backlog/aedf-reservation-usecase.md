---
type: Backlog Item
title: "予約（B0/B2）"
description: "validateFlightList・validateReservation・reserveConfirm・reserve を SourceModel と Spec で実装し、空席の不変条件を証明する。"
tags: [backlog, spec, source-model, reservation]
id: "aedfeffc-3e82-46b1-b497-3d8b7808d068"
state: doing
depends_on: ["0be7c5d4-01d9-43f4-a50d-227f174830f0", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "f18c3c0f-4007-42c1-ba25-102fb385a16c", "bbcce088-c475-4378-9cc6-e3d821acc0f5", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:00:00+09:00
---

# 予約（B0/B2）

## 目的

状態変更とトランザクションを伴う中心機能を、移植元側（`SourceModel`・`Abstraction`）と `Spec` で実装する。

## 範囲

- `Spec.Ticket`, `Spec.UseCase.Reserve`, `Spec.Port`
- `SourceModel.UseCase.Reserve`, `SourceModel.Repository.Reservation`（`@[source]` 付き）
- R 課題: ABS-021（採番）、ABS-023（予約・空席照会のリポジトリ）、ABS-041（予約のユースケース。`Conflict` と I/O 失敗の非決定性を含む。[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)）
- W 課題: ABS-109（D-009）、ABS-114（D-014）
- L 課題: ABS-020、ABS-022
- SPEC 課題: 予約の SPEC-001〜SPEC-004
- ベクタ（成功・各エラー・往復で復路のみ失敗した場合のロールバック）

## 対象外

- 移植先側（`TargetModel`・`Refinement`・Rust。[backlog 26c5](26c5-target-model-usecases-and-refinement.md)）
- 並行実行の確認（SRC-005）

## 進め方

3 段に分ける（[ADR 4c45](../decision/4c45-reservation-stage1-shared-state-and-source-model.md)。プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 第 1 段 | 予約の `Spec`（`Spec.Ticket`・`Spec.UseCase.Reserve`）と `SourceModel`（原典のソースツリーの形）の関数、`World` と状態の表の拡張、共有ベクタ、Java の原典実行 |
| 第 2 段 | 合成子 `Machine.alt`（スキル）、初期状態（会員のシードと採番の初期値）、抽象機械 `reserveMachine` と SPEC 課題、具体機械 `reserveConcrete`、予約の SQL の PostgreSQL での差分実行 |
| 第 3 段 | α を全表に広げ、ABS-020・ABS-021・ABS-022・ABS-023・ABS-041・ABS-109・ABS-131 を証明し、トップレベルの主定理に統合する |

## 完了条件

- [ ] [reservation.md](../spec/reservation.md) の例がベクタで通る
- [ ] ABS-020・ABS-021・ABS-022・ABS-023・ABS-041・ABS-109・ABS-114 と、予約の SPEC-001〜SPEC-004 を証明した
- [ ] 予約の `source-model/` ベクタが Java の原典実行と一致する
- [ ] リポジトリの SQL の写しを PostgreSQL での差分実行で照合した

## 第 1 段の結果

2026-11-01 に完了した（[ADR 4c45](../decision/4c45-reservation-stage1-shared-state-and-source-model.md)）。

- [Spec]: `Spec.Ticket`（選択フライトの解決・`validateFlightList`）と `Spec.UseCase.Reserve`（予約入力、搭乗者欄を詰める処理、予約内容の組み立て、`validateReservation`、`reserveConfirm`、`reserve`、選択フライトの検証を含む操作 `confirmOp`・`reserveOp`）を置いた。`World` に会員・予約・採番とポートの操作を、`AtrsError` に `invalidRequest`・`system`・`conflict` を足した。
- [Source]: 原典のソースツリーの形で、予約の Web 層（`App.B2`）・サービス・リポジトリ・モデルのクラスを写した。状態の表に会員・予約の表とシーケンスを足した。状態の表に対する計算 `SourceModel.Db.Tx` で、Mapper の文・`@Transactional` の取消（シーケンスは戻さない）・Clock・実行環境の障害を写した。入口の計算は `SourceModel.ReserveQuery`。
- 共有ベクタ `conformance/shared/reservation/` の 47 件が、`Spec` と `SourceModel` の両方で通る。期待値は仕様の例と手計算から取り、敵対的レビューで独立に再計算した。
- Java の原典実行（`tools/origin-run`）が、47 件を原典で照合した。シードの範囲から予約確認の 76 件を原典から採取し（`conformance/source-model/reservation/origin-run-confirm.json`）、`SourceModel` と一致した。
- スキルに `LangSemantics.Sql.Transaction`・`PgTimestamp`・`JLocalTime`・`JList.get`・`StringUtils` を足した（スキルの版 0.25。[スキルの ADR a303](../../.agents/skills/spec-pivot/references/docs/decision/a303-shared-state-machine-alt-and-transaction.md)）。
- 登録簿: D-009 の範囲を INT の上限に広げ、D-031 の R 課題の欄を直した（どちらもプロジェクトオーナーの確認待ち）。D-014 に予約確定の Clock の読み出しを足した。
- 完了条件のうち「reservation.md の例がベクタで通る」と「`source-model/` ベクタが Java の原典実行と一致する」を、第 1 段の範囲で満たした。予約確定の採取ベクタと、残りの完了条件は第 2・3 段で行う。
- 第 2 段に申し送るもの:
  - 会員の取得の結合（ログインの行・カード種別）を α の定義域に課す
  - 採番の自由な選択（[Spec] の採番は未使用の任意の値を許すか）と、`Conflict`・I/O 失敗のときの採番の前進を、選択の型で表す方法
  - 空席照会の α の定義域の制限を外す

## 第 2 段の結果

2026-11-02 に完了した（[ADR ca17](../decision/ca17-reservation-stage2-machines-seed-nondet-advance.md)）。

- スキルに、同じ状態の上の並置 `Machine.alt` 一式（`Refines.alt`・`Preserves.alt`）と、例・反例のテストを足した（版 0.25）。
- 抽象機械 `Spec.UseCase.Reserve.reserveMachine`（選択の像。N-001・N-002・N-004）を置き、予約の SPEC-001・002・003・004・007・008 を証明した。
- N-001・N-002 の選択の型に、失敗するまでに進んだ採番の数 `SeqAdvance` を持たせた（確認待ち）。
- 具体機械 `SourceModel.ReserveQuery.reserveConcrete` を置いた。業務例外・不正要求・I/O 失敗・排他の失敗を出力の値とする。
- 会員のシードの生成器 `tools/conformance/member_seed.py` と、初期状態 `Spec.Seed.World.world`・`SourceModel.Db.Seed.seedDb` を置いた。
- 予約の SQL を PostgreSQL での差分実行で照合した（`conformance/sql/reservation.json`・`Tests.ReservationSql`・検査 `pg-reservation-sql`）。
- 完了条件のうち「予約の SPEC-001〜SPEC-004 を証明した」と「リポジトリの SQL の写しを PostgreSQL での差分実行で照合した」を満たした。
- 第 3 段に申し送るもの: 空席照会の状態と初期状態を全表に広げること（全表の α と一体）、D-014 の述語、R 課題 ABS-020〜023・041・109・131 とトップレベルへの統合。

## 第 3 段の進み具合

[ADR ab93](../decision/ab93-reservation-stage3-world-alpha-and-abs041.md) で小段 3a〜3d に分けた。

* 3a（済）: 全表の α `worldOfDb`、具体側の不変条件 `IcW`、空席照会の初期状態の変更。ABS-011 とトップレベルの主定理は新しい貼り合わせで通る。
* 3b（途中）: 予約の PRE に `Request.Valid`・`World.RefMaster`・`World.MemberRefMaster` を足した。予約の入出力の α と貼り合わせ、FLIGHT・会員・便マスタの Provider・選択フライトの補題を置いた。検証の道具（Hoare 三つ組・`java_estate_simp`）をスキルに置き（スキルの ADR cd90、版 0.26）、選択フライトの検証の対応を示した。ABS-021・ABS-023 を L 課題に改めた（プロジェクトオーナーの決定）。差異の述語（`dev_D027R`・`dev_D014R`・`dev_D009`・`dev_D031`・`dev_D001R`・`dev_D002R`・`dev_D012R`）と非自明性の定理、D-031 の証人の材料を置いた。W 課題 ABS-109・ABS-131 の否定の定理は 3c で ABS-041 と同時に置く。
* 3c（途中）: 予約の各メソッドの事前・事後条件と ABS-041、ABS-020・ABS-022。予約内容の検証（代表者の年齢・運賃種別の利用条件・会員照合）の三つ組と [Spec] の対応、予約の合計金額の補題を置き、予約確認の 1 歩の対応（`confirm_run`）、予約確定の 1 歩の対応（`reserve_run`。空席の確保・登録・採番。D-009・D-014）と、ABS-041 の主定理 `reserveRefines`（`Abstraction.Reserve.ReserveRun`。課題の属性は束とともに 3d で付ける）を示した。W 課題 ABS-109・ABS-131 の否定の定理 `need_D009`・`need_D031`（`Abstraction.Reserve.Witness`）も示した。課題の属性は、束 `Preserves` と具体機械の定義域の扱いとともに 3d で付ける。
* 3d（未着手）: トップレベルへの統合と束。

## 参照

- [reservation.md](../spec/reservation.md)
- [ports.md](../spec/ports.md)
