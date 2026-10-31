//! `check`: 追跡の検査 TR-*（references/traceability.md#検査済みハッシュ・70eb・0eea）。
//!
//! | ID | 内容 |
//! | --- | --- |
//! | TR-S1 | 対象範囲の移植元の項目が、どの `@[source]` にも覆われていない |
//! | TR-S2 | `@[source]` のハッシュ・版がインベントリ・宣言と違う、または合格の記録（manifest）が無い |
//! | TR-T1 | `TargetModel` の定義に `@[target]` が無い、または移植先の公開項目が覆われていない（生成物は除く） |
//! | TR-T2 | `@[target]` のハッシュ・版が違う、合格の記録が無い、`/// trace: models` の Merkle が違う |
//! | TR-P | 公開操作（`@[source]`・`@[target]` を持つ `SourceModel`・`TargetModel` の定義）が、どの R 課題の参照の閉包にも無い |
//! | TR-PE | 公開操作が、入口の R 課題の参照の閉包に無い |
//! | TR-D | 登録簿（`@[gap_entry]`）の前提型・観測型の D/T と `@[deviation]` が 1 対 1 でない、R 課題に現れない、W 課題が無い、R 課題に無名の仮定（G1・G2） |
//! | TR-K | ギャップの箇所の印（`@[gap]`。裏付けの宣言を除く）が種類と合わない（前提型・観測型・PRE の外に `Spec` と具体側の印が無い、モデル外に印・差異がある、未確定に差異がある）、`@[deviation]` を使う R 課題が登録の R 課題に無い、証明の状態が未証明（`pending`） |
//! | TR-X | 移植元と移植先の直接の接続（層と種類の取り違え、`rust/` の中の移植元のロケータ） |
//! | TR-R | 存在しないロケータ・名前・ID への参照、対応表の抜け、`renames.json` と文書の「出典:」の参照切れ |
//! | TR-G・TR-N | `obligation-check` と `check_obligations.py` の結果 |
//!
//! TR-S1・TR-T1・TR-P・TR-PE・TR-D は、該当する機能（`trace/features.json`）の backlog がすべて
//! `done` なら誤り、そうでなければ警告とする（references/traceability.md#道具）。TR-K の印の不足と未証明の状態は、登録の `backlog`（無ければ R 課題の機能）が
//! すべて `done` なら誤り、そうでなければ警告とする（references/lean/trace-attributes.md#ギャップの登録簿）。それ以外は常に誤り。

use crate::docs::{Feature, Features};
use crate::inventory::Inventory;
use crate::lean::{closure, kind_of, split_hash, Dump, Gap, Obligations};
use crate::project::{source_kinds, source_langs, target_kinds, target_langs};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet, HashMap};

const FEATURE_LAYERS: &[&str] = &["SourceModel", "Abstraction", "TargetModel", "Refinement"];

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Finding {
    pub error: bool,
    pub rule: &'static str,
    pub feature: String,
    pub msg: String,
}

/// 合格した検査の記録（manifest の `checks`。`rehash` が書く）。
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord)]
pub struct Passed {
    pub definition: String,
    pub locator: String,
    pub hash: String,
    pub merkle: String,
}

pub struct Input<'a> {
    pub dump: &'a Dump,
    pub obligations: &'a Obligations,
    pub source: &'a Inventory,
    pub target: &'a Inventory,
    pub features: &'a Features,
    pub entry_tasks: Vec<String>,
    pub r_tasks: Vec<String>,
    /// `trace/upstream.json`
    pub upstream: Value,
    /// `trace/target.json`（無ければ Null）
    pub target_decl: Value,
    pub passed: BTreeSet<Passed>,
    /// `rust/` の中のファイル（パス, 内容）
    pub rust_files: Vec<(String, String)>,
    /// 適合テストベクタの `modelDef`（ファイル, 名前）
    pub model_defs: Vec<(String, String)>,
    /// `trace/renames.json` の（old, new）
    pub renames: Vec<(String, String)>,
    /// 文書の「出典:」のロケータ（`<ファイル>:<行>`, ロケータ）
    pub citations: Vec<(String, String)>,
}

struct Out<'f> {
    features: &'f Features,
    list: Vec<Finding>,
}

