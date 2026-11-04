---
type: Architecture Decision Record
title: "メールアドレスの検証規則は Hibernate Validator の規則を IDN 変換抜きで書き下す"
description: "制約 Email を Hibernate Validator 9.1 の AbstractEmailValidator・DomainNameUtil の規則として言語中立に定義し、IDN.toASCII だけを除外して既知差異 D-011 とする。"
tags: [adr, validation]
id: "ac33c0e6-b9cd-4d5d-a557-7eceb6670a48"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T23:40:00+09:00
sources:
  - id: hv-email
    resource: https://github.com/hibernate/hibernate-validator/blob/9.1.0.Final/engine/src/main/java/org/hibernate/validator/internal/constraintvalidators/AbstractEmailValidator.java
    title: AbstractEmailValidator.java (Hibernate Validator 9.1.0.Final)
  - id: hv-domain
    resource: https://github.com/hibernate/hibernate-validator/blob/9.1.0.Final/engine/src/main/java/org/hibernate/validator/internal/util/DomainNameUtil.java
    title: DomainNameUtil.java (Hibernate Validator 9.1.0.Final)
---

# メールアドレスの検証規則は Hibernate Validator の規則を IDN 変換抜きで書き下す

## Context and Problem Statement

原典のメール欄（`repMail`, `mail`, `reEnterMail`）には `jakarta.validation.constraints.Email` が付いており、判定は Hibernate Validator 9.1.0.Final の `AbstractEmailValidator`[^hv-email] と `DomainNameUtil`[^hv-domain] が行う。
ドメイン部の判定では `java.net.IDN.toASCII`（IDNA 2003）で ASCII に変換してから長さを数える。
IDNA の変換は Unicode の正規化と対応表に依存するため、言語中立な仕様として書き下すのも、Lean で証明するのも重い。
ただし ATRS のメール欄には `HalfWidth`（U+0020–U+007E）も付いているので、非 ASCII の入力は Email の判定とは別に必ず不合格になる。

## Decision Drivers

* [Spec] を言語中立に書け、どの言語でも同じ結果になること
* 原典と一致する入力の範囲を明確にすること
* 業務上の結果（合格か不合格か）を変えないこと

## Considered Options

* HV の規則を書き下し、IDN 変換だけを除外する
* IDN 変換まで含めて HV の規則を忠実に書き下す
* ASCII に限った簡略規則とし、非 ASCII を含む値は常に不合格とする

## Decision Outcome

Chosen option: "HV の規則を書き下し、IDN 変換だけを除外する", because 非 ASCII の入力は `HalfWidth` で必ず不合格になるので、業務上の合否は変わらない。違いが出るのは、Email のエラーが追加で報告されるかどうかだけである。

* 規則は [spec/input-validation.md](../../lean/Spec/Prim/Text.lean#email) に定義する。
* ドメイン部の長さは、IDN 変換の後の長さではなく、スカラ値の数で数える。
* 非 ASCII のドメインで生じる差は、既知差異 [D-011](../spec/abstraction.md#既知差異) として記録する。一致の前提は「ドメイン部が ASCII だけからなる」である。

### Consequences

* Good, because 正規表現と長さの比較だけで定義でき、Lean でも Rust でも同じ実装になる
* Bad, because 非 ASCII のドメイン（例 `a@例え.jp`）では、Email のエラーが報告されるかどうかが [Source] と異なりうる

### Confirmation

* `Abstraction` の課題 ABS-032 で、ASCII のドメインについて [Source] と [Spec] の Email 判定が一致することを証明する。
* `validation` の適合テストベクタに、ローカル部 64/65 文字、ドメイン末尾のドット、`[IPv4]`、`[IPv6:…]`、引用符付きローカル部の境界例を置く。

## Pros and Cons of the Options

### HV の規則を書き下し、IDN 変換だけを除外する

* Good, because 言語中立で、ASCII の範囲では原典と完全に一致する
* Bad, because 既知差異が 1 件増える

### IDN 変換まで含めて忠実に書き下す

* Good, because 差異が無い
* Bad, because IDNA 2003 の対応表を仕様に持ち込むことになり、移植先ごとに同じ実装を用意するのが難しい

### ASCII に限った簡略規則

* Good, because 最も単純
* Bad, because 非 ASCII のローカル部（HV は U+0080–U+FFFF を許す）でも差が出て、差異の範囲が広がる

## More Information

* [spec/input-validation.md](../../lean/Spec/Validation.lean), [spec/abstraction.md](../spec/abstraction.md)
* [ADR 10a5](10a5-text-length-and-character-classes.md)（文字列長と文字クラス）

[^hv-email]: hibernate-validator 9.1.0.Final `AbstractEmailValidator`
[^hv-domain]: hibernate-validator 9.1.0.Final `DomainNameUtil`
