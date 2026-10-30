//! `rehash`: 決定論的な検査を実行し、合格した組だけ注釈のハッシュを更新して記録する（ADR 0036・0041）。
//!
//! 1. 対象: `@[source]`・`@[target]` の（定義, ロケータ）のうち、ハッシュ・版がインベントリ・宣言と違う、
//!    合格の記録（本文ハッシュと Merkle の組）が無い、または `trace/renames.json` の `old` に当たるもの。
//! 2. 対象を覆う検査（`trace/checks.json`）を、それぞれ 1 回だけ実行する。覆う検査が無い対象は更新しない。
//! 3. 覆う検査がすべて合格した対象について、定義のモジュールのファイルの `"<loc>@<old>"` を
//!    `"<new-loc>@<new>"` に置き換え、manifest に記録を書く。同じ文字列を注釈に持つ定義が同じモジュールに
//!    複数あれば、そのすべてが合格したときだけ置き換える（置き換えない定義は記録もしない）。
//!
//! Merkle は属性を含まないので、注釈の書き換えで変わらない（`Trace.Dump`）。

use crate::check::{declared_version, is_version_kind, Passed};
use crate::checks::{self, Registry};
use crate::inventory::Inventory;
use crate::lean::{kind_of, split_hash, Dump};
use crate::manifest::{CheckRecord, Manifest};
use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::path::{Path, PathBuf};

/// Lean のソースの置き場所（モジュール名 `A.B` → `<root>/A/B.lean`）。
pub const LEAN_ROOTS: &[&str] = &["lean", ".agents/skills/port-lang/assets/lean"];

/// `trace/renames.json` の（old, new）。
pub fn load_renames(repo: &Path) -> Result<Vec<(String, String)>, String> {
    let p = repo.join("trace/renames.json");
    let Ok(s) = std::fs::read_to_string(&p) else { return Ok(vec![]) };
    let v: Value = serde_json::from_str(&s).map_err(|e| format!("{}: {e}", p.display()))?;
    let mut out = vec![];
    for r in v["renames"].as_array().cloned().unwrap_or_default() {
        match (r["old"].as_str(), r["new"].as_str()) {
            (Some(o), Some(n)) => out.push((o.to_string(), n.to_string())),
            _ => return Err(format!("{}: each rename needs \"old\" and \"new\"", p.display())),
        }
    }
    Ok(out)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Candidate {
    pub definition: String,
    pub module: String,
    /// 注釈の現在の値 `<loc>@<hash>`
    pub old: String,
    pub locator: String,
    pub hash: String,
    pub merkle: String,
    pub reason: String,
}

impl Candidate {
    pub fn new_value(&self) -> String {
        format!("{}@{}", self.locator, self.hash)
    }
}

#[derive(Debug, Default)]
pub struct Plan {
    pub candidates: Vec<Candidate>,
    /// 解決できない注釈（インベントリにも renames にも無い、宣言に無い版）
    pub unresolved: Vec<String>,
}

pub struct Context<'a> {
    pub dump: &'a Dump,
    pub source: &'a Inventory,
    pub target: &'a Inventory,
    pub upstream: &'a Value,
    pub target_decl: &'a Value,
    pub passed: &'a BTreeSet<Passed>,
    pub renames: &'a [(String, String)],
}

/// 更新の対象を求める（何も実行しない）。
pub fn plan(cx: &Context) -> Plan {
    let src: HashMap<&str, &str> = cx.source.items.iter().map(|i| (i.locator.as_str(), i.hash.as_str())).collect();
    let tgt: HashMap<&str, &str> = cx.target.items.iter().map(|i| (i.locator.as_str(), i.hash.as_str())).collect();
    let renames: HashMap<&str, &str> = cx.renames.iter().map(|(o, n)| (o.as_str(), n.as_str())).collect();
    let mut p = Plan::default();
    for d in &cx.dump.definitions {
        for (attr, inv, decl) in [("source", &src, cx.upstream), ("target", &tgt, cx.target_decl)] {
            for v in d.attr(attr) {
                let (loc, h) = split_hash(v);
                let (new_loc, cur, reason) = if is_version_kind(kind_of(loc)) {
                    match declared_version(decl, loc) {
                        Some(ver) if ver != h => (loc.to_string(), ver, "version changed".to_string()),
                        Some(_) => continue,
                        None => {
                            p.unresolved.push(format!("{}: {loc}: version not declared", d.name));
                            continue;
                        }
                    }
                } else if let Some(cur) = inv.get(loc) {
                    let rec = Passed { definition: d.name.clone(), locator: loc.into(), hash: cur.to_string(), merkle: d.merkle.clone() };
                    if *cur != h {
                        (loc.to_string(), cur.to_string(), format!("hash {h} -> {cur}"))
                    } else if !cx.passed.contains(&rec) {
                        (loc.to_string(), cur.to_string(), "no passed check for this hash and Merkle".to_string())
                    } else {
                        continue;
                    }
                } else if let Some(cur) = renames.get(loc).and_then(|n| inv.get(n).map(|h| (n, h))) {
                    (cur.0.to_string(), cur.1.to_string(), format!("renamed from {loc}"))
                } else {
                    p.unresolved.push(format!("{}: {loc}: not in the {attr} inventory nor in trace/renames.json", d.name));
                    continue;
                };
                p.candidates.push(Candidate {
                    definition: d.name.clone(),
                    module: d.module.clone(),
                    old: v.clone(),
                    locator: new_loc,
                    hash: cur,
                    merkle: d.merkle.clone(),
                    reason,
                });
            }
        }
    }
    p
}