impl<'f> Out<'f> {
    fn err(&mut self, rule: &'static str, msg: String) {
        self.list.push(Finding { error: true, rule, feature: String::new(), msg });
    }
    /// 機能の backlog がすべて done なら誤り、そうでなければ警告。機能が無ければ誤り。
    fn staged(&mut self, rule: &'static str, f: Option<&Feature>, msg: String) {
        let (error, feature) = match f {
            Some(f) => (self.features.done(f), f.name.clone()),
            None => (true, "(unassigned)".into()),
        };
        self.list.push(Finding { error, rule, feature, msg });
    }
    /// 登録の backlog がすべて done なら誤り、そうでなければ警告。backlog が無ければ機能で決める（`staged`）。
    fn staged_by(&mut self, rule: &'static str, backlog: &[String], f: Option<&Feature>, msg: String) {
        if backlog.is_empty() {
            return self.staged(rule, f, msg);
        }
        let error = backlog.iter().all(|b| self.features.backlog_done(b));
        self.list.push(Finding { error, rule, feature: format!("backlog {}", backlog.join(",")), msg });
    }
}

pub fn is_version_kind(k: &str) -> bool {
    k == "dep" || k == "lang"
}

/// `lang:<言語>#…` / `dep:<座標>#…` の宣言された版の文字列（`<名前>-<版>`。references/traceability.md#道具）。
pub fn declared_version(decl: &Value, loc: &str) -> Option<String> {
    let (kind, rest) = loc.split_once(':')?;
    let key = rest.split('#').next().unwrap_or(rest);
    match kind {
        "lang" => decl["languages"][key]["version"].as_str().map(|v| format!("{key}-{v}")),
        "dep" => decl["dependencies"].as_array()?.iter().find_map(|d| {
            (d["coordinate"].as_str() == Some(key)).then(|| {
                let artifact = key.rsplit(':').next().unwrap_or(key);
                format!("{artifact}-{}", d["version"].as_str().unwrap_or(""))
            })
        }),
        _ => None,
    }
}

