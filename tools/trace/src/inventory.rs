//! `inventory source|target`: インベントリの生成（ADR 0036・0040）。

use crate::item::Item;
use crate::rust::ModelTag;
use globset::{Glob, GlobSet, GlobSetBuilder};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

/// `trace/source-inventory.json`・`trace/target-inventory.json` の形。
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq)]
pub struct Inventory {
    /// 走査したディレクトリ（リポジトリのルートからの相対）
    pub root: String,
    /// 版（移植元は upstream.json の release と commit）
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub version: BTreeMap<String, String>,
    /// 種類ごとの件数（out_of_scope を含む）
    pub counts: BTreeMap<String, usize>,
    pub items: Vec<Item>,
    /// `/// trace: models` の札（移植先だけ）
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub model_tags: Vec<ModelTag>,
    /// 生成物の写し（`rust/src/model/`）の項目のロケータ（移植先だけ。TR-T1 の対象外）
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub generated: Vec<String>,
}

fn walk(dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(rd) = fs::read_dir(dir) else { return };
    let mut entries: Vec<PathBuf> = rd.filter_map(|e| e.ok().map(|e| e.path())).collect();
    entries.sort();
    for p in entries {
        if p.is_dir() {
            let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
            if name == "target" || name.starts_with('.') {
                continue;
            }
            walk(&p, out);
        } else {
            out.push(p);
        }
    }
}

fn rel(repo: &Path, p: &Path) -> String {
    p.strip_prefix(repo).unwrap_or(p).to_string_lossy().replace('\\', "/")
}

/// `out-of-scope.json` の glob（`JavaConfig-Thymeleaf/atrs` からの相対）。
pub fn out_of_scope(repo: &Path) -> Result<GlobSet, String> {
    let v: Value = serde_json::from_str(&fs::read_to_string(repo.join("trace/out-of-scope.json")).map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;
    let mut b = GlobSetBuilder::new();
    for it in v["items"].as_array().cloned().unwrap_or_default() {
        if let Some(p) = it["path"].as_str() {
            b.add(Glob::new(p).map_err(|e| e.to_string())?);
        }
    }
    b.build().map_err(|e| e.to_string())
}

fn counts(items: &[Item]) -> BTreeMap<String, usize> {
    let mut c = BTreeMap::new();
    for it in items {
        *c.entry(it.kind.clone()).or_default() += 1;
    }
    c
}

fn finish(mut items: Vec<Item>) -> Result<Vec<Item>, String> {
    items.sort_by(|a, b| a.locator.cmp(&b.locator));
    let dups: Vec<&str> = items.windows(2).filter(|w| w[0].locator == w[1].locator).map(|w| w[0].locator.as_str()).collect();
    if !dups.is_empty() {
        return Err(format!("duplicate locators: {}", dups.join(", ")));
    }
    Ok(items)
}

/// 移植元のインベントリ。
pub fn source(repo: &Path) -> Result<Inventory, String> {
    let up: Value = serde_json::from_str(&fs::read_to_string(repo.join("trace/upstream.json")).map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;
    let base = repo
        .join(up["submodule"].as_str().unwrap_or("upstream/atrs"))
        .join(up["variant"].as_str().unwrap_or("JavaConfig-Thymeleaf"))
        .join("atrs");
    if !base.is_dir() {
        return Err(format!("{} not found (git submodule update --init)", base.display()));
    }
    let oos = out_of_scope(repo)?;
    let mut files = vec![];
    walk(&base, &mut files);
    let mut items = vec![];
    for p in files {
        let r = rel(repo, &p);
        let in_base = rel(&base, &p);
        let name = p.file_name().and_then(|n| n.to_str()).unwrap_or("");
        let read = || fs::read_to_string(&p).map_err(|e| format!("{r}: {e}"));
        let mut found: Vec<Item> = if name.ends_with(".java") {
            if in_base.contains("/src/test/") { continue }
            crate::java::scan(&r, &read()?)
        } else if name.ends_with(".properties") {
            if in_base.contains("/src/test/") { continue }
            crate::props::scan(&r, &read()?)
        } else if name == "web.xml" {
            crate::webxml::scan(&r, &read()?)?
        } else if name.ends_with(".xml") && in_base.contains("/src/main/resources/") {
            let s = read()?;
            if s.contains("<mapper") { crate::mapper::scan(&r, &s)? } else { continue }
        } else if name.ends_with(".sql") && in_base.starts_with("atrs-initdb/") {
            crate::sqlfile::scan(&r, &read()?)
        } else if name.ends_with(".html") && in_base.contains("/WEB-INF/views/") {
            let v = in_base.split("/WEB-INF/views/").nth(1).unwrap_or(&in_base).to_string();
            crate::tmpl::scan(&r, &v, &read()?)
        } else {
            continue;
        };
        for it in &mut found {
            it.out_of_scope = oos.is_match(&in_base);
        }
        items.extend(found);
    }
    let items = finish(items)?;
    let mut version = BTreeMap::new();
    for k in ["release", "commit"] {
        version.insert(k.to_string(), up[k].as_str().unwrap_or("").to_string());
    }
    Ok(Inventory { root: rel(repo, &base), version, counts: counts(&items), items, ..Default::default() })
}

/// 移植先のインベントリ（`rust/src/`）。`rust/` が無ければ 0 件。
pub fn target(repo: &Path, crate_name: &str) -> Result<Inventory, String> {
    let base = repo.join("rust/src");
    let mut items = vec![];
    let mut tags = vec![];
    let mut generated = vec![];
    if base.is_dir() {
        let mut files = vec![];
        walk(&base, &mut files);
        for p in files.into_iter().filter(|p| p.extension().map(|e| e == "rs").unwrap_or(false)) {
            let r = rel(repo, &p);
            let in_src = rel(&base, &p);
            let src = fs::read_to_string(&p).map_err(|e| format!("{r}: {e}"))?;
            let (its, tg) = crate::rust::scan(&r, &crate::rust::module_path(crate_name, &in_src), &src);
            if in_src.starts_with("model/") {
                generated.extend(its.iter().map(|i| i.locator.clone()));
            }
            items.extend(its);
            tags.extend(tg);
        }
    }
    let items = finish(items)?;
    generated.sort();
    Ok(Inventory { root: "rust/src".into(), counts: counts(&items), items, model_tags: tags, generated, ..Default::default() })
}

/// JSON の文字列（末尾の改行付き、決定的）。
pub fn to_json(inv: &Inventory) -> String {
    serde_json::to_string_pretty(inv).unwrap() + "\n"
}

pub fn load(path: &Path) -> Result<Inventory, String> {
    match fs::read_to_string(path) {
        Ok(s) => serde_json::from_str(&s).map_err(|e| format!("{}: {e}", path.display())),
        Err(_) => Ok(Inventory::default()),
    }
}
