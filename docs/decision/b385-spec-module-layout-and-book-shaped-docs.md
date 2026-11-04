---
type: Architecture Decision Record
title: "Spec のモジュールを層と機能名で並べ、モジュール文書を仕様書の形にそろえる"
description: "lean/Spec を、序・基礎・ドメイン・環境（Spec.Env）・状態とポート（Spec.World・Spec.Port）・機能（機能名にそろえた Spec.Reserve・Auth・Report など）・外部契約（Spec.Validation・Spec.Http）・シード（手書きの入口 Spec.Seed と生成物 Spec.Seed.Master）の順と階層に並べ直す。本の目次はこの順になる。モジュール文書から作業の経緯（backlog・段）を除き、根拠の ADR・既知差異・対応するモデル・ベクタは各章の末尾の「根拠と対応」節にまとめる。"
tags: [adr, spec, documentation, lean]
id: "b3858f81-d867-4a59-b1f6-c030e424e155"
status: stable
decision_status: accepted
date: 2026-11-04
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-04T15:00:00+09:00
---

# Spec のモジュールを層と機能名で並べ、モジュール文書を仕様書の形にそろえる

## Context and Problem Statement

`lean/Spec` は、機能を足した順に平置きで増えてきた。そのため、名前が内容と合わないモジュールがあった。

* `Spec.Port` が、抽象状態 `World` と、ポートの契約・実行環境の要件を兼ねていた。
* 予約が `Spec.Ticket` と `Spec.UseCase.Reserve` に分かれ、他の層の機能名（`Abstraction.Reserve`）とそろっていなかった。
* 検証済みの環境の型が `Spec.EnvPre` にあり、生成物のシード（`Spec.Seed`）を import していた。そのため、運賃計算やマスタの参照まで 1,756 行のシードに依存していた。
* 生成物の `Spec.Seed` が、シードの章の入口を兼ねていた。散文を書けなかった。

本（[ADR 68a6](68a6-business-spec-in-lean-module-docs-and-book.md)・[ADR f779](f779-whole-lean-source-book.md)）の目次は、`lean/Spec.lean` の直接の import の順と、モジュール名の階層で決まる。いまの目次は、読む人の順になっていなかった。
モジュール文書には、作業の経緯（backlog の ID、「第 2 段で置く」など）、古い区分の表示（形式化済みなのに「形式化前の草案」）、題の形の不統一が混じっていた。
プロジェクトオーナーは、`Spec` のディレクトリ構成・名前空間構成を整理し、ドキュメンテーションコメントを仕様書として分かりやすくするよう指示した（[backlog d74f](../backlog/d74f-spec-module-layout-and-docs.md)）。

## Decision Drivers

* 本を開いた人が、序から順に読めば仕様の全体が分かること
* 層をまたいで同じ機能名で探せること（`Spec.Reserve`・`Abstraction.Reserve`）
* 仕様の本文に、何が正しいかだけを書くこと
* 名前の規則（NS-1・NS-2。スキルの [ADR 1a30](../../.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md)）と、既存の検査を保つこと

## Considered Options

* 層のディレクトリに並べ直し、機能のモジュールの名前を機能名にそろえる
* 名前は変えず、`Spec.lean` の import の順（目次）と文書だけを整える
* 上に加えて、SPEC 課題の補題を `…/Props` の下位モジュールに分ける

## Decision Outcome

Chosen option: "層のディレクトリに並べ直し、機能のモジュールの名前を機能名にそろえる", because 目次の入れ子が章の構成になり、名前から内容と層をまたぐ対応が分かるため。名前を変えずに順だけ整える案は、`Port`・`EnvPre`・`Ticket` の名前の誤解を残す。補題を分ける案は、`Abstraction` の参照名も広く変わる。それに比べて、本の読みやすさの利得は小さい（補題は章の中の「性質」の見出しの下にまとめれば見分けられる）。

### 構成

`Spec.lean` の import の順（本の目次の順）と、旧の名前は次のとおりである。