pub fn run(inp: &Input) -> Vec<Finding> {
    let mut out = Out { features: inp.features, list: vec![] };
    let src_items: HashMap<&str, &crate::item::Item> = inp.source.items.iter().map(|i| (i.locator.as_str(), i)).collect();
    let tgt_items: HashMap<&str, &crate::item::Item> = inp.target.items.iter().map(|i| (i.locator.as_str(), i)).collect();
    let merkles: HashMap<&str, &str> = inp.dump.definitions.iter().map(|d| (d.name.as_str(), d.merkle.as_str())).collect();
    let mut covered_src: BTreeSet<String> = BTreeSet::new();
    let mut covered_tgt: BTreeSet<String> = BTreeSet::new();
    let mut src_ops: Vec<String> = vec![];
    let mut tgt_ops: Vec<String> = vec![];

    // ---- 定義ごとの追跡属性: TR-X・TR-R・TR-S2・TR-T2 ----
    // ギャップの登録の宣言と、形式化していない主張（`opaque`）は機能をまたぐ登録簿なので、機能の対応表に載せない
    // （段階導入は登録の backlog による）
    let gap_decls: BTreeSet<&str> = inp.dump.gaps.iter()
        .flat_map(|g| {
            let claims = if g.evidence.state == "unformalized" { g.evidence.witnesses.as_slice() } else { &[] };
            std::iter::once(g.name.as_str()).chain(claims.iter().map(|c| c.as_str()))
        })
        .collect();
    // 移植元側・移植先側の層（言語の組は trace/project.json による）
    let src_layers: Vec<String> = ["SourceModel", "Abstraction", "Spec"].iter().map(|s| s.to_string()).chain(source_langs()).collect();
    let tgt_layers: Vec<String> = ["TargetModel", "Refinement"].iter().map(|s| s.to_string()).chain(target_langs()).collect();
    let (src_kinds, tgt_kinds) = (source_kinds(), target_kinds());
    for d in &inp.dump.definitions {
        let src_side = src_layers.contains(&d.layer);
        let tgt_side = tgt_layers.contains(&d.layer);
        if FEATURE_LAYERS.contains(&d.layer.as_str()) && inp.features.of_lean(&d.name).is_none()
            && !gap_decls.contains(d.name.as_str())
        {
            out.err("TR-R", format!("{}: no feature in trace/features.json covers this namespace", d.name));
        }
        for (attr, side_ok, own_kinds, decl) in [
            ("source", src_side, &src_kinds[..], &inp.upstream),
            ("target", tgt_side, &tgt_kinds[..], &inp.target_decl),
        ] {
            let values = d.attr(attr);
            if values.is_empty() {
                continue;
            }
            if !side_ok {
                out.err("TR-X", format!("{}: @[{attr}] in layer {} (the other side)", d.name, d.layer));
            }
            for v in values {
                let (loc, h) = split_hash(v);
                let k = kind_of(loc);
                let (rule2, inv) = if attr == "source" { ("TR-S2", &src_items) } else { ("TR-T2", &tgt_items) };
                if is_version_kind(k) {
                    match declared_version(decl, loc) {
                        None => out.err("TR-R", format!("{}: {loc}: not declared in trace/{}", d.name,
                            if attr == "source" { "upstream.json" } else { "target.json" })),
                        Some(ver) if ver != h => out.err(rule2, format!("{}: {loc}: version {h} != declared {ver}", d.name)),
                        _ => {}
                    }
                    // 移植元の依存を移植先で参照する（座標が upstream.json にだけある）
                    if attr == "target" && k == "dep" && declared_version(&inp.upstream, loc).is_some()
                        && declared_version(&inp.target_decl, loc).is_none()
                    {
                        out.err("TR-X", format!("{}: {loc}: a source-side dependency in @[target]", d.name));
                    }
                    continue;
                }
                if !own_kinds.contains(&k) {
                    out.err("TR-X", format!("{}: @[{attr}] has a {k}: locator ({loc})", d.name));
                    continue;
                }
                match inv.get(loc) {
                    None => out.err("TR-R", format!("{}: {loc}: not in the {attr} inventory", d.name)),
                    Some(it) => {
                        if it.hash != h {
                            out.err(rule2, format!("{}: {loc}: hash {h} != inventory {}", d.name, it.hash));
                        }
                        let rec = Passed { definition: d.name.clone(), locator: loc.into(), hash: h.into(), merkle: d.merkle.clone() };
                        if !inp.passed.contains(&rec) {
                            out.err(rule2, format!("{}: {loc}: no passed check recorded for this hash and Merkle (run rehash)", d.name));
                        }
                    }
                }
                if attr == "source" {
                    covered_src.insert(loc.to_string());
                    if d.layer == "SourceModel" && !src_ops.contains(&d.name) {
                        src_ops.push(d.name.clone());
                    }
                } else {
                    covered_tgt.insert(loc.to_string());
                    if d.layer == "TargetModel" && !tgt_ops.contains(&d.name) {
                        tgt_ops.push(d.name.clone());
                    }
                }
            }
        }
        // TR-T1（Lean 側）: TargetModel の定義は @[target] を持つ
        if d.layer == "TargetModel" && d.attr("target").is_empty() {
            out.staged("TR-T1", inp.features.of_lean(&d.name), format!("{}: no @[target]", d.name));
        }
    }

    // ---- TR-S1・TR-T1（インベントリ側） ----
    for it in &inp.source.items {
        if it.out_of_scope || covered_src.contains(&it.locator) {
            continue;
        }
        out.staged("TR-S1", inp.features.of_locator(&it.locator), format!("{} is not covered by any @[source]", it.locator));
    }
    let generated: BTreeSet<&String> = inp.target.generated.iter().collect();
    for it in &inp.target.items {
        if generated.contains(&it.locator) || covered_tgt.contains(&it.locator) {
            continue;
        }
        out.staged("TR-T1", inp.features.of_locator(&it.locator), format!("{} is not covered by any @[target]", it.locator));
    }

    // ---- TR-T2・TR-R: /// trace: models ----
    for t in &inp.target.model_tags {
        match merkles.get(t.name.as_str()) {
            None => out.err("TR-R", format!("{}:{}: trace: models {}: no such Lean definition", t.file, t.line, t.name)),
            Some(m) if *m != t.merkle => out.err("TR-T2", format!("{}:{}: {}: Merkle {} != Lean {m}", t.file, t.line, t.name, t.merkle)),
            _ => {}
        }
    }

    // ---- TR-P・TR-PE ----
    let r_names = |pred: &dyn Fn(&crate::lean::Obligation) -> bool, layer: &str| -> Vec<String> {
        inp.obligations.obligations.iter().filter(|o| o.refines && o.name.starts_with(&format!("{layer}.")) && pred(o))
            .map(|o| o.name.clone()).collect()
    };
    for (ops, layer) in [(&src_ops, "Abstraction"), (&tgt_ops, "Refinement")] {
        let all = closure(inp.dump, &r_names(&|_| true, layer));
        let entry = closure(inp.dump, &r_names(&|o| o.ids.iter().any(|i| inp.entry_tasks.contains(i)), layer));
        for op in ops.iter() {
            let f = inp.features.of_lean(op);
            if !all.contains(op) {
                out.staged("TR-P", f, format!("{op}: not in the closure of any R task in {layer}"));
            }
            if !entry.contains(op) {
                out.staged("TR-PE", f, format!("{op}: not in the closure of any entry R task in {layer}"));
            }
        }
    }

    // ---- TR-D ----
    let mut lean_devs: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for d in &inp.dump.definitions {
        for id in d.attr("deviation") {
            lean_devs.entry(id.clone()).or_default().push(d.name.clone());
        }
    }
    let in_theorems: BTreeSet<&String> =
        inp.obligations.refinements.iter().flat_map(|r| r.deviations.iter().chain(r.observations.iter())).collect();
    let obligation_ids: BTreeSet<&String> = inp.dump.definitions.iter().flat_map(|d| d.attr("obligation")).collect();
    let gap_ids: BTreeMap<&str, &Gap> = inp.dump.gaps.iter().map(|g| (g.id.as_str(), g)).collect();
    let feature_of_gap = |g: &Gap| -> Option<&Feature> {
        let feats: Vec<&Feature> = g.r_tasks.iter().filter_map(|t| inp.features.of_task(t)).collect();
        feats.iter().find(|f| inp.features.done(f)).or(feats.first()).copied()
    };
    for g in inp.dump.gaps.iter().filter(|g| g.is_typed()) {
        // 行の R 課題の機能のうち、完了したものがあれば誤り
        let f = feature_of_gap(g);
        if !lean_devs.contains_key(&g.id) {
            out.staged("TR-D", f, format!("{}: no @[deviation \"{}\"] in Lean", g.id, g.id));
        }
        match &g.w_task {
            None => out.err("TR-D", format!("{}: no W task in the registry", g.id)),
            Some(w) if !obligation_ids.contains(w) => {
                out.staged("TR-D", f, format!("{}: W task {w} has no @[obligation] theorem", g.id))
            }
            _ => {}
        }
    }
    for (id, names) in &lean_devs {
        match gap_ids.get(id.as_str()) {
            None => out.err("TR-D", format!("{id}: @[deviation] on {} but no @[gap_entry] in the registry", names.join(", "))),
            Some(g) if !g.is_typed() => {
                out.err("TR-D", format!("{id}: @[deviation] on {} but the registry kind is {}", names.join(", "), g.kind_label))
            }
            _ => {}
        }
        for n in names {
            if !in_theorems.contains(n) {
                out.staged("TR-D", inp.features.of_lean(n), format!("{n} (@[deviation \"{id}\"]) appears in no R task"));
            }
        }
    }

    // ---- TR-K: ギャップの箇所の印 ----
    let layer_of: HashMap<&str, &str> = inp.dump.definitions.iter().map(|d| (d.name.as_str(), d.layer.as_str())).collect();
    for g in &inp.dump.gaps {
        let concrete = if g.id.starts_with("T-") { "TargetModel" } else { "SourceModel" };
        let in_layer = |l: &str| g.site_markers().any(|m| layer_of.get(m.as_str()) == Some(&l));
        if g.is_typed() || g.kind == "outside_pre" {
            for l in ["Spec", concrete] {
                if !in_layer(l) {
                    out.staged_by("TR-K", &g.backlog, feature_of_gap(g),
                        format!("{} ({}): no @[gap \"{}\"] on a {l} definition", g.id, g.kind_label, g.id));
                }
            }
        }
        if g.kind == "out_of_model" && !(g.site_markers().next().is_none() && g.deviations.is_empty()) {
            out.err("TR-K", format!("{} (モデル外): has @[gap] / @[deviation] on {}", g.id,
                g.site_markers().chain(g.deviations.iter()).cloned().collect::<Vec<_>>().join(", ")));
        }
        // 証明の状態が未証明なら、段階導入（backlog が完了したら誤り）
        if g.evidence.state == "pending" {
            out.staged_by("TR-K", &g.backlog, feature_of_gap(g),
                format!("{} ({}): the evidence is pending ({})", g.id, g.kind_label, g.evidence.reason));
        }
        if !g.is_typed() && g.kind != "out_of_model" && !g.deviations.is_empty() {
            out.err("TR-K", format!("{} ({}): has @[deviation] on {}", g.id, g.kind_label, g.deviations.join(", ")));
        }
        for r in &inp.obligations.refinements {
            if r.deviations.iter().chain(r.observations.iter()).any(|d| g.deviations.contains(d)) {
                for t in r.ids.iter().filter(|t| !g.r_tasks.contains(t)) {
                    out.err("TR-K", format!("{}: R task {t} ({}) uses it but is not in the registry's R tasks", g.id, r.name));
                }
            }
        }
        for b in &g.backlog {
            if !inp.features.backlog_exists(b) {
                out.err("TR-R", format!("{} ({}): backlog {b} does not exist", g.id, g.name));
            }
        }
    }
    for d in &inp.dump.definitions {
        for id in d.attr("gap") {
            if !gap_ids.contains_key(id.as_str()) {
                out.err("TR-R", format!("{}: @[gap \"{id}\"] but {id} has no @[gap_entry]", d.name));
            }
        }
    }
    for r in &inp.obligations.refinements {
        for e in r.errors.iter().filter(|e| e.starts_with("G1") || e.starts_with("G2")) {
            out.err("TR-D", format!("{}: {e}", r.name));
        }
    }

    // ---- TR-G（obligation-check の誤り） ----
    for e in &inp.obligations.errors {
        out.err("TR-G", e.clone());
    }
    for r in &inp.obligations.refinements {
        for e in &r.errors {
            out.err("TR-G", format!("{}: {e}", r.name));
        }
    }

    // ---- TR-X: rust/ の中の移植元のロケータ ----
    for (path, text) in &inp.rust_files {
        for (i, l) in text.lines().enumerate() {
            if let Some(k) = source_locator_in(l) {
                out.err("TR-X", format!("{path}:{}: source locator ({k}:) in the target source", i + 1));
            }
        }
    }

    // ---- TR-R: 対応表・ベクタ ----
    for f in &inp.features.list {
        for b in &f.backlog {
            if !inp.features.backlog_exists(b) {
                out.err("TR-R", format!("trace/features.json: {}: backlog {b} does not exist", f.name));
            }
        }
    }
    for t in &inp.r_tasks {
        if inp.features.of_task(t).is_none() {
            out.err("TR-R", format!("{t}: R task is not assigned to any feature in trace/features.json"));
        }
    }
    for (file, name) in &inp.model_defs {
        if !merkles.contains_key(name.as_str()) {
            out.err("TR-R", format!("{file}: modelDef {name} is not a Lean definition"));
        }
    }
    // renames.json: old は現在のインベントリに無く、new はある
    for (old, new) in &inp.renames {
        let side = |l: &str| if tgt_kinds.contains(&kind_of(l)) { &tgt_items } else { &src_items };
        if side(old).contains_key(old.as_str()) {
            out.err("TR-R", format!("trace/renames.json: {old} -> {new}: the old locator is still in the inventory"));
        }
        if !side(new).contains_key(new.as_str()) {
            out.err("TR-R", format!("trace/renames.json: {old} -> {new}: the new locator is not in the inventory"));
        }
    }
    // 文書の「出典:」: ロケータは現在のインベントリ（dep:・lang: は宣言）にある
    for (at, loc) in &inp.citations {
        let k = kind_of(loc);
        let ok = if is_version_kind(k) {
            declared_version(&inp.upstream, loc).is_some() || declared_version(&inp.target_decl, loc).is_some()
        } else if tgt_kinds.contains(&k) {
            tgt_items.contains_key(loc.as_str())
        } else {
            src_items.contains_key(loc.as_str())
        };
        if !ok {
            out.err("TR-R", format!("{at}: 出典 {loc}: not in the inventory"));
        }
    }
    out.list.sort();
    out.list.dedup();
    out.list
}

