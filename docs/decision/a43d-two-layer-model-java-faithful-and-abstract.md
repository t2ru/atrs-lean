---
type: Architecture Decision Record
title: "移植元モデルと抽象モデルの二層で仕様を定義し、関係を証明する"
description: "移植元モデル [Source] と抽象モデル [Spec] を別々に定義し、両者の関係を証明課題とする。"
tags: [adr, model, abstraction]
id: "a43d7889-12f1-468f-8ae5-85616febe9c6"
status: deprecated
decision_status: superseded
superseded_by: "01d40490-d5c8-4239-a74e-c3e8b2004b7c"
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
sources:
  - id: atrs-upstream
    resource: https://github.com/terasolunaorg/atrs/tree/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf
    title: TERASOLUNA ATRS (JavaConfig-Thymeleaf)
---

# 移植元モデルと抽象モデルの二層で仕様を定義し、関係を証明する

## Context and Problem Statement

原典の運賃計算は double と int32 を混在させている。

```
basicFare = (int)((basicFareOfRoute + extraCharge) * (multiplicationRatio * 0.01))
fare      = (int)(basicFare * (1 - (discountRate * 0.01)))   // その後 100 円未満切上げ
```

出典: atrs-domain/.../service/b0/TicketSharedServiceImpl.java `calculateBasicFare`, `calculateFare`

このため、厳密な整数計算とは結果が異なる場合がある。例えば基本運賃 1430 円・割引率 30% では、
Java は `1430 * 0.69999999999999995559… = 1000.999…` を切り捨てて 1000、100 円切上げで **1000 円** を返すが、
厳密計算では `floor(1430 * 70 / 100) = 1001` → **1100 円** となる。
一方、同梱シードデータの範囲（路線運賃は 100 円単位、積算比率 100/125/140、割引率 0/5/10/20/30）では最終運賃の差異は 0 件である（全探索で確認）。

原典の振る舞いをそのまま写すか、意図された業務規則を写すかを決める必要がある。

## Decision Drivers

* 原典との互換性を検証可能な形で保ちたい
* 他言語移植では浮動小数点の再現に依存したくない
* 差異がどの入力で生じ、どの入力で生じないかを **証明** として示したい

## Considered Options

* 二層モデル: 移植元モデル [Source] と抽象モデル [Spec] を別々に定義し、関係を証明する
* 抽象モデル（厳密整数）のみ。Java との差は ADR に記述するだけ
* Java 互換（IEEE 754 double 再現）のみ

## Decision Outcome

Chosen option: "二層モデル", because 原典互換と言語中立性を両立でき、両者の差異を「どの前提の下で一致するか」という定理として明示できるため。

* **[Source] 移植元モデル**（Lean: `SourceModel`）: 原典の観測可能な振る舞いを、Java の意味論（int32 の折り返し、0 方向切捨て除算、IEEE 754 binary64、`BigDecimal` 丸め、UTF-16 長、`Assert` 失敗）ごと再現する。原典の不具合も再現する。Java の基本演算は [ADR 935b](935b-java-primitive-semantics.md) で定義する。
* **[Spec] 抽象モデル**（Lean: `Spec`）: 意図された業務規則を任意精度整数で定義する（[ADR e41d](e41d-exact-integer-arithmetic-in-abstract-model.md)）。他言語移植の第一の対象。各言語の実装（移植先モデル `TargetModel`）が `Spec` を満たすことは具体化証明課題 `Refinement` で扱う。
* **抽象化証明課題**（`Abstraction`）: 抽象化関数 α（[Source] の値を [Spec] の値に写す）と、次の種類の証明義務を [spec/abstraction.md](../spec/abstraction.md) に列挙し、Lean で証明する。
  1. **一致定理**: 前提（例: シードデータのマスタ制約、値域）の下で `α(Source(x)) = Spec(α(x))`。
  2. **差異の特徴付け**: 一般入力での差の向きと大きさ（例: [Source] の運賃 ≤ [Spec] の運賃、差は 100 円以下）。
  3. **安全性**: 前提の下で [Source] に int32 オーバーフローや前提違反が起きないこと。
* 仕様の各定義は [Spec]/[Source] を併記し、差異には `D-NNN` の ID を付ける（[spec-pivot/spec-documents.md](../../.agents/skills/spec-pivot/references/docs/rules/spec-documents.md)）。

### Consequences

* Good, because 原典互換が必要な移植者は [Source]、業務仕様だけが必要な移植者は [Spec] を選べる
* Good, because 差異が証明付きで文書化され、マスタデータ変更時の影響範囲が分かる
* Bad, because 定義と実装とテストベクタがモデル数だけ増える
* Bad, because [Source] の double を証明可能にするため、IEEE 754 の部分的なソフトウェアモデルが必要になる（[ADR 935b](935b-java-primitive-semantics.md)）

### Confirmation

* `Spec` が `SourceModel` に依存していないことをビルド構成で確認する。
* [abstraction.md](../spec/abstraction.md) の全証明義務に対応する Lean 定理が `sorry` 無しで存在することを CI で確認する。
* `conformance/source-model/` のベクタは Java オラクル（[backlog f18c](../backlog/f18c-java-oracle-harness.md)）と一致する。

## Pros and Cons of the Options

### 二層モデル

* Good, because 互換性と移植性の両方を検証可能にする
* Bad, because 工数が最も大きい

### 抽象モデルのみ

* Good, because 単純で移植しやすい
* Bad, because 原典との差異がどの入力で現れるかを機械的に示せない

### Java 互換のみ

* Good, because 原典と完全に一致する
* Bad, because 全移植先に IEEE 754 と Java の丸め規則の厳密再現を強いる。業務規則の意図が式から読み取れない

## More Information

* 層とトップレベル名前空間の名前は [ADR 3e1d](3e1d-language-neutral-top-level-namespaces.md) で確定した（`SourceModel` / `Spec` / `Abstraction` / `TargetModel` / `Refinement`）。

* 浮動小数差異の調査スクリプトの結果: シード範囲（路線運賃 100〜100000 の 100 円単位 × 加算料金 {0, 5000} × 比率 {100, 125, 140} × 割引率 {0, 5, 10, 20, 30}）で最終運賃の差異 0 件。基本運賃を任意の整数 0〜1000000 とし割引率をシードの 5 種に限ると、100 円切上げ後の差異は 188 件（最小例: 1430 円・30%）。
* [spec/abstraction.md](../spec/abstraction.md), [spec/fare-calculation.md](../spec/fare-calculation.md)

* （補足 2026-10-30）本 ADR は [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) で置き換えられた（[ADR c336](c336-foundational-principles.md) の基本原則に合わせるため）。
