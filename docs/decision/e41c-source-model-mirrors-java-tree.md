---
type: Architecture Decision Record
title: "SourceModel を原典の Java のソースツリーと同じ形に並べ、式・語彙を原典と同じ字面にする"
description: "SourceModel が原典を正しく写しているかを、人が Java と見比べて確かめられるようにする。モジュールを原典のクラスと 1 対 1（jp.co.ntt.atrs.<pkg>.<Class> → SourceModel.<Pkg>.<Class>。パッケージの成分は先頭を大文字に）にし、式は java! で、検査は Spring の Assert の名前で書く。配置と名前の対応は trace check の TR-M が確かめ、対照表は trace review が生成する。"
tags: [adr, source-model, traceability, review, java]
id: "e41cae21-da46-47e6-b333-320a26234b10"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T18:00:00+09:00
---

# SourceModel を原典の Java のソースツリーと同じ形に並べ、式・語彙を原典と同じ字面にする

## Context and Problem Statement

`SourceModel` と原典の一致は、決定論的な手段（ベクタ・オラクル・差分実行）で確かめる（[ADR c336](c336-foundational-principles.md) の原則 1）。
それとは別に、人が Lean と Java を見比べて「正しく写していそうだ」と確かめられることは、手段の届かない部分（[assurance.md](../spec/assurance.md)）の検討や、
レビュー・版上げの差分の確認に要る。これまでの `SourceModel` には、次の妨げがあった。

* 式の形が違う。Java の `(int) ((basicFareOfRoute + boardingClassFare) * (multiplicationRatio * 0.01))` が
  `jd2i (jdmul (jd (j32add …).val) (jdmul (jd multiplicationRatio.val) (jdLit "0.01")))` になる。`J32 = BitVec 32` なので、`/` と書くと符号無しの除算になる。
* 配置が違う。`SourceModel/Fare.lean` は 3 クラス分を持ち、`TicketSharedServiceImpl` のメソッドは `Fare.lean` と `FlightSearch.lean` に分かれていた。
  `Model.lean` は 9 クラス、`Repository/Mapping.lean` は 5 つの Mapper の resultMap を持っていた。
* 語彙が違う。Spring の `Assert.isTrue`・`notNull`・`notEmpty`・`hasText` を、`jAssert`・`assertNotEmpty`・`match … | none => throw …` で書いていた。
* 並べて見る手段が無い。`@[source]` とインベントリはあるが、両方を並べた表示が無い。

## Decision Drivers

* 原典の構造を写す（スキルの [lang/lean/rules.md](../../.agents/skills/spec-pivot/references/docs/lang/lean/rules.md#書き方)）。抽象化は `Abstraction` の仕事である
* 見比べやすさを、人の注意ではなく決定論的な検査で保つ
* 証明（`Abstraction`）を壊さない。式の書き方を変えても、展開した項は同じにする
* アプリに依存しない道具・構文はスキルに置く（[ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md)）

## Considered Options

* 原典のクラスと 1 対 1 のモジュール（`SourceModel.Domain.Service.B0.TicketSharedServiceImpl`）にし、パッケージの成分は先頭を大文字にする
* 同じく 1 対 1 で、パッケージの成分は Java のまま小文字にする（`SourceModel.domain.service.b0.TicketSharedServiceImpl`）
* 業務機能ごとのモジュールのまま、`@[source]` と対照表だけで対応をとる

## Decision Outcome

Chosen option: "原典のクラスと 1 対 1 のモジュールにし、パッケージの成分は先頭を大文字にする", because Lean の慣習（モジュールは UpperCamel）に沿いつつ、
大文字にする規則だけで原典のクラスと機械的に対応し、検査（TR-M）で配置を確かめられるからである。業務機能ごとのままでは、1 つのクラスが複数のファイルに分かれる。

* 配置: 原典のクラス `jp.co.ntt.atrs.<pkg>.<Class>` は `lean/SourceModel/<Pkg>/<Class>.lean`（モジュール `SourceModel.<Pkg>.<Class>`）に写す。
  クラスの型はモジュールと同じ名前（`SourceModel.Domain.Service.B0.TicketSharedServiceImpl`）、メソッドは `<Class>.<method>`、定数は Java の綴り
  （`TicketSharedServiceImpl.MULTIPLICATION_RATIO_IN_NORMAL_TIME`）、コンストラクタは `<Class>.new` とする。Mapper の XML の文と resultMap は、
  同じパッケージのリポジトリのモジュール（`Domain.Repository.Route.RouteRepository.findAll`・`routeMap`）に写す。enum の `name()`・`valueOf` は
  enum のモジュール（`Domain.Model.BoardingClassCd.valueOf`）に置く。
* 原典のクラスに当たらないもの（具体機械 `FareQuery`・`MasterQuery`・`FlightSearchQuery`、DB の状態 `Db.Schema`・`Db.FlightSeed`、MyBatis の型の対応
  `Db.MyBatis`、TERASOLUNA のコードリスト `Gfw.CodeList`、設定 `AtrsProperties`）は、原典のソースツリーの外（`Domain`・`App`・`Config`・`Api` の外）に置く。
* 式: Java の式はスキルの `java!` で書く（例: `let fare ← java! boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum`）。
  展開した項は原始関数の項と同じで、証明は変えない（[スキルの ADR 1f75](../../.agents/skills/spec-pivot/references/docs/decision/1f75-java-expression-syntax-and-spring-assert.md)）。
* 語彙: Spring の検査はスキルの `LangSemantics.Java.Spring.Assert` で、原典と同じ名前で書く。
* 検査と表示: 配置と名前の対応は `trace check` の TR-M が確かめる。Java と Lean を並べた対照表は `trace review` が生成する（CI の artifact。commit しない。
  [スキルの ADR 8a3c](../../.agents/skills/spec-pivot/references/docs/decision/8a3c-mirror-layout-check-and-review-view.md)）。ATRS の設定は
  `trace/project.json` の `source.mirror`（接頭辞 `jp.co.ntt.atrs`、根 `Domain`・`App`・`Config`・`Api`）。
* 改名は対応表 `tools/docs/lean-renames-mirror.json` で一度に行った（`rename.py`）。`trace/features.json` の `lean` と `trace/checks.json` の `covers` は、
  新しい名前空間に合わせた。

### Consequences

* Good, because Java のファイルを開けば、同じパスの Lean のファイルに写しがある。1 つのクラスが 1 つのファイルにまとまる
* Good, because 式・検査の字面が原典と同じになり、行ごとに見比べられる
* Bad, because ファイルの数が増える（`SourceModel` は 15 から 46 ファイル）。名前が長くなる（`BoardingClassProvider.getBoardingClass` のように修飾して呼ぶ）
* Bad, because 原典のパッケージの名前（`boardingclass`）を先頭だけ大文字にするので、Lean の名前（`Boardingclass`）は読みにくいことがある

### Confirmation

`tools/ci/lean.sh` が、`lake build`・`lake test`・`layout-check`・`trace check`（TR-M を含む）を通すこと。`rename.py check tools/docs/lean-renames-mirror.json` が、
対応表のほかに旧い名前を見つけないこと。

## More Information

* 作業項目: [backlog cb06](../backlog/cb06-source-model-review-aids.md)
* 規則: スキルの [lang/java/layout.md](../../.agents/skills/spec-pivot/references/docs/lang/java/layout.md#移植元として原典を読む)
