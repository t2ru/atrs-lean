---
type: Backlog Item
title: "Spec のモジュール構成を整理し、モジュール文書を仕様書の形にする"
description: "lean/Spec を層と機能名で並べ直し（Spec.Env・Spec.World・Spec.Port・Spec.Reserve・Spec.Auth・Spec.Report・Spec.Validation・Spec.Seed.Master など）、全モジュールの文書を、経緯を除いた仕様書の形（題・区分・前文・本文・根拠と対応）にそろえる。"
tags: [backlog, spec, documentation, lean]
id: "d74f7265-8960-4ad3-92f3-d2e7d09ee12d"
state: done
depends_on: ["63a3a945-ab83-421c-a7ae-62e3a6054bbf"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-04T15:00:00+09:00
---

# Spec のモジュール構成を整理し、モジュール文書を仕様書の形にする

## 目的

`Spec` の本を、序から順に読める業務仕様書にする（[ADR b385](../decision/b385-spec-module-layout-and-book-shaped-docs.md)）。

## 範囲

- `lean/Spec` のファイルの移動と、完全名の改名（`tools/docs/lean-renames-spec.json`・`tools/docs/spec_layout.py`）。参照（`Abstraction`・`Tests`・ベクタ・manifest・文書）の追随。
- `Spec.Port` を `Spec.World` と文書だけの `Spec.Port` に分ける。`Spec.EnvPre` を `Spec.Env` にし、シードの定理を `Spec.Seed` へ移す。生成物の `Spec.Seed` を `Spec.Seed.Master` にし、生成器を合わせる。
- 全モジュールの文書の書き直し（題・区分・前文・根拠と対応。散文と Lean の食い違いの修正）。
- スキル okf-bundle の `docmv.py` が Lean のモジュール文書のリンクを張り直すようにする。スキル spec-pivot の文書の規則に、経緯を書かないことと「根拠と対応」節を足す。

## 対象外

- 散文どうしの食い違いのうち、意図の判断が要るもの（`TODO(spec)` として残す。プロジェクトオーナーの判断を待つ）
- `Spec.Model` の分割、SPEC 課題の補題の下位モジュールへの分離

## 完了条件

- [x] `lake build`・`lake test`・`layout-check` が通る
- [x] 全数の検査（`mise run ci` のうち、この環境で動く段）が通る
- [x] 本の目次が、序・基礎・ドメイン・環境・状態とポート・機能・外部契約・シードの順になる

## 参照

- [ADR b385](../decision/b385-spec-module-layout-and-book-shaped-docs.md)、[ADR 68a6](../decision/68a6-business-spec-in-lean-module-docs-and-book.md)、[ADR f779](../decision/f779-whole-lean-source-book.md)
- スキル spec-pivot の [ADR f3c5](../../.agents/skills/spec-pivot/references/docs/decision/f3c5-spec-module-docs-without-history.md)