/// モジュールのファイル。
pub fn module_file(repo: &Path, module: &str) -> Option<PathBuf> {
    let rel = module.replace('.', "/") + ".lean";
    LEAN_ROOTS.iter().map(|r| repo.join(r).join(&rel)).find(|p| p.is_file())
}

#[derive(Debug, Default)]
pub struct Outcome {
    /// 更新した（定義, 新しい値）
    pub updated: Vec<(String, String)>,
    /// 更新しなかった理由
    pub skipped: Vec<String>,
    /// 検査の結果
    pub results: BTreeMap<String, bool>,
}

/// 検査を実行し、合格した対象の注釈と manifest の記録を更新する。
/// `runner` は検査の実行（試験では差し替える）。
pub fn execute(
    repo: &Path,
    cx: &Context,
    reg: &Registry,
    cover: &BTreeMap<String, BTreeSet<String>>,
    manifest: &mut Manifest,
    runner: &dyn Fn(&Path, &checks::Check) -> bool,
) -> Result<Outcome, String> {
    let p = plan(cx);
    let mut out = Outcome::default();
    out.skipped.extend(p.unresolved.iter().map(|u| format!("{u} (unresolved)")));
    let empty = BTreeSet::new();
    let needed: BTreeSet<&String> = p.candidates.iter().flat_map(|c| cover.get(&c.definition).unwrap_or(&empty)).collect();
    for c in &reg.checks {
        if needed.contains(&c.id) {
            out.results.insert(c.id.clone(), runner(repo, c));
        }
    }
    for id in &needed {
        if !reg.checks.iter().any(|c| &c.id == *id) {
            return Err(format!("unknown check id {id}"));
        }
    }
    // 対象ごとの合否
    let mut ok: Vec<&Candidate> = vec![];
    for c in &p.candidates {
        let ids = cover.get(&c.definition).unwrap_or(&empty);
        if ids.is_empty() {
            out.skipped.push(format!("{}: {}: no check covers this definition (add one to trace/checks.json)", c.definition, c.old));
        } else if let Some(bad) = ids.iter().find(|i| !out.results.get(*i).copied().unwrap_or(false)) {
            out.skipped.push(format!("{}: {}: check {bad} failed", c.definition, c.old));
        } else {
            ok.push(c);
        }
    }
    // 注釈の書き換え: （モジュール, 旧い値）ごと
    let holders = |module: &str, value: &str| -> BTreeSet<String> {
        cx.dump.definitions.iter()
            .filter(|d| d.module == module && (d.attr("source").iter().chain(d.attr("target")).any(|v| v == value)))
            .map(|d| d.name.clone())
            .collect()
    };
    let mut groups: BTreeMap<(String, String), Vec<&Candidate>> = BTreeMap::new();
    for c in &ok {
        groups.entry((c.module.clone(), c.old.clone())).or_default().push(c);
    }
    let mut accepted: Vec<&Candidate> = vec![];
    let mut edits: BTreeMap<PathBuf, Vec<(String, String)>> = BTreeMap::new();
    for ((module, old), cs) in &groups {
        let news: BTreeSet<String> = cs.iter().map(|c| c.new_value()).collect();
        let passed: BTreeSet<String> = cs.iter().map(|c| c.definition.clone()).collect();
        // 記録だけを書く（注釈は変えない）なら、他の定義にはかかわらない
        let rewrite = news.len() != 1 || !news.contains(old);
        if rewrite && (news.len() != 1 || passed != holders(module, old)) {
            for c in cs {
                out.skipped.push(format!(
                    "{}: {old}: other definitions in {module} share this annotation and did not all pass",
                    c.definition
                ));
            }
            continue;
        }
        let new = news.into_iter().next().unwrap();
        if new != *old {
            let Some(file) = module_file(repo, module) else {
                for c in cs {
                    out.skipped.push(format!("{}: source file of module {module} not found", c.definition));
                }
                continue;
            };
            edits.entry(file).or_default().push((old.clone(), new));
        }
        accepted.extend(cs.iter().copied());
    }
    for (file, reps) in &edits {
        let mut text = std::fs::read_to_string(file).map_err(|e| format!("{}: {e}", file.display()))?;
        for (old, new) in reps {
            let from = format!("\"{old}\"");
            if !text.contains(&from) {
                return Err(format!("{}: annotation {from} not found", file.display()));
            }
            text = text.replace(&from, &format!("\"{new}\""));
        }
        std::fs::write(file, text).map_err(|e| format!("{}: {e}", file.display()))?;
    }
    for c in &accepted {
        let old_loc = split_hash(&c.old).0;
        manifest.checks.retain(|r| !(r.definition == c.definition && (r.locator == old_loc || r.locator == c.locator)));
        let ids: Vec<String> = cover[&c.definition].iter().cloned().collect();
        manifest.checks.push(CheckRecord {
            definition: c.definition.clone(),
            locator: c.locator.clone(),
            hash: c.hash.clone(),
            merkle: c.merkle.clone(),
            checks: ids,
        });
        out.updated.push((c.definition.clone(), c.new_value()));
    }
    manifest.checks.sort();
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::checks::{Check, Covers, Step};
    use crate::item::Item;
    use crate::lean::Def;

    fn def(name: &str, module: &str, src: &[&str]) -> Def {
        let mut d = Def { name: name.into(), layer: "SourceModel".into(), merkle: format!("m-{name}"), module: module.into(), ..Default::default() };
        d.attributes.insert("source".into(), src.iter().map(|s| s.to_string()).collect());
        d
    }

    fn inv(items: &[(&str, &str)]) -> Inventory {
        let mut i = Inventory::default();
        for (l, h) in items {
            i.items.push(Item { locator: l.to_string(), kind: "java".into(), file: "F.java".into(), lines: [1, 1], hash: h.to_string(), out_of_scope: false });
        }
        i
    }

    fn reg(ids: &[&str]) -> Registry {
        Registry {
            checks: ids.iter().map(|id| Check {
                id: id.to_string(),
                description: String::new(),
                steps: vec![Step { cwd: ".".into(), argv: vec!["true".into()] }],
                covers: Covers::default(),
            }).collect(),
        }
    }

    struct Fx {
        dir: PathBuf,
    }

    impl Fx {
        fn new(tag: &str, lean: &str) -> Fx {
            let dir = std::env::temp_dir().join(format!("trace-rehash-{tag}-{}", std::process::id()));
            let _ = std::fs::remove_dir_all(&dir);
            std::fs::create_dir_all(dir.join("lean/SourceModel")).unwrap();
            std::fs::write(dir.join("lean/SourceModel/Fare.lean"), lean).unwrap();
            Fx { dir }
        }
        fn lean(&self) -> String {
            std::fs::read_to_string(self.dir.join("lean/SourceModel/Fare.lean")).unwrap()
        }
    }

    impl Drop for Fx {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }

    fn go(
        fx: &Fx,
        defs: Vec<Def>,
        src: &Inventory,
        renames: &[(String, String)],
        cover: &[(&str, &[&str])],
        pass: &[&str],
        m: &mut Manifest,
    ) -> Outcome {
        let dump = Dump { definitions: defs, ..Default::default() };
        let passed = crate::manifest::passed(m);
        let tgt = Inventory::default();
        let cx = Context { dump: &dump, source: src, target: &tgt, upstream: &Value::Null, target_decl: &Value::Null, passed: &passed, renames };
        let ids: BTreeSet<&str> = cover.iter().flat_map(|(_, v)| v.iter().copied()).collect();
        let r = reg(&ids.into_iter().collect::<Vec<_>>());
        let cv: BTreeMap<String, BTreeSet<String>> =
            cover.iter().map(|(d, v)| (d.to_string(), v.iter().map(|s| s.to_string()).collect())).collect();
        let pass: Vec<String> = pass.iter().map(|s| s.to_string()).collect();
        execute(&fx.dir, &cx, &r, &cv, m, &|_, c| pass.contains(&c.id)).unwrap()
    }

    const LEAN: &str = "@[source \"java:a.B#f()@0000\"]\ndef f := 1\n";

    #[test]
    fn passing_check_updates_annotation_and_records() {
        let fx = Fx::new("pass", LEAN);
        let mut m = Manifest::default();
        let out = go(&fx, vec![def("SourceModel.Fare.f", "SourceModel.Fare", &["java:a.B#f()@0000"])],
            &inv(&[("java:a.B#f()", "1111")]), &[], &[("SourceModel.Fare.f", &["vec"])], &["vec"], &mut m);
        assert_eq!(out.updated, vec![("SourceModel.Fare.f".to_string(), "java:a.B#f()@1111".to_string())]);
        assert!(fx.lean().contains("\"java:a.B#f()@1111\""));
        assert_eq!(m.checks.len(), 1);
        assert_eq!((m.checks[0].hash.as_str(), m.checks[0].merkle.as_str()), ("1111", "m-SourceModel.Fare.f"));
        assert_eq!(m.checks[0].checks, vec!["vec".to_string()]);
    }

    /// 完了条件: 検査が合格していない定義のハッシュを更新しない。
    #[test]
    fn failing_check_changes_nothing() {
        let fx = Fx::new("fail", LEAN);
        let mut m = Manifest::default();
        let out = go(&fx, vec![def("SourceModel.Fare.f", "SourceModel.Fare", &["java:a.B#f()@0000"])],
            &inv(&[("java:a.B#f()", "1111")]), &[], &[("SourceModel.Fare.f", &["vec"])], &[], &mut m);
        assert!(out.updated.is_empty());
        assert_eq!(out.results.get("vec"), Some(&false));
        assert_eq!(fx.lean(), LEAN);
        assert!(m.checks.is_empty());
    }

    #[test]
    fn uncovered_definition_is_not_updated() {
        let fx = Fx::new("uncovered", LEAN);
        let mut m = Manifest::default();
        let out = go(&fx, vec![def("SourceModel.Fare.f", "SourceModel.Fare", &["java:a.B#f()@0000"])],
            &inv(&[("java:a.B#f()", "1111")]), &[], &[], &[], &mut m);
        assert!(out.updated.is_empty());
        assert!(out.skipped[0].contains("no check covers"));
        assert_eq!(fx.lean(), LEAN);
    }

    #[test]
    fn shared_annotation_needs_all_holders_to_pass() {
        let text = "@[source \"java:a.B#f()@0000\"]\ndef f := 1\n@[source \"java:a.B#f()@0000\"]\ndef g := 2\n";
        let fx = Fx::new("shared", text);
        let mut m = Manifest::default();
        let defs = vec![
            def("SourceModel.Fare.f", "SourceModel.Fare", &["java:a.B#f()@0000"]),
            def("SourceModel.Fare.g", "SourceModel.Fare", &["java:a.B#f()@0000"]),
        ];
        let out = go(&fx, defs, &inv(&[("java:a.B#f()", "1111")]), &[],
            &[("SourceModel.Fare.f", &["a"]), ("SourceModel.Fare.g", &["b"])], &["a"], &mut m);
        assert!(out.updated.is_empty());
        assert_eq!(fx.lean(), text);
        assert!(m.checks.is_empty());
    }

    #[test]
    fn rename_is_accepted_only_when_checks_pass() {
        let fx = Fx::new("rename", "@[source \"java:a.B#old()@1111\"]\ndef f := 1\n");
        let renames = vec![("java:a.B#old()".to_string(), "java:a.B#new()".to_string())];
        let defs = || vec![def("SourceModel.Fare.f", "SourceModel.Fare", &["java:a.B#old()@1111"])];
        let src = inv(&[("java:a.B#new()", "1111")]);
        let mut m = Manifest::default();
        let out = go(&fx, defs(), &src, &renames, &[("SourceModel.Fare.f", &["vec"])], &[], &mut m);
        assert!(out.updated.is_empty());
        assert!(fx.lean().contains("java:a.B#old()@1111"));
        let out = go(&fx, defs(), &src, &renames, &[("SourceModel.Fare.f", &["vec"])], &["vec"], &mut m);
        assert_eq!(out.updated.len(), 1);
        assert!(fx.lean().contains("\"java:a.B#new()@1111\""));
        assert_eq!(m.checks[0].locator, "java:a.B#new()");
    }

    #[test]
    fn up_to_date_and_recorded_is_not_a_candidate() {
        let fx = Fx::new("noop", "@[source \"java:a.B#f()@1111\"]\ndef f := 1\n");
        let mut m = Manifest {
            checks: vec![CheckRecord {
                definition: "SourceModel.Fare.f".into(),
                locator: "java:a.B#f()".into(),
                hash: "1111".into(),
                merkle: "m-SourceModel.Fare.f".into(),
                checks: vec!["vec".into()],
            }],
            ..Default::default()
        };
        let out = go(&fx, vec![def("SourceModel.Fare.f", "SourceModel.Fare", &["java:a.B#f()@1111"])],
            &inv(&[("java:a.B#f()", "1111")]), &[], &[("SourceModel.Fare.f", &["vec"])], &[], &mut m);
        assert!(out.updated.is_empty() && out.skipped.is_empty() && out.results.is_empty());
        assert_eq!(m.checks.len(), 1);
    }
}
