//! `diff`: 新旧のインベントリを分類する（port-lang の guide/upgrade.md の手順 3。references/docs/spec/traceability.md#道具）。
//!
//! | 分類 | 判定 |
//! | --- | --- |
//! | 不変 | 本文ハッシュが同じ |
//! | 本文変更 | 同じロケータで本文ハッシュが違う |
//! | 移動/改名 | 旧ロケータが消え、同じ本文ハッシュの新ロケータが 1 つだけ現れた。または `trace/renames.json` の対応 |
//! | 追加 / 削除 | 上記以外で、新版にだけ / 旧版にだけある |
//! | 版の変化 | 宣言（`upstream.json`・`target.json`）の `languages`・`dependencies` の版が違う |

use crate::inventory::Inventory;
use serde::Serialize;
use serde_json::Value;
use std::collections::{BTreeMap, HashMap};

#[derive(Serialize, Debug, Default, PartialEq)]
pub struct Diff {
    pub unchanged: usize,
    pub changed: Vec<String>,
    /// （旧, 新, 本文も変わったか）
    pub moved: Vec<(String, String, bool)>,
    pub added: Vec<String>,
    pub removed: Vec<String>,
    /// （`lang:<名前>` / `dep:<座標>`, 旧い版, 新しい版）。片方に無ければ空文字列
    pub versions: Vec<(String, String, String)>,
}

impl Diff {
    /// 変化したロケータ（`impact` の起点）。移動/改名は新しいロケータ、削除は旧いロケータ。
    pub fn changed_locators(&self) -> Vec<String> {
        let mut v: Vec<String> = self.changed.clone();
        v.extend(self.moved.iter().map(|(_, n, _)| n.clone()));
        v.extend(self.removed.iter().cloned());
        v.extend(self.added.iter().cloned());
        v.extend(self.versions.iter().map(|(k, _, _)| k.clone()));
        v
    }
}

fn versions(decl: &Value) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    if let Some(m) = decl["languages"].as_object() {
        for (k, v) in m {
            out.insert(format!("lang:{k}"), v["version"].as_str().unwrap_or("").to_string());
        }
    }
    for d in decl["dependencies"].as_array().cloned().unwrap_or_default() {
        if let Some(c) = d["coordinate"].as_str() {
            out.insert(format!("dep:{c}"), d["version"].as_str().unwrap_or("").to_string());
        }
    }
    out
}

pub fn diff(old: &Inventory, new: &Inventory, renames: &[(String, String)], decls: Option<(&Value, &Value)>) -> Diff {
    let o: BTreeMap<&str, &str> = old.items.iter().map(|i| (i.locator.as_str(), i.hash.as_str())).collect();
    let n: BTreeMap<&str, &str> = new.items.iter().map(|i| (i.locator.as_str(), i.hash.as_str())).collect();
    let mut d = Diff::default();
    let mut gone: Vec<&str> = vec![];
    for (l, h) in &o {
        match n.get(l) {
            Some(h2) if h2 == h => d.unchanged += 1,
            Some(_) => d.changed.push(l.to_string()),
            None => gone.push(l),
        }
    }
    let mut fresh: Vec<&str> = n.keys().filter(|l| !o.contains_key(*l)).copied().collect();
    // 手で書いた改名
    for (ol, nl) in renames {
        if let (Some(i), Some(j)) = (gone.iter().position(|g| g == ol), fresh.iter().position(|f| f == nl)) {
            d.moved.push((ol.clone(), nl.clone(), o[ol.as_str()] != n[nl.as_str()]));
            gone.remove(i);
            fresh.remove(j);
        }
    }
    // 同じ本文ハッシュ（新版で一意）
    let mut by_hash: HashMap<&str, Vec<&str>> = HashMap::new();
    for f in &fresh {
        by_hash.entry(n[f]).or_default().push(f);
    }
    let mut old_by_hash: HashMap<&str, usize> = HashMap::new();
    for g in &gone {
        *old_by_hash.entry(o[g]).or_default() += 1;
    }
    let mut taken: Vec<&str> = vec![];
    for g in &gone {
        let h = o[g];
        match by_hash.get(h) {
            Some(c) if c.len() == 1 && old_by_hash[h] == 1 => {
                d.moved.push((g.to_string(), c[0].to_string(), false));
                taken.push(c[0]);
            }
            _ => d.removed.push(g.to_string()),
        }
    }
    d.added = fresh.into_iter().filter(|f| !taken.contains(f)).map(String::from).collect();
    if let Some((od, nd)) = decls {
        let (ov, nv) = (versions(od), versions(nd));
        for k in ov.keys().chain(nv.keys()).collect::<std::collections::BTreeSet<_>>() {
            let (a, b) = (ov.get(k).cloned().unwrap_or_default(), nv.get(k).cloned().unwrap_or_default());
            if a != b {
                d.versions.push((k.clone(), a, b));
            }
        }
    }
    d.moved.sort();
    d
}

