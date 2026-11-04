import Spec.Env
import Spec.Seed.Master

/-!
# シードデータ（`Spec.Seed`）

> **区分: 要約（informative）。** 値は生成した Lean の定義（下の表のモジュール）が正で、本文はその要約である。

シードデータは、原典の初期データ投入 SQL[^seed-fixed] が DB に入れる初期データである。[Spec] では、シードの設定とマスタを
環境の値として、シードを投入した後の状態を抽象状態 `World` の初期状態として持つ。適合テストの共有入力
（`conformance/fixtures/`）も同じシードから作る。

| モジュール | 内容 | 作り方 |
| --- | --- | --- |
| [`Spec.Seed.Master`](Seed/Master.lean) | シードのマスタ `masterData` と設定 `config` | 生成（`tools/conformance/seed_lean.py`） |
| [`Spec.Seed.Flight`](Seed/Flight.lean) | シードのフライト（約 15 万行）を、日付の列・便名の列・枠の列から作る式 | 生成（`tools/conformance/flight_seed.py`） |
| [`Spec.Seed.FlightProps`](Seed/FlightProps.lean) | シードのフライトの性質（主キーの一意性・マスタの参照） | 手書き（証明） |
| [`Spec.Seed.Member`](Seed/Member.lean) | シードの会員と、採番の初期値 | 生成（`tools/conformance/member_seed.py`） |
| [`Spec.Seed.World`](Seed/World.lean) | シードを投入した後の `World`（各機能の機械の初期状態） | 手書き |

生成したファイルは手で編集しない。本章（`Spec.Seed`）は、シードの設定とマスタが入口の環境の前提
（[`Spec.Env`](Env.lean) の `masterConfigOk`）を満たすこと（`seed_env`）と、前提が自明でないこと（前提を破る例）を示す。
-/

/-!
## シードデータ

**[Spec=Source]** 原典の初期データの内容。適合テストの共有入力 `conformance/fixtures/master-data.json` の元になる。

### 搭乗クラス

| cd | 名前 | 加算料金 | 表示順 |
| --- | --- | --- | --- |
| `N` | 一般席 | 0 | 1 |
| `S` | 特別席 | 5000 | 2 |

### 運賃種別

| cd | 名前 | 割引率 | 予約開始（日前） | 予約終了（日前） | 最少人数 | 表示順 | 分類 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `OW` | 片道運賃 | 0 | 90 | 0 | 1 | 1 | 片道 |
| `RT` | 往復運賃 | 5 | 90 | 0 | 1 | 2 | 往復 |
| `RD1` | 予約割1 | 10 | 60 | 1 | 1 | 3 | 片道 |
| `RD7` | 予約割7 | 20 | 60 | 7 | 1 | 4 | 片道 |
| `ED` | 早期割 | 30 | 60 | 30 | 1 | 5 | 片道 |
| `LD` | レディース割 | 30 | 60 | 1 | 1 | 6 | 片道 |
| `GD` | グループ割 | 30 | 60 | 1 | 3 | 7 | 片道 |
| `SOW` | 特別片道運賃 | 0 | 90 | 0 | 1 | 100 | 片道 |
| `SRT` | 特別往復運賃 | 5 | 90 | 0 | 1 | 101 | 往復 |
| `SRD` | 特別予約割 | 10 | 60 | 1 | 1 | 102 | 片道 |

シードのフライトでは、`S` クラスには `SOW`/`SRT`/`SRD`、`N` クラスにはそれ以外の運賃種別だけが存在する（運賃種別と搭乗クラスの組合せの制約はマスタには無く、フライトの有無で表現される）。

### ピーク時期

