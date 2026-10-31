//! `manifest`: `trace/manifest.json` と、`docs/spec/traceability.md` の生成区画（references/traceability.md#検査済みハッシュ・0eea）。
//!
//! - ノード: 追跡属性を持つ Lean の定義と、`SourceModel`・`Abstraction`・`TargetModel`・`Refinement` の定義。
//!   インベントリの項目はインベントリのファイルにあるので、ここには写さない。
//! - リンク: 定義 → ロケータ（`source`・`target`）、定義 → ID（`obligation`・`deviation`・`gap`・`nondet`、
//!   ギャップの登録の宣言 `gap_entry`）、
//!   定義 → 文書（`spec_doc`）、移植先の写し → 定義（`model`）。型付き。
//! - 合格した検査（`checks`）: `rehash` が書く。ここでは既存の記録を保ち、現在の注釈に無い
//!   （定義, ロケータ）の記録だけを捨てる（references/traceability.md#道具）。
//! - Merkle はノードに写さない（Lean の変更のたびに manifest が変わるのを避ける。合格の記録にだけ残す）。

use crate::check::Passed;
use crate::inventory::Inventory;
use crate::lean::{split_hash, Dump};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Node {
    pub name: String,
    pub layer: String,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct Link {
    #[serde(rename = "type")]
    pub kind: String,
    pub from: String,
    pub to: String,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub hash: String,
}

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct CheckRecord {
    pub definition: String,
    pub locator: String,
    pub hash: String,
    pub merkle: String,
    /// 合格した決定論的な検査（ベクタ・オラクル・差分実行・Verus など）
    pub checks: Vec<String>,
}

#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq)]
pub struct Manifest {
    pub nodes: Vec<Node>,
    pub links: Vec<Link>,
    #[serde(default)]
    pub checks: Vec<CheckRecord>,
}

const MODEL_LAYERS: &[&str] = &["SourceModel", "Abstraction", "TargetModel", "Refinement"];

pub fn build(dump: &Dump, target: &Inventory, old: &Manifest) -> Manifest {
    let mut nodes = BTreeSet::new();
    let mut links = BTreeSet::new();
    for d in &dump.definitions {
        if d.attributes.values().any(|v| !v.is_empty()) || MODEL_LAYERS.contains(&d.layer.as_str()) {
            nodes.insert(Node { name: d.name.clone(), layer: d.layer.clone() });
        }
        for (attr, vals) in &d.attributes {
            for v in vals {
                let (to, hash) = match attr.as_str() {
                    "source" | "target" => {
                        let (l, h) = split_hash(v);
                        (l.to_string(), h.to_string())
                    }
                    _ => (v.clone(), String::new()),
                };
                links.insert(Link { kind: attr.clone(), from: d.name.clone(), to, hash });
            }
        }
    }
    for g in &dump.gaps {
        links.insert(Link { kind: "gap_entry".into(), from: g.name.clone(), to: g.id.clone(), hash: String::new() });
    }
    for t in &target.model_tags {
        links.insert(Link { kind: "model".into(), from: format!("{}:{}", t.file, t.line), to: t.name.clone(), hash: t.merkle.clone() });
    }
    let current = annotated(dump);
    let mut checks: Vec<CheckRecord> =
        old.checks.iter().filter(|c| current.contains(&(c.definition.clone(), c.locator.clone()))).cloned().collect();
    checks.sort();
    Manifest { nodes: nodes.into_iter().collect(), links: links.into_iter().collect(), checks }
}

/// 現在の `@[source]`・`@[target]` の（定義, ロケータ）。
pub fn annotated(dump: &Dump) -> BTreeSet<(String, String)> {
    let mut out = BTreeSet::new();
    for d in &dump.definitions {
        for attr in ["source", "target"] {
            for v in d.attr(attr) {
                out.insert((d.name.clone(), split_hash(v).0.to_string()));
            }
        }
    }
    out
}

pub fn passed(m: &Manifest) -> BTreeSet<Passed> {
    m.checks
        .iter()
        .filter(|c| !c.checks.is_empty())
        .map(|c| Passed { definition: c.definition.clone(), locator: c.locator.clone(), hash: c.hash.clone(), merkle: c.merkle.clone() })
        .collect()
}

pub fn to_json(m: &Manifest) -> String {
    serde_json::to_string_pretty(m).unwrap() + "\n"
}

pub fn load(path: &std::path::Path) -> Result<Manifest, String> {
    match std::fs::read_to_string(path) {
        Ok(s) => serde_json::from_str(&s).map_err(|e| format!("{}: {e}", path.display())),
        Err(_) => Ok(Manifest::default()),
    }
}

fn region(m: &Manifest, inv: &Inventory, kind: &str, title: &str) -> String {
    let links: Vec<&Link> = m.links.iter().filter(|l| l.kind == kind).collect();
    let records: BTreeMap<(&str, &str), &CheckRecord> =
        m.checks.iter().map(|c| ((c.definition.as_str(), c.locator.as_str()), c)).collect();
    let in_scope = inv.items.iter().filter(|i| !i.out_of_scope).count();
    let covered: BTreeSet<&str> = links.iter().map(|l| l.to.as_str()).collect();
    let covered_n = inv.items.iter().filter(|i| covered.contains(i.locator.as_str())).count();
    let mut s = String::new();
    s.push_str(&format!(
        "{title}: インベントリ {} 件（対象範囲 {in_scope} 件、対象外 {} 件）、対応あり {covered_n} 件。`trace manifest` が生成する（手で編集しない）。\n\n",
        inv.items.len(),
        inv.items.len() - in_scope
    ));
    s.push_str("| ロケータ | Lean の定義 | 本文ハッシュ | 合格した検査 |\n| --- | --- | --- | --- |\n");
    if links.is_empty() {
        s.push_str("| （対応なし） | | | |\n");
    }
    for l in links {
        let checks = records.get(&(l.from.as_str(), l.to.as_str())).map(|c| c.checks.join(", ")).unwrap_or_else(|| "（なし）".into());
        s.push_str(&format!("| `{}` | `{}` | `{}` | {checks} |\n", l.to.replace('|', "\\|"), l.from, l.hash));
    }
    s
}

/// traceability.md の生成区画を書き換えた全文。
pub fn render_doc(doc: &str, m: &Manifest, source: &Inventory, target: &Inventory) -> Result<String, String> {
    let mut out = doc.to_string();
    for (name, kind, inv, title) in [
        ("source-trace", "source", source, "移植元ソース ⇔ SourceModel"),
        ("target-trace", "target", target, "TargetModel ⇔ 移植先ソース"),
    ] {
        let begin = format!("<!-- BEGIN GENERATED: {name} -->\n");
        let end = format!("<!-- END GENERATED: {name} -->");
        let b = out.find(&begin).ok_or(format!("traceability.md: marker {begin:?} not found"))? + begin.len();
        let e = out[b..].find(&end).ok_or(format!("traceability.md: marker {end:?} not found"))? + b;
        out.replace_range(b..e, &region(m, inv, kind, title));
    }
    Ok(out)
}
