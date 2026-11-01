# Directory Update Log

## 2026-11-01
* **Creation**: スキル work-records を作った。版は 0.1。
  * スキル spec-pivot の道具 `scripts/docs/ids.py` を `scripts/ids.py` に移した。設定を、spec-pivot の `trace/project.json` の `ids` から、リポジトリのルートの `.work-records.json` に移した。
  * 移植に固有の検査を一般化した。機能と作業項目の対応表の検査（`features`）は、ID を書く JSON の欄の宣言 `id_fields` にした。登録簿の旧番号の検査（`registers`）と旧番号からの書き換え（`migrate`。`legacy`・`backlog_index`）は削除した（適用先の道具に移した）。
  * 意思決定記録・作業項目の形の検査（A1・B1）を、スキル okf-bundle の `okf_check.py` から `ids.py check` に移した（`outcome_markers` は設定のキー）。`--self-test` と違反例 `scripts/fixtures/` を足した。
  * [rules/records.md](rules/records.md) に、spec-pivot の rules/maintenance.md の「意思決定記録」「作業項目」「ID と参照」「持ち出せること」節と、適用先の記録の規約の汎用の部分をまとめた。雛形 `assets/templates/` を足した。
  * 来歴: スキル spec-pivot の ADR 22b4（道具の元の決定は spec-pivot の ADR 87b9）。適用先 ATRS の ADR 625d（UUID の ID は ATRS の ADR f57e）。
