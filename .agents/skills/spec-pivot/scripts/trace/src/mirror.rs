//! TR-M: モデルのモジュールが原典のソースツリーの形に並んでいること（references/docs/spec/traceability.md#検査、
//! lang/java/layout.md#移植元として原典を読む）。`trace/project.json` の `source.mirror` があるときだけ検査する。
//!
//! 原典のクラス `<prefix>.<pkg>.<Class>` は、モジュール `<lean_root>.<Pkg>.<Class>` に写す（`case = upper-camel` なら
//! パッケージの各成分の先頭を大文字に）。モジュールの名前の層の直下が `roots` のどれかなら、原典のソースツリーを写す
//! モジュール（mirror のモジュール）とする。
//!
//! | ID | 内容 | 重さ |
//! | --- | --- | --- |
//! | TR-M1 | `java:`・`sql:` のロケータを持つ定義が、そのクラスのモジュールにない（`shared` のクラスのロケータは除く）。mirror の外の定義が、それらのロケータを持つ | 機能の移植元側で段階 |
//! | TR-M2 | mirror のモジュールの直下の宣言の名前が、自分のロケータのメンバーの名前とも、クラスのソース（Java・Mapper の XML）の識別子とも合わない | 警告 |
//! | TR-M3 | `java:<Class>#<m>(…)` を持ち、名前が `<m>`（`<init>` は `new`）の定義の引数の名前に、Java の引数の名前が順に現れない（可変長引数は省いてよい） | 機能の移植元側で段階 |
//! | TR-M4 | クラスの型（名前がモジュールと同じ構造体）の欄が、Java のクラスの欄に無い | 警告 |
//!
//! 名前の比較は、大文字小文字と `_`・`-` を区別しない。TR-M2 は、構造体の欄・構築子・自動生成の名前と、`_` を含む小文字の名前
//! （定理など）を対象にしない。

use crate::check::Finding;
use crate::docs::{Features, Side};
use crate::inventory::Inventory;
use crate::java::{param_types, text};
use crate::lean::Dump;
use crate::project::Mirror;
use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;
use tree_sitter::{Node, Parser};

/// Java のクラスの情報（TR-M2〜M4）。
#[derive(Debug, Default, Clone)]
pub struct JavaClass {
    /// 欄の名前
    pub fields: BTreeSet<String>,
    /// メソッド・コンストラクタ（名前、引数の型の並び、引数の名前の並び）
    pub methods: Vec<(String, String, Vec<String>)>,
    /// ソース（Java と Mapper の XML）に現れる識別子（正規化したもの）
    pub idents: BTreeSet<String>,
}

/// 名前の正規化（大文字小文字と `_`・`-` を区別しない）。
pub fn norm(s: &str) -> String {
    s.chars().filter(|c| *c != '_' && *c != '-').flat_map(|c| c.to_lowercase()).collect()
}

/// 原典のクラスの完全修飾名のモジュール（接頭辞の外なら `None`）。
pub fn module_of_class(m: &Mirror, fqcn: &str) -> Option<String> {
    let fqcn = fqcn.split('$').next().unwrap_or(fqcn);
    let rest = fqcn.strip_prefix(&format!("{}.", m.package_prefix))?;
    let parts: Vec<&str> = rest.split('.').collect();
    let (cls, pkg) = parts.split_last()?;
    let pkg: Vec<String> = pkg
        .iter()
        .map(|p| if m.case == "same" { p.to_string() } else { upper_first(p) })
        .collect();
    let mut segs = vec![m.lean_root.clone()];
    segs.extend(pkg);
    segs.push(cls.to_string());
    Some(segs.join("."))
}

/// モジュールの原典のクラスの完全修飾名（mirror のモジュールでなければ `None`）。
pub fn class_of_module(m: &Mirror, module: &str) -> Option<String> {
    let rest = module.strip_prefix(&format!("{}.", m.lean_root))?;
    let parts: Vec<&str> = rest.split('.').collect();
    if parts.len() < 2 || !m.roots.iter().any(|r| r == parts[0]) {
        return None;
    }
    let (cls, pkg) = parts.split_last()?;
    let pkg: Vec<String> = pkg.iter().map(|p| if m.case == "same" { p.to_string() } else { lower_first(p) }).collect();
    Some(format!("{}.{}.{}", m.package_prefix, pkg.join("."), cls))
}

fn upper_first(s: &str) -> String {
    let mut c = s.chars();
    c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default()
}

fn lower_first(s: &str) -> String {
    let mut c = s.chars();
    c.next().map(|f| f.to_lowercase().collect::<String>() + c.as_str()).unwrap_or_default()
}