/// 人が読む形の出力。
pub fn render(d: &Diff) -> String {
    let mut s = format!(
        "unchanged {}, changed {}, moved/renamed {}, added {}, removed {}, versions {}\n",
        d.unchanged,
        d.changed.len(),
        d.moved.len(),
        d.added.len(),
        d.removed.len(),
        d.versions.len()
    );
    for l in &d.changed {
        s += &format!("changed  {l}\n");
    }
    for (a, b, c) in &d.moved {
        s += &format!("moved    {a} -> {b}{}\n", if *c { " (body changed)" } else { "" });
    }
    for l in &d.added {
        s += &format!("added    {l}\n");
    }
    for l in &d.removed {
        s += &format!("removed  {l}\n");
    }
    for (k, a, b) in &d.versions {
        s += &format!("version  {k}: {a} -> {b}\n");
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::item::Item;
    use serde_json::json;

    fn inv(items: &[(&str, &str)]) -> Inventory {
        let mut i = Inventory::default();
        for (l, h) in items {
            i.items.push(Item { locator: l.to_string(), kind: "java".into(), file: "F".into(), lines: [1, 1], hash: h.to_string(), out_of_scope: false });
        }
        i
    }

    #[test]
    fn classifies_all_kinds() {
        let old = inv(&[("java:A#same()", "1"), ("java:A#body()", "2"), ("java:A#moved()", "3"), ("java:A#gone()", "4"), ("java:A#hand()", "5")]);
        let new = inv(&[("java:A#same()", "1"), ("java:A#body()", "9"), ("java:B#moved()", "3"), ("java:A#new()", "6"), ("java:A#hand2()", "7")]);
        let renames = vec![("java:A#hand()".to_string(), "java:A#hand2()".to_string())];
        let od = json!({"languages": {"java": {"version": "17"}}, "dependencies": [{"coordinate": "g:a", "version": "1"}]});
        let nd = json!({"languages": {"java": {"version": "21"}}, "dependencies": [{"coordinate": "g:a", "version": "1"}]});
        let d = diff(&old, &new, &renames, Some((&od, &nd)));
        assert_eq!(d.unchanged, 1);
        assert_eq!(d.changed, vec!["java:A#body()"]);
        assert_eq!(d.moved, vec![
            ("java:A#hand()".into(), "java:A#hand2()".into(), true),
            ("java:A#moved()".into(), "java:B#moved()".into(), false),
        ]);
        assert_eq!(d.added, vec!["java:A#new()"]);
        assert_eq!(d.removed, vec!["java:A#gone()"]);
        assert_eq!(d.versions, vec![("lang:java".into(), "17".into(), "21".into())]);
    }

    #[test]
    fn ambiguous_hash_is_not_a_move() {
        let old = inv(&[("java:A#x()", "1")]);
        let new = inv(&[("java:B#x()", "1"), ("java:C#x()", "1")]);
        let d = diff(&old, &new, &[], None);
        assert!(d.moved.is_empty());
        assert_eq!(d.removed, vec!["java:A#x()"]);
        assert_eq!(d.added.len(), 2);
    }
}