/// 行に移植元のロケータ（`java:a…`・`http:GET /…` など）があれば、その種類。
fn source_locator_in(l: &str) -> Option<&'static str> {
    for k in source_kinds() {
        let pat = format!("{k}:");
        let mut start = 0;
        while let Some(p) = l[start..].find(&pat) {
            let at = start + p;
            let before_ok = at == 0 || !l[..at].chars().last().map(|c| c.is_alphanumeric()).unwrap_or(false);
            let after = &l[at + pat.len()..];
            let looks = if k == "http" {
                ["GET ", "POST ", "PUT ", "DELETE ", "PATCH ", "* "].iter().any(|m| after.starts_with(m))
            } else {
                after.chars().next().map(|c| c.is_alphanumeric()).unwrap_or(false) && !after.starts_with("//")
            };
            if before_ok && looks {
                return Some(k);
            }
            start = at + pat.len();
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::item::Item;
    use crate::lean::Def;
    use std::collections::BTreeMap;

    fn def(name: &str, layer: &str, attrs: &[(&str, &[&str])], refs: &[&str]) -> Def {
        Def {
            name: name.into(),
            layer: layer.into(),
            attributes: attrs.iter().map(|(k, v)| (k.to_string(), v.iter().map(|s| s.to_string()).collect())).collect(),
            merkle: "m0".into(),
            references: refs.iter().map(|s| s.to_string()).collect(),
            ..Default::default()
        }
    }

    fn feats(done: bool) -> Features {
        Features::from(
            vec![Feature {
                name: "Fare".into(),
                backlog: vec!["00000000-0000-4000-8000-000000000004".into()],
                lean: vec!["SourceModel.Fare".into(), "Abstraction.Fare".into(), "TargetModel.Fare".into(), "Refinement.Fare".into()],
                tasks: vec!["ABS-001".into(), "ABS-031".into()],
                locators: vec!["java:a.Fare*".into()],
            }],
            BTreeMap::from([("00000000-0000-4000-8000-000000000004".to_string(), if done { "done" } else { "todo" }.to_string())]),
        )
    }

    fn inv(locs: &[(&str, &str)]) -> Inventory {
        Inventory {
            items: locs.iter().map(|(l, h)| Item { locator: l.to_string(), kind: kind_of(l).into(), file: "f".into(), lines: [1, 1], hash: h.to_string(), out_of_scope: false }).collect(),
            ..Default::default()
        }
    }

    fn run_with(defs: Vec<Def>, obl: Obligations, src: Inventory, f: &Features, gaps: Vec<Gap>, entry: &[&str]) -> Vec<Finding> {
        let dump = Dump { lean_version: "x".into(), definitions: defs, gaps };
        let input = Input {
            dump: &dump,
            obligations: &obl,
            source: &src,
            target: &Inventory::default(),
            features: f,
            entry_tasks: entry.iter().map(|s| s.to_string()).collect(),
            r_tasks: vec![],
            upstream: serde_json::json!({"languages": {"java": {"version": "17"}}, "dependencies": [{"coordinate": "org.x:lib", "version": "1.0"}]}),
            target_decl: Value::Null,
            passed: BTreeSet::new(),
            rust_files: vec![("rust/src/a.rs".into(), "// ok http://example.com\n// java:a.Fare#f()\n".into())],
            model_defs: vec![],
            renames: vec![("java:a.Fare#old()".into(), "java:a.Fare#gone()".into())],
            citations: vec![("docs/spec/x.md:3".into(), "java:a.Fare#nope()".into()), ("docs/spec/x.md:4".into(), "lang:java#JLS-1".into())],
        };
        run(&input)
    }

    #[test]
    fn tr_x_java_locator_in_target_model() {
        let defs = vec![def("TargetModel.Fare.f", "TargetModel", &[("target", &["java:a.Fare#f()@00"])], &[])];
        let fs = run_with(defs, Obligations::default(), inv(&[]), &feats(false), vec![], &[]);
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-X" && f.msg.contains("TargetModel.Fare.f")), "{fs:?}");
        // rust/ の中の移植元のロケータも検出する（URL は誤検出しない）
        assert_eq!(fs.iter().filter(|f| f.rule == "TR-X" && f.msg.starts_with("rust/src/a.rs")).count(), 1, "{fs:?}");
    }

    #[test]
    fn tr_s1_staged_and_s2_hash_and_record() {
        let src = inv(&[("java:a.Fare#f()", "aa"), ("java:a.Fare#g()", "bb"), ("java:z.Other#h()", "cc")]);
        let defs = vec![def("SourceModel.Fare.f", "SourceModel", &[("source", &["java:a.Fare#f()@ab", "lang:java#JLS-1@java-17"])], &[])];
        let fs = run_with(defs.clone(), Obligations::default(), src.clone(), &feats(false), vec![], &[]);
        // 未完了の機能の未対応は警告、機能の無い項目は誤り
        assert!(fs.iter().any(|f| !f.error && f.rule == "TR-S1" && f.msg.contains("#g()")));
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-S1" && f.msg.contains("z.Other")));
        // ハッシュの不一致と、合格の記録が無いこと
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-S2" && f.msg.contains("hash ab")));
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-S2" && f.msg.contains("no passed check")));
        // 機能が完了したら、TR-S1 は誤り
        let fs = run_with(defs, Obligations::default(), src, &feats(true), vec![], &[]);
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-S1" && f.msg.contains("#g()")));
    }

    #[test]
    fn tr_r_unknown_locator_and_undeclared_dependency() {
        let defs = vec![def("SourceModel.Fare.f", "SourceModel", &[("source", &["java:a.Fare#nope()@00", "dep:org.y:other#X@other-1"])], &[])];
        let fs = run_with(defs, Obligations::default(), inv(&[]), &feats(false), vec![], &[]);
        assert!(fs.iter().any(|f| f.rule == "TR-R" && f.msg.contains("not in the source inventory")));
        assert!(fs.iter().any(|f| f.rule == "TR-R" && f.msg.contains("not declared")));
    }

    #[test]
    fn tr_d_missing_deviation_and_anonymous_hypothesis() {
        let devs = vec![gap("D-001", "pre", &["ABS-001"], Some("ABS-101"))];
        let obl = Obligations {
            refinements: vec![crate::lean::Refinement { name: "Abstraction.Fare.r".into(), ids: vec!["ABS-001".into()], deviations: vec![], observations: vec![],
                errors: vec!["G1: the type has hypotheses (∀); state deviations with restrict".into()] }],
            ..Default::default()
        };
        let fs = run_with(vec![], obl, inv(&[]), &feats(true), devs, &[]);
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-D" && f.msg.contains("no @[deviation \"D-001\"]")), "{fs:?}");
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-D" && f.msg.contains("G1")));
        assert!(fs.iter().any(|f| f.rule == "TR-D" && f.msg.contains("ABS-101")));
        // 文書に無い @[deviation]
        let defs = vec![def("Abstraction.Fare.dev_D999", "Abstraction", &[("deviation", &["D-999"])], &[])];
        let fs = run_with(defs, Obligations::default(), inv(&[]), &feats(false), vec![], &[]);
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-D" && f.msg.contains("D-999: @[deviation]")));
    }

    fn gap(id: &str, kind: &str, r: &[&str], w: Option<&str>) -> Gap {
        Gap {
            name: format!("Abstraction.Gap.{}", id.replace('-', "")),
            id: id.into(),
            kind: kind.into(),
            kind_label: kind.into(),
            r_tasks: r.iter().map(|s| s.to_string()).collect(),
            w_task: w.map(|s| s.to_string()),
            ..Default::default()
        }
    }

    #[test]
    fn tr_k_markers_by_kind() {
        let defs = vec![
            def("Spec.Fare.f", "Spec", &[("gap", &["D-001", "D-013"])], &[]),
            def("SourceModel.Fare.g", "SourceModel", &[("gap", &["D-077"])], &[]),
            def("Abstraction.Fare.dev_D005", "Abstraction", &[("deviation", &["D-005"])], &[]),
        ];
        let mut d1 = gap("D-001", "pre", &["ABS-001"], Some("ABS-101"));
        d1.markers = vec!["Spec.Fare.f".into()];
        d1.backlog = vec!["00000000-0000-4000-8000-000000000004".into()];
        let mut d13 = gap("D-013", "out_of_model", &[], None);
        d13.markers = vec!["Spec.Fare.f".into(), "Abstraction.Gap.claim_D013".into()];
        d13.evidence = crate::lean::Evidence { state: "unformalized".into(),
            witnesses: vec!["Abstraction.Gap.claim_D013".into()], ..Default::default() };
        d1.evidence = crate::lean::Evidence { state: "pending".into(), reason: "r".into(), ..Default::default() };
        let mut d5 = gap("D-005", "undetermined", &[], None);
        d5.deviations = vec!["Abstraction.Fare.dev_D005".into()];
        let mut d3 = gap("D-003", "outside_pre", &[], None);
        d3.backlog = vec!["00000000-0000-4000-8000-000000000099".into()];
        let obl = Obligations {
            refinements: vec![crate::lean::Refinement { name: "Abstraction.Fare.r".into(), ids: vec!["ABS-031".into()],
                deviations: vec!["Abstraction.Fare.dev_D005".into()], observations: vec![], errors: vec![] }],
            ..Default::default()
        };
        let gaps = vec![d1.clone(), d13, d5, d3];
        let fs = run_with(defs.clone(), obl.clone(), inv(&[]), &feats(false), gaps.clone(), &[]);
        let k = |f: &&Finding| f.rule == "TR-K";
        // 前提型に具体側の印が無い（backlog が未完了なので警告）
        assert!(fs.iter().filter(k).any(|f| !f.error && f.msg.contains("D-001") && f.msg.contains("SourceModel")), "{fs:?}");
        assert!(!fs.iter().filter(k).any(|f| f.msg.contains("D-001") && f.msg.contains("a Spec")), "{fs:?}");
        // モデル外に印、未確定に差異
        assert!(fs.iter().filter(k).any(|f| f.error && f.msg.contains("D-013 (モデル外): has @[gap] / @[deviation] on Spec.Fare.f")
            && !f.msg.contains("claim_D013")), "{fs:?}");
        // 未証明の状態（backlog が未完了なので警告）
        assert!(fs.iter().filter(k).any(|f| !f.error && f.msg.contains("D-001 (pre): the evidence is pending (r)")), "{fs:?}");
        assert!(fs.iter().filter(k).any(|f| f.error && f.msg.starts_with("D-005 (undetermined): has @[deviation]")), "{fs:?}");
        // 差異を使う R 課題が登録に無い
        assert!(fs.iter().filter(k).any(|f| f.error && f.msg.contains("R task ABS-031")), "{fs:?}");
        // 宣言の無い印、存在しない backlog
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-R" && f.msg.contains("@[gap \"D-077\"]")), "{fs:?}");
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-R" && f.msg.contains("backlog 00000000-0000-4000-8000-000000000099")), "{fs:?}");
        // backlog が完了すれば、印の不足は誤り
        let fs = run_with(defs, obl, inv(&[]), &feats(true), gaps, &[]);
        assert!(fs.iter().filter(k).any(|f| f.error && f.msg.contains("D-001") && f.msg.contains("SourceModel")), "{fs:?}");
        assert!(fs.iter().filter(k).any(|f| f.error && f.msg.contains("D-001 (pre): the evidence is pending")), "{fs:?}");
    }

    #[test]
    fn tr_pe_operation_only_in_non_entry_r_task() {
        let defs = vec![
            def("SourceModel.Fare.f", "SourceModel", &[("source", &["java:a.Fare#f()@aa"])], &[]),
            def("SourceModel.Fare.machine", "SourceModel", &[], &["SourceModel.Fare.f"]),
            def("Abstraction.Fare.inner_refines", "Abstraction", &[("obligation", &["ABS-001"])], &["SourceModel.Fare.machine"]),
        ];
        let obl = Obligations {
            obligations: vec![crate::lean::Obligation { name: "Abstraction.Fare.inner_refines".into(), ids: vec!["ABS-001".into()], refines: true }],
            ..Default::default()
        };
        let fs = run_with(defs.clone(), obl.clone(), inv(&[("java:a.Fare#f()", "aa")]), &feats(true), vec![], &["ABS-031"]);
        assert!(!fs.iter().any(|f| f.rule == "TR-P"), "{fs:?}");
        assert!(fs.iter().any(|f| f.error && f.rule == "TR-PE" && f.msg.contains("SourceModel.Fare.f")), "{fs:?}");
        // 入口の R 課題の閉包に入れば TR-PE は出ない
        let fs = run_with(defs, obl, inv(&[("java:a.Fare#f()", "aa")]), &feats(true), vec![], &["ABS-001"]);
        assert!(!fs.iter().any(|f| f.rule == "TR-PE"), "{fs:?}");
    }

    #[test]
    fn tr_r_renames_and_citations() {
        let fs = run_with(vec![], Obligations::default(), inv(&[("java:a.Fare#old()", "1")]), &feats(false), vec![], &[]);
        let msgs: Vec<&str> = fs.iter().filter(|f| f.error && f.rule == "TR-R").map(|f| f.msg.as_str()).collect();
        assert!(msgs.iter().any(|m| m.contains("old locator is still")), "{msgs:?}");
        assert!(msgs.iter().any(|m| m.contains("new locator is not")), "{msgs:?}");
        assert!(msgs.iter().any(|m| m.contains("x.md:3") && m.contains("nope")), "{msgs:?}");
        assert!(!msgs.iter().any(|m| m.contains("x.md:4")), "{msgs:?}");
    }

    #[test]
    fn finds_source_locators_in_text() {
        assert_eq!(source_locator_in("// see java:jp.co.X#f()"), Some("java"));
        assert_eq!(source_locator_in("let u = \"http://example.com\";"), None);
        assert_eq!(source_locator_in("http:GET /ticket/search"), Some("http"));
        assert_eq!(source_locator_in("mysql:foo"), None);
    }
}