/// mirror のモジュールか。
pub fn is_mirror_module(m: &Mirror, module: &str) -> bool {
    class_of_module(m, module).is_some()
}

/// ロケータのクラスの完全修飾名とメンバー（`java:` と `sql:` だけ）。
pub fn locator_class(loc: &str) -> Option<(String, String)> {
    let loc = loc.split('@').next().unwrap_or(loc);
    let (kind, body) = loc.split_once(':')?;
    if kind != "java" && kind != "sql" {
        return None;
    }
    if let Some((cls, member)) = body.split_once('#') {
        return Some((cls.split('$').next().unwrap_or(cls).to_string(), member.to_string()));
    }
    // 定数・enum の定数: `<Class>.<NAME>`
    let (cls, member) = body.rsplit_once('.')?;
    Some((cls.split('$').next().unwrap_or(cls).to_string(), member.to_string()))
}

/// メンバーの名前（`calculateFare(int,int)` → `calculateFare`、`<init>(…)` → `new`）。
fn member_name(member: &str) -> String {
    let n = member.split('(').next().unwrap_or(member);
    if n == "<init>" { "new".into() } else { n.to_string() }
}

/// Java のソースから、単純名 `simple` の型の情報を取る。
pub fn java_class(src: &str, simple: &str) -> Option<JavaClass> {
    let mut parser = Parser::new();
    parser.set_language(&tree_sitter_java::LANGUAGE.into()).ok()?;
    let tree = parser.parse(src, None)?;
    let b = src.as_bytes();
    let node = find_type(tree.root_node(), b, simple)?;
    let mut jc = JavaClass::default();
    let body = node.child_by_field_name("body")?;
    let mut members: Vec<Node> = vec![];
    let mut c = body.walk();
    for ch in body.children(&mut c) {
        if ch.kind() == "enum_body_declarations" {
            let mut c2 = ch.walk();
            members.extend(ch.children(&mut c2));
        } else {
            members.push(ch);
        }
    }
    for m in members {
        match m.kind() {
            "field_declaration" | "constant_declaration" => {
                let mut c2 = m.walk();
                for d in m.children(&mut c2).filter(|d| d.kind() == "variable_declarator") {
                    if let Some(n) = d.child_by_field_name("name") {
                        jc.fields.insert(text(n, b).to_string());
                    }
                }
            }
            "method_declaration" | "constructor_declaration" => {
                let name = if m.kind() == "constructor_declaration" {
                    "<init>".to_string()
                } else {
                    m.child_by_field_name("name").map(|x| text(x, b).to_string()).unwrap_or_default()
                };
                let sig = param_types(m, b).join(",");
                let mut names = vec![];
                if let Some(ps) = m.child_by_field_name("parameters") {
                    let mut c3 = ps.walk();
                    for p in ps.children(&mut c3) {
                        match p.kind() {
                            "formal_parameter" => {
                                if let Some(n) = p.child_by_field_name("name") {
                                    names.push(text(n, b).to_string());
                                }
                            }
                            "spread_parameter" => {
                                let mut c4 = p.walk();
                                if let Some(d) = p.children(&mut c4).find(|x| x.kind() == "variable_declarator") {
                                    if let Some(n) = d.child_by_field_name("name") {
                                        // 可変長引数は、モデルで省いてよい（引数無しの呼び出しを写す）
                                        names.push(format!("...{}", text(n, b)));
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                }
                jc.methods.push((name, sig, names));
            }
            _ => {}
        }
    }
    jc.idents = idents(src);
    Some(jc)
}

fn find_type<'a>(n: Node<'a>, src: &[u8], simple: &str) -> Option<Node<'a>> {
    let kinds = ["class_declaration", "interface_declaration", "enum_declaration", "record_declaration"];
    if kinds.contains(&n.kind()) && n.child_by_field_name("name").map(|x| text(x, src)) == Some(simple) {
        return Some(n);
    }
    let mut c = n.walk();
    for ch in n.children(&mut c) {
        if let Some(t) = find_type(ch, src, simple) {
            return Some(t);
        }
    }
    None
}

/// ソースの識別子（英数字・`_`・`-`・`$` の並び。正規化したもの）。
pub fn idents(src: &str) -> BTreeSet<String> {
    src.split(|c: char| !(c.is_ascii_alphanumeric() || c == '_' || c == '-' || c == '$'))
        .filter(|w| w.chars().next().is_some_and(|c| c.is_ascii_alphabetic()))
        .map(norm)
        .collect()
}

/// インベントリから、クラスごとのソースファイル（Java と Mapper の XML）を引き、情報を読む。
pub fn load_classes(repo: &Path, inv: &Inventory) -> BTreeMap<String, JavaClass> {
    let mut files: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
    for it in &inv.items {
        if let Some((cls, _)) = locator_class(&it.locator) {
            files.entry(cls).or_default().insert(it.file.clone());
        }
    }
    let mut out = BTreeMap::new();
    for (cls, fs) in files {
        let simple = cls.rsplit('.').next().unwrap_or(&cls).to_string();
        let mut jc = JavaClass::default();
        let mut found = false;
        for f in fs {
            let Ok(src) = std::fs::read_to_string(repo.join(&f)) else { continue };
            if f.ends_with(".java") {
                if let Some(c) = java_class(&src, &simple) {
                    jc.fields.extend(c.fields);
                    jc.methods.extend(c.methods);
                    jc.idents.extend(c.idents);
                    found = true;
                }
            } else {
                jc.idents.extend(idents(&src));
                found = true;
            }
        }
        if found {
            out.insert(cls, jc);
        }
    }
    out
}

/// 自動生成の名前・構造体の欄・定理などで、TR-M2 の対象にしないもの。
fn skip_m2(last: &str, type_fields: &BTreeSet<String>) -> bool {
    const GEN: &[&str] = &["mk", "ctorIdx", "noConfusionType", "noConfusion", "rec", "recOn", "casesOn", "below", "brecOn"];
    type_fields.contains(last)
        || GEN.contains(&last)
        || last.starts_with("inst")
        || last.starts_with('_')
        || (last.contains('_') && last.chars().any(|c| c.is_ascii_lowercase()))
}

/// `sub` が `all` の部分列か。
fn subsequence(sub: &[String], all: &[String]) -> bool {
    let mut it = all.iter();
    sub.iter().all(|s| it.any(|a| a == s))
}

/// TR-M の検査。
pub fn check(dump: &Dump, m: &Mirror, classes: &BTreeMap<String, JavaClass>, features: &Features) -> Vec<Finding> {
    let mut out = vec![];
    let layer = m.lean_root.as_str();
    let shared: BTreeSet<&str> = m.shared.iter().map(|s| s.as_str()).collect();
    let staged = |out: &mut Vec<Finding>, rule: &'static str, name: &str, msg: String| {
        let f = features.of_lean(name);
        let (error, feature) = match f {
            Some(f) => (features.done_side(f, Side::Source), f.name.clone()),
            None => (true, "(unassigned)".into()),
        };
        out.push(Finding { error, rule, feature, msg });
    };
    let warn = |out: &mut Vec<Finding>, rule: &'static str, name: &str, msg: String| {
        let feature = features.of_lean(name).map(|f| f.name.clone()).unwrap_or_default();
        out.push(Finding { error: false, rule, feature, msg });
    };
    // 構造体の欄（モジュールと同じ名前の型）
    let mut type_fields: BTreeMap<&str, BTreeSet<String>> = BTreeMap::new();
    for d in dump.definitions.iter().filter(|d| d.layer == layer) {
        if d.name == d.module && !d.fields.is_empty() {
            type_fields.insert(d.module.as_str(), d.fields.iter().cloned().collect());
        }
    }
    let empty = BTreeSet::new();
    let mut missing_class: BTreeSet<String> = BTreeSet::new();
    for d in dump.definitions.iter().filter(|d| d.layer == layer) {
        let locs: Vec<(String, String)> = d.attr("source").iter().filter_map(|l| locator_class(l)).collect();
        let own: Vec<&(String, String)> = locs.iter().filter(|(c, _)| !shared.contains(c.as_str())).collect();
        let mirror = is_mirror_module(m, &d.module);
        // ---- TR-M1 ----
        if !own.is_empty() {
            let expected: BTreeSet<String> = own.iter().filter_map(|(c, _)| module_of_class(m, c)).collect();
            if !mirror {
                staged(&mut out, "TR-M1", &d.name, format!(
                    "{}: has source locators of {} but is outside the source tree; move it to {}",
                    d.name, own.iter().map(|(c, _)| c.as_str()).collect::<BTreeSet<_>>().into_iter().collect::<Vec<_>>().join(", "),
                    expected.iter().next().cloned().unwrap_or_default()));
            } else if !expected.contains(&d.module) {
                staged(&mut out, "TR-M1", &d.name, format!(
                    "{}: is in {} but its locators are of {}; move it to one of them",
                    d.name, d.module, expected.iter().cloned().collect::<Vec<_>>().join(", ")));
            }
        }
        if !mirror {
            continue;
        }
        let Some(cls) = class_of_module(m, &d.module) else { continue };
        let jc = classes.get(&cls);
        if jc.is_none() {
            if missing_class.insert(d.module.clone()) {
                warn(&mut out, "TR-M2", &d.name, format!("{}: no class {cls} in the source inventory", d.module));
            }
            continue;
        }
        // 直下の宣言だけ（`<module>.<x>`、または型そのもの）
        let last = if d.name == d.module {
            d.module.rsplit('.').next().unwrap_or("").to_string()
        } else {
            match d.name.strip_prefix(&format!("{}.", d.module)) {
                Some(x) if !x.contains('.') => x.to_string(),
                _ => continue,
            }
        };
        let tf = type_fields.get(d.module.as_str()).unwrap_or(&empty);
        // ---- TR-M2 ----
        if !skip_m2(&last, tf) {
            let members: BTreeSet<String> = locs.iter().map(|(_, mb)| norm(&member_name(mb))).collect();
            let n = norm(&last);
            let in_src = jc.is_some_and(|j| j.idents.contains(&n));
            if !members.contains(&n) && !in_src {
                warn(&mut out, "TR-M2", &d.name, format!(
                    "{}: `{last}` is neither a member named by its locators nor an identifier in the source of {cls}", d.name));
            }
        }
        // ---- TR-M3 ----
        if let Some(j) = jc {
            for (c, mb) in &own {
                if c != &cls && !d.attr("source").iter().any(|l| l.contains(&format!("{c}#"))) {
                    continue;
                }
                let name = member_name(mb);
                if name != last {
                    continue;
                }
                let raw = mb.split('(').next().unwrap_or(mb);
                let sig = mb.split_once('(').map(|(_, s)| s.trim_end_matches(')')).unwrap_or("");
                // 同じクラスのソースにあるメソッドだけ（インタフェースのロケータは、そのクラスの情報で確かめる）
                let cj = if c == &cls { Some(j) } else { classes.get(c) };
                let Some(cj) = cj else { continue };
                if let Some((_, _, names)) = cj.methods.iter().find(|(n, s, _)| n == raw && s == sig) {
                    let required: Vec<String> = names.iter().filter(|n| !n.starts_with("...")).cloned().collect();
                    let names: Vec<String> = names.iter().map(|n| n.trim_start_matches("...").to_string()).collect();
                    if !subsequence(&required, &d.params) {
                        staged(&mut out, "TR-M3", &d.name, format!(
                            "{}: the parameters ({}) do not contain the Java parameters ({}) of {c}#{mb} in order",
                            d.name, d.params.join(", "), names.join(", ")));
                    }
                }
            }
        }
        // ---- TR-M4 ----
        if d.name == d.module && !d.fields.is_empty() {
            if let Some(j) = jc {
                let missing: Vec<&String> = d.fields.iter().filter(|f| !j.fields.contains(*f)).collect();
                if !missing.is_empty() {
                    warn(&mut out, "TR-M4", &d.name, format!(
                        "{}: field(s) {} are not fields of {cls}",
                        d.name, missing.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(", ")));
                }
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::lean::Def;

    fn mirror() -> Mirror {
        Mirror {
            lean_root: "SourceModel".into(),
            package_prefix: "p".into(),
            roots: vec!["Domain".into()],
            case: "upper-camel".into(),
            shared: vec!["p.config.Shared".into()],
        }
    }

    fn def(name: &str, module: &str, src: &[&str], params: &[&str], fields: &[&str]) -> Def {
        let mut d = Def { name: name.into(), layer: "SourceModel".into(), module: module.into(), ..Default::default() };
        if !src.is_empty() {
            d.attributes.insert("source".into(), src.iter().map(|s| s.to_string()).collect());
        }
        d.params = params.iter().map(|s| s.to_string()).collect();
        d.fields = fields.iter().map(|s| s.to_string()).collect();
        d
    }

    const JAVA: &str = r#"package p.domain.service;
public class FooServiceImpl implements FooService {
    private int limitDay;
    BarProvider barProvider;
    public int calc(int basicFare, int discountRate) { return helperOne(basicFare); }
    private int helperOne(int x) { return x; }
}"#;

    #[test]
    fn module_and_class_names() {
        let m = mirror();
        assert_eq!(module_of_class(&m, "p.domain.service.FooServiceImpl").as_deref(), Some("SourceModel.Domain.Service.FooServiceImpl"));
        assert_eq!(class_of_module(&m, "SourceModel.Domain.Service.FooServiceImpl").as_deref(), Some("p.domain.service.FooServiceImpl"));
        assert_eq!(class_of_module(&m, "SourceModel.FareQuery"), None);
        assert_eq!(locator_class("java:p.a.B#c(int)@h"), Some(("p.a.B".into(), "c(int)".into())));
        assert_eq!(locator_class("java:p.a.B.CONST@h"), Some(("p.a.B".into(), "CONST".into())));
        assert_eq!(locator_class("sql:p.a.BRepository#findAll@h"), Some(("p.a.BRepository".into(), "findAll".into())));
        assert_eq!(locator_class("dep:x#y@v"), None);
    }

    #[test]
    fn java_class_info() {
        let j = java_class(JAVA, "FooServiceImpl").unwrap();
        assert!(j.fields.contains("limitDay") && j.fields.contains("barProvider"));
        assert!(j.methods.iter().any(|(n, s, ps)| n == "calc" && s == "int,int" && ps == &vec!["basicFare".to_string(), "discountRate".to_string()]));
        assert!(j.idents.contains("helperone"));
    }

    #[test]
    fn findings() {
        let m = mirror();
        let mut classes = BTreeMap::new();
        classes.insert("p.domain.service.FooServiceImpl".to_string(), java_class(JAVA, "FooServiceImpl").unwrap());
        let md = "SourceModel.Domain.Service.FooServiceImpl";
        let dump = Dump {
            definitions: vec![
                // 合格: 型（欄は Java の欄）、メソッド（引数は Java の引数を順に含む）、private の写し
                def(md, md, &["java:p.domain.service.FooServiceImpl#calc(int,int)@h"], &[], &["limitDay", "barProvider"]),
                def(&format!("{md}.calc"), md, &["java:p.domain.service.FooServiceImpl#calc(int,int)@h"], &["svc", "basicFare", "discountRate"], &[]),
                def(&format!("{md}.helperOne"), md, &[], &["x"], &[]),
                def(&format!("{md}.limitDay"), md, &[], &[], &[]),
                def(&format!("{md}.calc_example"), md, &[], &[], &[]),
                // 横断的な設定のクラスのロケータは配置の根拠にしない
                def("SourceModel.Domain.Service.Other.x", "SourceModel.Domain.Service.Other", &["java:p.config.Shared#configuration()@h"], &[], &[]),
                // 違反
                def(&format!("{md}.calcWrong"), md, &["java:p.domain.service.FooServiceImpl#calc(int,int)@h"], &[], &[]),
                def("SourceModel.Fare.calc", "SourceModel.Fare", &["java:p.domain.service.FooServiceImpl#calc(int,int)@h"], &["a", "b"], &[]),
                def("SourceModel.Domain.Service.BarServiceImpl.calc", "SourceModel.Domain.Service.BarServiceImpl",
                    &["java:p.domain.service.FooServiceImpl#calc(int,int)@h"], &[], &[]),
                def(&format!("{md}.calc2"), md, &[], &[], &[]),
            ],
            ..Default::default()
        };
        let mut d = dump.clone();
        // TR-M3: 引数の名前が違う
        d.definitions[1].params = vec!["svc".into(), "fare".into(), "rate".into()];
        // TR-M4: Java に無い欄
        d.definitions[0].fields.push("today".into());
        let feats = Features::from(vec![], BTreeMap::new());
        let fs = check(&dump, &m, &classes, &feats);
        let rules = |fs: &[Finding], r: &str, s: &str| fs.iter().any(|f| f.rule == r && f.msg.contains(s));
        assert!(!fs.iter().any(|f| f.msg.starts_with(&format!("{md}:")) || f.msg.starts_with(&format!("{md}.calc:"))
            || f.msg.contains("helperOne") || f.msg.contains("limitDay") || f.msg.contains("calc_example") || f.msg.contains("Other.x")), "{fs:?}");
        assert!(rules(&fs, "TR-M1", "SourceModel.Fare.calc: has source locators"), "{fs:?}");
        assert!(rules(&fs, "TR-M1", "BarServiceImpl.calc: is in"), "{fs:?}");
        assert!(rules(&fs, "TR-M2", "calc2"), "{fs:?}");
        assert!(fs.iter().all(|f| f.rule != "TR-M2" || !f.error));
        // calcWrong: ロケータのメンバー calc と名前が合わず、識別子にも無い
        assert!(rules(&fs, "TR-M2", "calcWrong"), "{fs:?}");
        let fs2 = check(&d, &m, &classes, &feats);
        assert!(rules(&fs2, "TR-M3", "do not contain the Java parameters (basicFare, discountRate)"), "{fs2:?}");
        assert!(rules(&fs2, "TR-M4", "today"), "{fs2:?}");
        assert!(fs2.iter().all(|f| f.rule != "TR-M4" || !f.error));
    }
}
