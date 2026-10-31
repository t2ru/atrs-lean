//! `impact`: 変化の起点から、証明のグラフ（参照）に沿って影響を求める（port-lang の upgrade.md の手順 5。references/docs/traceability.md#道具）。
//!
//! 移植元の起点（移植元のロケータ・`SourceModel` などの名前）は、次の順に伝播させる。
//!
//! 1. 注釈にそのロケータを持つ定義と、同じ側のモデル層でそれを参照する定義
//! 2. それを参照の閉包に含む `Abstraction` の R 課題
//! 3. その R 課題の閉包にある `Spec` の定義
//! 4. その `Spec` を閉包に含む `Refinement` の R 課題、その閉包の `TargetModel` の定義と `rust:` ロケータ
//!    （`Spec` を変える場合だけ影響する。分けて示す）
//!
//! 移植先の起点（`rust:`・`TargetModel` の名前）は、逆向きに `Refinement` の R 課題と `Spec` まで示す。
//!
//! あわせて、影響を受ける `SourceModel`・`Spec`・`TargetModel` の定義に箇所の印（`@[gap]`）を持つギャップを、
//! 見直すギャップとして示す（references/docs/lean/trace-attributes.md#ギャップの登録簿）。
//! 移植元ソースと移植先ソースを直接は結ばない（references/docs/traceability.md#検査済みハッシュ）。

use crate::lean::{closure, split_hash, Dump, Obligations};
use serde::Serialize;
use std::collections::{BTreeSet, HashMap};


#[derive(Serialize, Debug, Default, PartialEq)]
pub struct Impact {
    pub source_defs: Vec<String>,
    pub abstraction: Vec<String>,
    pub spec: Vec<String>,
    /// `Spec` を変える場合
    pub refinement_if_spec_changes: Vec<String>,
    pub target_defs_if_spec_changes: Vec<String>,
    pub rust_if_spec_changes: Vec<String>,
    /// 移植先の起点から
    pub target_defs: Vec<String>,
    pub refinement: Vec<String>,
    pub spec_of_target: Vec<String>,
    /// 見直すギャップ（`<ID> (<宣言>)`。印の付いた定義が上のどれかに含まれる）
    pub gaps: Vec<String>,
    /// どの定義にも当たらなかった起点
    pub unmatched: Vec<String>,
}

/// 注釈のロケータが起点に当たるか（`lang:java` は `lang:java#…` にも当たる）。
fn hits(seed: &str, loc: &str) -> bool {
    loc == seed || ((seed.starts_with("lang:") || seed.starts_with("dep:")) && loc.starts_with(&format!("{seed}#")))
}

