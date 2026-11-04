import Spec.Env
import Spec.Seed.Master

/-!
# シードデータ（`Spec.Seed`）

-/

/-!
## シードデータ

原典の初期データ[^seed-fixed]。適合テストの共有入力 `conformance/fixtures/master-data.json` の元になる（[backlog 4b0e](../../docs/backlog/4b0e-in-memory-adapters-and-seed-data.md)）。

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
- フライト: 投入日から 120 日後まで（両端を含む）の各日について、便ごとに搭乗クラス×運賃種別の行を作る。空席数は日ごとに 3 パターン（`i mod 3`）で変わる。fixture では投入日を 2026-11-01 とする（[ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)）。

### 会員

7 件（会員番号は `0000000001` から採番）。全員のパスワードは `aaaaa11111`（前回パスワード `aaaaa00000`）の `{pbkdf2}` ハッシュ。

### カード種別

`VIS`（VISA）, `MTR`（MASTER）, `JCB`（JCB）, `DNS`（DNS）, `AMX`（American Express）

シードの全件（空港・区間・便マスタ・搭乗クラス・運賃種別・ピーク時期・機材・カード種別）は、生成器 `tools/conformance/master_fixture.py` が上流の SQL から `conformance/fixtures/master-data.json` に書き出す（投入日 2026-11-01。[ADR 8f18](../../docs/decision/8f18-fare-source-model-and-shared-vectors.md)）。

シードのマスタ・設定の [Spec] の値は `Spec.Seed`（生成器 `tools/conformance/seed_lean.py`。`outsideSpec` の行を除くが、上流のシードには無い）で、MD-1〜MD-8 と設定の不変条件を満たすことを定理 `Spec.Seed.seed_env` で示した（入口の環境の前提 `Spec.Env.masterConfigOk`。前提は、設定とマスタの検証 `Spec.Env.validate` が、不変条件の証明を持つ検証済みの型 `ValidEnv` を返すことである。機械の入力の設定・マスタは生の型のまま持つ（[ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)）。[ADR cd33](../../docs/decision/cd33-spec-nondet-types-and-env-pre.md)）。

翌日着の便（NTT523・NTT528）について、[Source] の空席照会は到着時刻を文字列として整形するだけで（`DateTimeUtil.toFormatTimeString`。`2415` → `24:15`）、[Spec] と一致する。
[Source] の `DateTimeFormatter("HHmm")` が `DateTimeParseException` を投げるのは、予約の往復便の検査で往路便がこの便のとき（`TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight`）で、既知差異 [D-031](../../docs/spec/abstraction.md#既知差異) である（[ADR ce36](../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)。[ADR 8f18](../../docs/decision/8f18-fare-source-model-and-shared-vectors.md) の暫定措置 `outsideSpec` は外した）。

[^seed-fixed]: atrs-initdb/src/sqls/integration-test-postgres/00200〜00250_*.sql
-/

namespace Spec.Seed
open Spec.Env Spec.Env.MasterData

/-! ## シードは環境の前提を満たす -/

set_option maxRecDepth 100000 in
/-- シードの設定とマスタは、入口の環境の前提を満たす。 -/
theorem seed_env : masterConfigOk (Master.config, Master.masterData) :=
  masterConfigOk.of_valid (by decide) (Env.validB_sound (by decide +kernel))

/-- 環境の前提を破る例: 空港コードの重複（MD-1）。 -/
def badMasterData : MasterData :=
  { Master.masterData with airports := ⟨{ val := "HND" }, "x", 1000⟩ :: Master.masterData.airports }

theorem badMasterData_not_env : ¬ masterConfigOk (Master.config, badMasterData) := by
  intro h
  obtain ⟨-, hv⟩ := h.valid
  have h := hv.md1.1
  simp only [badMasterData, List.map_cons, List.nodup_cons] at h
  exact h.1 (by decide)

/-- G8: 環境の前提は自明でない。 -/
theorem masterConfigOk_nontrivial : Machine.Preserves.Nontrivial masterConfigOk :=
  ⟨⟨_, seed_env⟩, ⟨_, badMasterData_not_env⟩⟩

end Spec.Seed