| 章 | モジュール | 旧 |
| --- | --- | --- |
| 序 | `Spec`・`Spec.Glossary` | 同 |
| 基礎 | `Spec.Prim.{Int,Date,Time,Format,Text}` | 同 |
| ドメイン | `Spec.Model`・`Spec.Error` | 同 |
| 環境 | `Spec.Env`・`Spec.Env.{Config,MasterData,CodeList}` | `Spec.EnvPre`・`Spec.{Config,MasterData,CodeList}` |
| 状態とポート | `Spec.World`（型 `Spec.World`・`Spec.World.Sequences`）・`Spec.Port`（文書だけ）・`Spec.Nondet` | `Spec.Port` |
| 機能 | `Spec.MasterQuery`・`Spec.Fare`・`Spec.FlightSearch`・`Spec.Reserve`・`Spec.Reserve.FlightSelection`・`Spec.Member`・`Spec.Auth`・`Spec.Report` | `Spec.UseCase.Reserve`・`Spec.Ticket`・`Spec.Authentication`・`Spec.ReservationHistoryReport` |
| 外部契約 | `Spec.Validation`・`Spec.Http` | `Spec.InputValidation` |
| シード | `Spec.Seed`（手書きの入口。`seed_env` など）・`Spec.Seed.{Master,Flight,FlightProps,Member,World}` | `Spec.Seed`（生成物）は `Spec.Seed.Master` |

* `Spec.Model` は 1 つのモジュールのままにした。分けると型の名前が変わり、400 か所を超える参照と `open` を手で直すことになるが、得るものが小さいためである。
* 完全名の対応表は `tools/docs/lean-renames-spec.json`、移動と改名の手順は `tools/docs/spec_layout.py` に残した。文書の移動の道具（スキル okf-bundle の `docmv.py`）は、Lean のモジュール文書の相対リンクも張り直すようにした。
* 主題の違う節を移した。入力検証の制約の語彙と Email の文法は `Spec.Prim.Text` から `Spec.Validation` へ、予約の画面の節は `Spec.Reserve` から `Spec.Http` へ、シードデータの説明は `Spec.Env.MasterData` から `Spec.Seed` へ移した。

### モジュール文書の形

モジュール文書の書き方の規則は、スキル spec-pivot の [spec-documents.md](../../.agents/skills/spec-pivot/references/docs/rules/spec-documents.md) と、スキルの [ADR f3c5](../../.agents/skills/spec-pivot/references/docs/decision/f3c5-spec-module-docs-without-history.md) による。

* 題は「<日本語の題>（`<モジュール名>`）」とし、直下に区分を実態どおりに書く。形式化済みの章は「要約（informative）」である。
* 前文と本文には仕様だけを書く。作業の経緯（backlog・段）は書かない。
* 根拠の ADR・関係する既知差異・対応する `SourceModel`・`Abstraction`・適合テストベクタは、各章の末尾の「根拠と対応」節にまとめる。
* 序（`Spec`）に、区分と記号（`[Spec]`・`[Source]`・`[Spec=Source]`・`D-NNN` など）の凡例と、章の表を置く。
* 散文が Lean と食い違う箇所は、Lean に合わせて直した。散文どうしが食い違い、意図の判断が要る箇所は、`TODO(spec)` として残した。

### Consequences

* Good, because 本の目次が章の構成になり、名前から内容と層をまたぐ対応が分かる。
* Good, because 運賃計算・マスタの参照が生成物のシードに依存しなくなった。
* Bad, because `Spec` の完全名が変わり、`Abstraction`・`Tests`・ベクタ・manifest・文書を一度に書き換えた。過去の対応表と変更履歴は書き換えていない（旧名は `tools/docs/lean-renames-spec.json` で引ける）。

## More Information

* 置き場所と本: [ADR 68a6](68a6-business-spec-in-lean-module-docs-and-book.md)、[ADR f779](f779-whole-lean-source-book.md)
* 名前の規則: スキルの [ADR 1a30](../../.agents/skills/spec-pivot/references/docs/decision/1a30-lean-module-namespace-layout.md)