pub fn impact(dump: &Dump, obligations: &Obligations, seeds: &[String]) -> Impact {
    // 同じ側のモデル層（言語の組は trace/project.json による）
    let source_side: Vec<String> = std::iter::once("SourceModel".to_string()).chain(crate::project::source_langs()).collect();
    let target_side: Vec<String> = std::iter::once("TargetModel".to_string()).chain(crate::project::target_langs()).collect();
    let target_kinds = crate::project::target_kinds();
    let layer: HashMap<&str, &str> = dump.definitions.iter().map(|d| (d.name.as_str(), d.layer.as_str())).collect();
    let mut rev: HashMap<&str, Vec<&str>> = HashMap::new();
    for d in &dump.definitions {
        for r in &d.references {
            rev.entry(r.as_str()).or_default().push(d.name.as_str());
        }
    }
    let mut src0: BTreeSet<String> = BTreeSet::new();
    let mut tgt0: BTreeSet<String> = BTreeSet::new();
    let mut out = Impact::default();
    for s in seeds {
        let mut found = false;
        for d in &dump.definitions {
            let annotated = d.attr("source").iter().chain(d.attr("target")).any(|v| hits(s, split_hash(v).0));
            if annotated || d.name == *s {
                found = true;
                if source_side.contains(&d.layer) {
                    src0.insert(d.name.clone());
                } else if target_side.contains(&d.layer) {
                    tgt0.insert(d.name.clone());
                }
            }
        }
        if !found {
            out.unmatched.push(s.clone());
        }
    }
    // 同じ側のモデル層で、参照する定義へ広げる
    let widen = |start: &BTreeSet<String>, side: &[String]| -> BTreeSet<String> {
        let mut seen = start.clone();
        let mut stack: Vec<String> = start.iter().cloned().collect();
        while let Some(n) = stack.pop() {
            for r in rev.get(n.as_str()).into_iter().flatten() {
                if side.iter().any(|s| s == layer.get(r).unwrap_or(&"")) && seen.insert(r.to_string()) {
                    stack.push(r.to_string());
                }
            }
        }
        seen
    };
    let tasks = |prefix: &str, hit: &BTreeSet<String>| -> (Vec<String>, BTreeSet<String>) {
        let mut names = vec![];
        let mut reach = BTreeSet::new();
        for o in obligations.obligations.iter().filter(|o| o.refines && o.name.starts_with(&format!("{prefix}."))) {
            let c = closure(dump, std::slice::from_ref(&o.name));
            if c.iter().any(|n| hit.contains(n)) {
                names.push(o.name.clone());
                reach.extend(c);
            }
        }
        (names, reach)
    };
    let in_layer = |set: &BTreeSet<String>, ls: &[&str]| -> Vec<String> {
        set.iter().filter(|n| ls.contains(layer.get(n.as_str()).unwrap_or(&""))).cloned().collect()
    };
    let rust_of = |defs: &[String]| -> Vec<String> {
        let mut v: BTreeSet<String> = BTreeSet::new();
        for d in dump.definitions.iter().filter(|d| defs.contains(&d.name)) {
            v.extend(d.attr("target").iter().map(|t| split_hash(t).0.to_string()).filter(|l| target_kinds.contains(&crate::lean::kind_of(l))));
        }
        v.into_iter().collect()
    };

    let src = widen(&src0, &source_side);
    out.source_defs = src.iter().cloned().collect();
    let (abs, abs_reach) = tasks("Abstraction", &src);
    out.abstraction = abs;
    let spec: BTreeSet<String> = in_layer(&abs_reach, &["Spec"]).into_iter().collect();
    out.spec = spec.iter().cloned().collect();
    let (rf, rf_reach) = tasks("Refinement", &spec);
    out.refinement_if_spec_changes = rf;
    out.target_defs_if_spec_changes = in_layer(&rf_reach, &["TargetModel"]);
    out.rust_if_spec_changes = rust_of(&out.target_defs_if_spec_changes);

    let tgt = widen(&tgt0, &target_side);
    out.target_defs = tgt.iter().cloned().collect();
    let (rf2, rf2_reach) = tasks("Refinement", &tgt);
    out.refinement = rf2;
    out.spec_of_target = in_layer(&rf2_reach, &["Spec"]);

    let touched: BTreeSet<&String> = out.source_defs.iter().chain(&out.spec).chain(&out.target_defs)
        .chain(&out.spec_of_target).collect();
    out.gaps = dump.gaps.iter()
        .filter(|g| g.markers.iter().any(|m| touched.contains(m)))
        .map(|g| format!("{} ({})", g.id, g.name))
        .collect();
    out
}

