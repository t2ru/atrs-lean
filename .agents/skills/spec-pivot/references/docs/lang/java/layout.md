---
type: Reference
title: "Java: ソースの構成と Lean 名前空間の対応"
description: "Java のソースの構成と、Lean の名前空間の対応。"
tags: [java, language-pack]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Java: ソースの構成と Lean 名前空間の対応

## 移植元として（原典を読む）

- `SourceModel` のモジュールは、原典のソースツリーと同じ形に並べる（[ADR 8a3c](../../decision/8a3c-mirror-layout-check-and-review-view.md)）。人が原典のファイルを開けば、同じパスにモデルの写しがある。
  - 原典のクラス `<prefix>.<pkg>.<Class>` は、モジュール `SourceModel.<Pkg>.<Class>` に写す。`<prefix>` はプロジェクトの共通の接頭辞、`<Pkg>` はパッケージの各成分の先頭を大文字にしたもの（`case = upper-camel`。`same` ならそのまま）。
    例: `jp.co.ntt.atrs.domain.service.b0.TicketSharedServiceImpl` → `lean/SourceModel/Domain/Service/B0/TicketSharedServiceImpl.lean`。
  - クラスの型（注入された依存・`@Value` の値・欄）は、モジュールと同じ名前の構造体にする。メソッドは `<Class>.<method>`、定数は原典の綴り、コンストラクタは `<Class>.new`、private のメソッドも同じ名前で写す。
  - 1 つのクラスのメソッドは、業務機能が違っても同じモジュールに置く。どの機能に属するかは `trace/features.json` の `lean` に、メソッドの粒度で書く。
  - Mapper の XML の文と resultMap は、同じパッケージのリポジトリのモジュール（`…Repository`）に、文の id・resultMap の id の名前で写す。enum の `name()`・`valueOf` は enum のモジュールに置く。
  - 原典のクラスに当たらないもの（具体機械、DB の状態、フレームワークの値、設定）は、ソースツリーの根（`roots`）の外に置く。
  - 対応は `trace check` の TR-M が確かめる（設定は `trace/project.json` の `source.mirror`。[traceability.md](../../spec/traceability.md#検査)）。原典とモデルを並べた対照表は `trace review` が生成する。
- 式・検査の語彙は原典と同じ字面で書く（[semantics.md](semantics.md#式の構文-java)・[原典の語彙とモデルの語彙](semantics.md#原典の語彙とモデルの語彙)）。
- 1 つの `SourceModel` 定義が、複数のメソッドに対応してよい（`@[source]` に複数のロケータを並べる。インタフェースと実装クラスのメソッドなど）。逆に、1 つのメソッドを複数の定義で分けて写してもよい。
- SQL（MyBatis の Mapper、JPA の JPQL）は SQL パックで写し、Java 側では呼び出しと結果の対応づけだけを写す。
- 原典の `@Transactional` などの境界は、`SourceModel` のユースケースの境界として写す。

## 移植先として（Java を書く）

> **未整備:** 次の項目を、Java を移植先にするときに決める。

- パッケージ構成: 業務機能ごとのパッケージを、`TargetModel` の下位名前空間名にそろえる。
- 純粋なコアと、アダプタ（永続化・HTTP・時計）を分ける。
- `TargetModel` の JML による写しの置き場所と、追跡タグ `/** trace: models <TargetModel の完全名> @<Merkle ハッシュ> */` の書き方。
- 禁止事項: `double`/`float` の業務計算への使用、暗黙の `now()`、null を返す API。
