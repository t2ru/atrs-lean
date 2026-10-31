---
type: Backlog Item
title: "ギャップの証明の状態を Lean で表す"
description: "Trace.Gap に証明の状態 Evidence を足し、obligation-check（GK）で裏付けの宣言と照合する。ATRS の登録簿の 30 件に状態を与え、否定の定理と opaque の主張に @[gap] を付け、生成する表に証明の状態の列を足す。"
tags: [backlog, lean, traceability, gap]
id: "c27dc8ff-3a6d-4e3d-aae0-5c31ce05b7af"
state: done
depends_on: ["38fb13cc-95c9-4e28-9758-7d94f97dcc39"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:00:00+09:00
---

# ギャップの証明の状態を Lean で表す

## 目的

[ADR 6ab4](../decision/6ab4-gap-evidence-states-without-axioms.md) のとおり、ギャップが証明できない理由を、公理・`sorry` を使わずに Lean の宣言で示す。

## 範囲

- スキル
  - `Trace.Gap`: `Evidence`、`deviations`、名前の読み取り、種類と状態の検査、JSON
  - `Trace.Obligation`: GK の状態ごとの照合、`pending` の G9 の警告
  - `TraceTest`: 状態ごとの正例・違反例
  - `scripts/trace`: 表の「証明の状態」の列、TR-K の `pending`、モデル外の印から主張を除く
  - `scripts/ci/check_obligations.py`: obligation-check の警告を出す
  - 文書: `lean/trace-attributes.md`・`architecture.md`・SKILL.md（版 0.7）
- ATRS
  - `lean/Abstraction/Gap.lean` の 30 件
  - `need_D001`・`need_D002`・`need_D012`・`need_D027` の `@[gap]`、`Spec.MasterData.MD5` の `@[gap "D-005"]`
  - 文書: ADR 6ab4、abstraction.md・assurance.md（生成した表と本文）、atrs-porting.md、index・log、AGENTS.md

## 対象外

- 記載なし（作成時に節が無かった。[backlog ddbd](ddbd-okf-bundle-lint.md) で文書の検査を入れたときに、節だけを補った）

## 完了条件

- [x] `tools/ci/lean.sh` が全段通る
- [x] obligation-check の誤り・警告が 0、axiom-check が通る（`opaque` の主張が公理を足さない）
- [x] `TraceTest` の違反例（種類と状態の不一致、別の差異の否定の定理、`@[gap]` の無い裏付け、被覆の循環、`opaque` でない主張、主張の参照、`deviations` の漏れ）を検出する
- [x] R 課題の判定が変わらない

## 参照

- [ADR 6ab4](../decision/6ab4-gap-evidence-states-without-axioms.md)
- [ADR cc24](../decision/cc24-gap-registry-as-lean-attributes.md)