pub fn render(i: &Impact) -> String {
    let mut s = String::new();
    let mut sec = |title: &str, v: &[String]| {
        s += &format!("{title} ({})\n", v.len());
        for x in v {
            s += &format!("  {x}\n");
        }
    };
    sec("1. SourceModel・移植元の LangSemantics", &i.source_defs);
    sec("2. Abstraction の R 課題", &i.abstraction);
    sec("3. Spec", &i.spec);
    sec("4. Refinement の R 課題（Spec を変える場合）", &i.refinement_if_spec_changes);
    sec("   TargetModel（Spec を変える場合）", &i.target_defs_if_spec_changes);
    sec("   移植先ソース（Spec を変える場合）", &i.rust_if_spec_changes);
    sec("移植先の起点: TargetModel・移植先の LangSemantics", &i.target_defs);
    sec("移植先の起点: Refinement の R 課題", &i.refinement);
    sec("移植先の起点: Spec（確認する）", &i.spec_of_target);
    sec("見直すギャップ（@[gap] の印が上の定義にある）", &i.gaps);
    sec("どの定義にも当たらない起点", &i.unmatched);
    s
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lean::{Def, Obligation};

    fn def(name: &str, layer: &str, attrs: &[(&str, &str)], refs: &[&str]) -> Def {
        let mut d = Def { name: name.into(), layer: layer.into(), references: refs.iter().map(|s| s.to_string()).collect(), ..Default::default() };
        for (k, v) in attrs {
            d.attributes.entry(k.to_string()).or_default().push(v.to_string());
        }
        d
    }

    #[test]
    fn propagates_in_layer_order() {
        let dump = Dump {
            definitions: vec![
                def("SourceModel.Fare.calc", "SourceModel", &[("source", "java:A#calc()@11"), ("gap", "D-001")], &[]),
                def("SourceModel.Fare.machine", "SourceModel", &[], &["SourceModel.Fare.calc"]),
                def("SourceModel.Other.x", "SourceModel", &[("source", "java:A#x()@22")], &[]),
                def("Spec.Fare.basic", "Spec", &[], &[]),
                def("Abstraction.Fare.r", "Abstraction", &[], &["SourceModel.Fare.machine", "Spec.Fare.basic"]),
                def("TargetModel.Fare.basic", "TargetModel", &[("target", "rust:app::fare::basic@33")], &[]),
                def("Refinement.Fare.r", "Refinement", &[], &["Spec.Fare.basic", "TargetModel.Fare.basic"]),
            ],
            ..Default::default()
        };
        let obl = Obligations {
            obligations: ["Abstraction.Fare.r", "Refinement.Fare.r"]
                .iter()
                .map(|n| Obligation { name: n.to_string(), ids: vec![], refines: true })
                .collect(),
            ..Default::default()
        };
        let mut dump = dump;
        dump.gaps = vec![
            crate::lean::Gap { name: "Abstraction.Gap.D001".into(), id: "D-001".into(), markers: vec!["SourceModel.Fare.calc".into()], ..Default::default() },
            crate::lean::Gap { name: "Abstraction.Gap.D002".into(), id: "D-002".into(), markers: vec!["SourceModel.Other.x".into()], ..Default::default() },
        ];
        let i = impact(&dump, &obl, &["java:A#calc()".to_string(), "java:Z#none()".to_string()]);
        assert_eq!(i.source_defs, vec!["SourceModel.Fare.calc", "SourceModel.Fare.machine"]);
        assert_eq!(i.abstraction, vec!["Abstraction.Fare.r"]);
        assert_eq!(i.spec, vec!["Spec.Fare.basic"]);
        assert_eq!(i.refinement_if_spec_changes, vec!["Refinement.Fare.r"]);
        assert_eq!(i.target_defs_if_spec_changes, vec!["TargetModel.Fare.basic"]);
        assert_eq!(i.rust_if_spec_changes, vec!["rust:app::fare::basic"]);
        assert!(i.target_defs.is_empty());
        assert_eq!(i.unmatched, vec!["java:Z#none()"]);
        assert_eq!(i.gaps, vec!["D-001 (Abstraction.Gap.D001)"]);

        let j = impact(&dump, &obl, &["rust:app::fare::basic".to_string()]);
        assert!(j.source_defs.is_empty() && j.abstraction.is_empty());
        assert_eq!(j.target_defs, vec!["TargetModel.Fare.basic"]);
        assert_eq!(j.refinement, vec!["Refinement.Fare.r"]);
        assert_eq!(j.spec_of_target, vec!["Spec.Fare.basic"]);
    }

    #[test]
    fn language_version_seed_hits_its_sections() {
        assert!(hits("lang:java", "lang:java#JLS-15.17.1"));
        assert!(!hits("lang:java", "lang:javascript#x"));
        assert!(!hits("java:A#f()", "java:A#f(int)"));
    }
}
