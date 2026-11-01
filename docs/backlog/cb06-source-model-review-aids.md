---
type: Backlog Item
title: "SourceModel を原典と見比べやすくする（ソースツリーの形・java!・Assert・TR-M・対照表）"
description: "SourceModel と原典の Java を人が見比べて正しそうであることを確かめられるよう、モジュールを原典のソースツリーと同じ形に並べ、式・検査を原典と同じ字面で書き、対応を TR-M で検査し、対照表を trace review で生成する。"
tags: [backlog, source-model, review, traceability, java]
id: "cb0666c6-1a6a-4413-bc8a-97393312c501"
state: done
depends_on: ["0be7c5d4-01d9-43f4-a50d-227f174830f0", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T18:00:00+09:00
---

# SourceModel を原典と見比べやすくする（ソースツリーの形・java!・Assert・TR-M・対照表）

## 目的

`SourceModel` が原典を正しく写しているかを、人が原典の Java と並べて確かめられるようにする。原典との一致の根拠は、これまでどおり決定論的な手段
（ベクタ・差分実行・証明）であり、この項目はその外側の確認（レビュー・版上げの差分・保証の限界の検討）を助ける。

## 範囲

- 式: Java の式の構文 `java!`（スキルの `LangSemantics.Java.Expr`）。運賃計算・空席照会・Provider の式を、原典と同じ字面で書く
- 語彙: Spring の `Assert`（スキルの `LangSemantics.Java.Spring`）。`jAssert`・`assertNotEmpty`・`assertHasText` と、`null` の `match` を置き換える
- 配置: `SourceModel` のモジュールを、原典のクラスと 1 対 1 に並べる（`jp.co.ntt.atrs.<pkg>.<Class>` → `SourceModel.<Pkg>.<Class>`）。改名の対応表 `tools/docs/lean-renames-mirror.json`
- 検査: `trace check` の TR-M（配置・名前・引数・欄）。`trace/project.json` の `source.mirror`
- 表示: `trace review` の対照表（`build/review/`。CI の artifact）
- 文書: スキルの言語パック（`lang/java/semantics.md`・`layout.md`）、traceability.md、ADR（ATRS の e41c、スキルの 1f75・8a3c）

## 対象外

- getter の呼び出し（`flight.getFlightMaster().getRoute()`）の構文。モデルは欄の参照と `deref` で書く
- 移植先（`TargetModel`・Rust）の側の同様の仕組み。Rust のコードができてから決める

## 完了条件

- `tools/ci/lean.sh` が通る（`lake build`・`lake test`・`layout-check`・`trace check`。TR-M1・TR-M3 は運賃計算・マスタ・空席照会で失敗扱い）
- `Test.LangSemantics.JavaExpr` が、`java!` の展開と原始関数の項が構文として同じことを確かめる
- `trace review` が、原典のクラスごとのページと索引を生成する

## 結果

- 完了（2026-11-01）。`SourceModel` は 15 から 46 ファイルになった。`Abstraction` の証明は、改名と `simp` の補題（`pure_bind`・`Assert.notNullValue_some`）の追加だけで通った。
- TR-M が、原典との名前の食い違いを見つけて直した: `FareTypeProvider` の欄（原典 `fareTypeMap`、モデル `fareTypeCodeMap`）、引数の名前（`getBoardingClass`・`getFareType`・`addFareTypeVacantInfo`・`AtrsBusinessException.new`・`toFlightList`）。
- TR-M2（名前）・TR-M4（欄）の警告は、SQL の写しの補助の定義（`vacantSeatCond` など）と、環境から受ける欄（`TicketSearchServiceImpl` の `today`・`sharedClock` など）である。

## 参照

- [ADR e41c](../decision/e41c-source-model-mirrors-java-tree.md)
- [スキルの ADR 1f75](../../.agents/skills/spec-pivot/references/docs/decision/1f75-java-expression-syntax-and-spring-assert.md)・[スキルの ADR 8a3c](../../.agents/skills/spec-pivot/references/docs/decision/8a3c-mirror-layout-check-and-review-view.md)
