---
type: Overview
title: "スキルの意思決定記録"
description: "スキル spec-pivot の意思決定記録（MADR 4.0）の索引。"
tags: [adr, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:30:00+09:00
---

# スキルの意思決定記録

書き方は [maintenance.md](../rules/maintenance.md#意思決定記録decision)。並びは日付の順。

| ID | 題名 | decision_status | 日付 |
| --- | --- | --- | --- |
| 6edf | [スキル spec-pivot の Lean パッケージを assets/lean/ に置く](6edf-lean-package-under-skill-assets-lean.md) | accepted | 2026-10-30 |
| 0eea | [追跡の道具の未確定事項（本文ハッシュ・正規化・ロケータの細部・機能と backlog の対応）を決める](0eea-trace-tooling-unresolved-details.md) | accepted | 2026-10-30 |
| 9cd9 | [rehash・diff・impact の細部（検査の登録・注釈の書き換え・改名・出典の検査）を決める](9cd9-rehash-diff-impact-details.md) | accepted | 2026-10-31 |
| 0b83 | [移植が成り立つ条件をスキルに明示し、進め方の既定（評価・判断点・ゲート・敵対的レビュー・記録）を補う](0b83-porting-conditions-and-workflow.md) | accepted | 2026-10-31 |
| 7fe4 | [追跡属性の仕組み（Trace）をスキル spec-pivot の assets に移す](7fe4-move-trace-attributes-to-skill.md) | accepted | 2026-10-31 |
| edc8 | [アプリに依存しない道具と Lean のライブラリをスキル spec-pivot へ移し、ATRS 固有の値を trace/project.json に集める](edc8-skill-scripts-and-generic-lean-libraries.md) | accepted | 2026-10-31 |
| 87b9 | [スキルの文書を references/docs/ の OKF バンドルにし、スキルの決定と作業項目をスキルで持つ](87b9-skill-docs-as-okf-bundle.md) | accepted | 2026-10-31 |
| 330e | [OKF バンドルとリンクの検査の道具 okf_check.py を置き、規則を設定のプロファイルで与える](330e-okf-bundle-check-tool.md) | accepted | 2026-10-31 |
| c08b | [スキルの assets の Lean の検査を名前空間 Test.<ライブラリ> にまとめる](c08b-test-namespace-for-skill-asset-tests.md) | accepted | 2026-10-31 |
| 748c | [スキルの文書を spec/・rules/・guide/・lang/ に分け、移動の道具 docmv.py を置く](748c-skill-docs-category-directories.md) | accepted | 2026-10-31 |
| ab9e | [義務の束 Machine.Adequate、機械の並置によるトップレベルの主定理、側ごとの段階導入](ab9e-adequate-bundle-sum-and-side-staging.md) | superseded（[6b4b](6b4b-preserves-refines-abstracts.md)） | 2026-10-31 |
| 1a30 | [Lean の宣言をモジュール名の下に置き、機能の証明課題を機能のモジュールに置く](1a30-lean-module-namespace-layout.md) | accepted | 2026-10-31 |
| 6b4b | [adequate の廃止: A abstracts B = A preserves B ∧ B refines A](6b4b-preserves-refines-abstracts.md) | accepted | 2026-10-31 |
| cfad | [この方法を Spec Pivot と名付け、スキルの名前を spec-pivot に改める](cfad-name-the-method-spec-pivot.md) | accepted | 2026-11-01 |
| 1f75 | [Java の式の構文 java! と Spring の Assert を言語パックに置き、移植元のモデルを原典と同じ字面で書く](1f75-java-expression-syntax-and-spring-assert.md) | accepted | 2026-11-01 |
| 8a3c | [移植元のモデルを原典のソースツリーの形に並べ、対応を TR-M で検査し、対照表を trace review で生成する](8a3c-mirror-layout-check-and-review-view.md) | accepted | 2026-11-01 |
| 8cb7 | [スキルの Python の道具を uv で実行する](8cb7-run-python-tools-with-uv.md) | accepted | 2026-11-01 |
| 7d3a | [Java の適合テストの道具 conformance-kit を assets に置き、HTTP レベルの原典実行の方法を言語パックに書く](7d3a-java-conformance-kit-and-http-origin-run-method.md) | accepted | 2026-11-01 |
| 288a | [「オラクル」を「原典実行」（origin-run）と呼び替える](288a-rename-oracle-to-origin-run.md) | accepted | 2026-11-01 |
| a303 | [同じ状態を共有する機能の合成子 Machine.alt、トランザクションの取消、LocalTime・List.get・StringUtils・TIMESTAMP の写し](a303-shared-state-machine-alt-and-transaction.md) | accepted | 2026-11-01 |
| cd90 | [命令型の計算の検証の道具: EStateM の Hoare 三つ組と、計算の形を求める簡約のタクティク](cd90-estate-hoare-and-simp-tactics.md) | accepted | 2026-11-02 |
| 22b4 | [OKF のバンドルの管理と記録の管理を、別のスキル okf-bundle・work-records に分ける](22b4-split-okf-and-records-skills.md) | accepted | 2026-11-01 |
| 89f2 | [layout-check のモジュールの組を、組ごとに別のプロセスで判定する](89f2-layout-check-one-process-per-group.md) | accepted | 2026-11-01 |
| b187 | [モデルの評価を速くする実装は、元の定義と等しいことの定理を付けた @[csimp] で与える](b187-proven-csimp-for-evaluating-models.md) | accepted | 2026-11-01 |
| cb1f | [差異の登録簿の棚卸しの手順を方法の文書に置く](cb1f-gap-inventory-procedure.md) | accepted | 2026-11-01 |