初期データ投入時の年 `Y` と `Y+1` の 2 年分（投入時点の年に依存する）。fixture では `Y = 2026` とする（[conformance.md](../../docs/spec/conformance.md#atrs-固有の前提)）。

| cd | 期間 | 積算比率 |
| --- | --- | --- |
| `PEAK1` | 01/01–01/05, 03/20–03/31, 08/08–08/18, 12/26–12/31 | 140 |
| `PEAK2` | 03/13–03/19, 07/18–08/07, 08/19–08/31, 12/19–12/25 | 125 |

期間は互いに重ならない（MD-4 を満たす）。

### 空港・区間・便

- 空港 51 件（主要空港 9 件は表示順 1〜9、その他 42 件は表示順 100〜141）。
- 区間 20 件。路線基本運賃はすべて 100 円単位（20,100〜52,400 円）。
- 便マスタ 126 件。
- フライト: 投入日から 120 日後まで（両端を含む）の各日について、便ごとに搭乗クラス×運賃種別の行を作る。空席数は日ごとに 3 パターン（`i mod 3`）で変わる。fixture では投入日を 2026-11-01 とする。

### 会員

7 件（会員番号は `0000000001` から採番）。全員のパスワードは `aaaaa11111`（前回パスワード `aaaaa00000`）の `{pbkdf2}` ハッシュ。

### カード種別

`VIS`（VISA）, `MTR`（MASTER）, `JCB`（JCB）, `DNS`（DNS）, `AMX`（American Express）

シードの全件（空港・区間・便マスタ・搭乗クラス・運賃種別・ピーク時期・機材・カード種別）は、生成器
`tools/conformance/master_fixture.py` が上流の SQL から `conformance/fixtures/master-data.json` に書き出し（投入日 2026-11-01）、
`tools/conformance/seed_lean.py` がそこから [`Spec.Seed.Master`](Seed/Master.lean) を作る。

翌日着の便（NTT523・NTT528。到着時刻 `2415`）について、[Source] の空席照会は到着時刻を文字列として整形するだけで
（`DateTimeUtil.toFormatTimeString`。`2415` → `24:15`）、[Spec] と一致する。[Source] が `DateTimeParseException` を投げるのは、
予約の往復便の検査で往路便がこの便のとき（`TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight`）で、
既知差異 [D-031](../../docs/spec/abstraction.md#既知差異) である。

[^seed-fixed]: atrs-initdb/src/sqls/integration-test-postgres/00200〜00250_*.sql
-/

namespace Spec.Seed
open Spec.Env Spec.Env.MasterData

/-!
## シードは環境の前提を満たす

シードの設定とマスタは、設定の不変条件とマスタの不変条件 MD-1〜MD-8 を満たす（`seed_env`。検査 `validB` をカーネルで
評価して示す）。空港コードを重複させたマスタは前提を破る（`badMasterData_not_env`）ので、前提は自明でない
（`masterConfigOk_nontrivial`）。
-/

set_option maxRecDepth 100000 in
/-- シードの設定とマスタは、入口の環境の前提を満たす。 -/
theorem seed_env : masterConfigOk (Master.config, Master.masterData) :=
  masterConfigOk.of_valid (by decide) (Env.validB_sound (by decide +kernel))

/-- 環境の前提を破る例: 空港コードの重複（MD-1）。 -/
def badMasterData : MasterData :=
  { Master.masterData with airports := ⟨{ val := "HND" }, "x", 1000⟩ :: Master.masterData.airports }

/-- 空港コードを重複させたマスタは、環境の前提を満たさない。 -/
theorem badMasterData_not_env : ¬ masterConfigOk (Master.config, badMasterData) := by
  intro h
  obtain ⟨-, hv⟩ := h.valid
  have h := hv.md1.1
  simp only [badMasterData, List.map_cons, List.nodup_cons] at h
  exact h.1 (by decide)

/-- 環境の前提は自明でない（満たす例と破る例がある。空虚化を防ぐ義務の G8）。 -/
theorem masterConfigOk_nontrivial : Machine.Preserves.Nontrivial masterConfigOk :=
  ⟨⟨_, seed_env⟩, ⟨_, badMasterData_not_env⟩⟩

end Spec.Seed

/-!
## 根拠と対応

- 根拠: [ADR 8f18](../../docs/decision/8f18-fare-source-model-and-shared-vectors.md)（シードから共有入力を作る）、
  [ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)（投入日 2026-11-01）、
  [ADR ce36](../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)（翌日着の便）、
  [ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)・[ADR cd33](../../docs/decision/cd33-spec-nondet-types-and-env-pre.md)
  （境界の検証と入口の環境の前提）
- 既知差異: D-031（[abstraction.md](../../docs/spec/abstraction.md#既知差異)）
- 移植元モデルのシード: [`SourceModel.Db`](../SourceModel/Db/)（`MasterSeed`・`FlightSeed`・`MemberSeed`）
- 共有入力: `conformance/fixtures/`（[conformance.md](../../docs/spec/conformance.md#共有入力fixtures)）
-/
