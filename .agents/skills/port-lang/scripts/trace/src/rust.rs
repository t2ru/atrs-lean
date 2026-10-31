//! Rust のインベントリ（`rust:`）と `/// trace: models` の札。rust/locators.md と references/traceability.md#道具 による。
//!
//! - 単位: `pub` の関数・メソッド・型・定数・トレイト。ロケータは `rust:<crate>::<モジュール>::<名前>`、
//!   メソッドは `<型>::<名前>`、トレイトの実装は `<<型> as <トレイト>>::<名前>`。
//! - 同じモジュールの非 `pub` の関数の本文を、呼ぶ側の本文の後に連結する（推移的。初出順）。
//! - `verus!` の中は、行の走査で `pub … fn` を切り出す（tree-sitter はマクロの中を解析しない）。
//! - `rust/src/model/`（`TargetModel` の写し。生成物）の項目は `generated` とし、TR-T1 の対象から外す。

use crate::item::Item;
use crate::normalize::ts_tokens;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tree_sitter::{Node, Parser};

const COMMENTS: &[&str] = &["line_comment", "block_comment"];
const ATOMIC: &[&str] = &["string_literal", "raw_string_literal", "char_literal"];

/// `/// trace: models <Lean の名前> @<Merkle>`
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct ModelTag {
    pub file: String,
    pub line: usize,
    pub name: String,
    pub merkle: String,
}

fn text<'a>(n: Node, src: &'a [u8]) -> &'a str {
    n.utf8_text(src).unwrap_or("")
}

fn tokens(n: Node, src: &[u8]) -> String {
    let mut out = vec![];
    ts_tokens(n, src, COMMENTS, ATOMIC, &mut out);
    out.join(" ")
}

fn is_pub(n: Node) -> bool {
    let mut c = n.walk();
    n.children(&mut c).any(|ch| ch.kind() == "visibility_modifier")
}

fn calls(n: Node, src: &[u8], privates: &HashMap<String, Node>, out: &mut Vec<String>) {
    if n.kind() == "call_expression" {
        if let Some(f) = n.child_by_field_name("function") {
            let name = text(f, src).rsplit("::").next().unwrap_or("").to_string();
            if privates.contains_key(&name) && !out.contains(&name) {
                out.push(name);
            }
        }
    }
    let mut c = n.walk();
    for ch in n.children(&mut c) {
        calls(ch, src, privates, out);
    }
}

fn with_privates(n: Node, src: &[u8], privates: &HashMap<String, Node>) -> String {
    let mut parts = vec![tokens(n, src)];
    let mut queue = vec![];
    calls(n, src, privates, &mut queue);
    let mut i = 0;
    while i < queue.len() {
        let f = privates[&queue[i]];
        i += 1;
        parts.push(tokens(f, src));
        let mut more = vec![];
        calls(f, src, privates, &mut more);
        for m in more {
            if !queue.contains(&m) {
                queue.push(m);
            }
        }
    }
    parts.join(" ")
}

fn lines(n: Node) -> [usize; 2] {
    [n.start_position().row + 1, n.end_position().row + 1]
}

fn scan_items(body: Node, path: &str, src: &[u8], file: &str, out: &mut Vec<Item>) {
    let mut privates: HashMap<String, Node> = HashMap::new();
    let mut c = body.walk();
    for ch in body.children(&mut c) {
        if ch.kind() == "function_item" && !is_pub(ch) {
            if let Some(nm) = ch.child_by_field_name("name") {
                privates.insert(text(nm, src).to_string(), ch);
            }
        }
    }
    let mut c = body.walk();
    for ch in body.children(&mut c) {
        match ch.kind() {
            "function_item" | "struct_item" | "enum_item" | "const_item" | "static_item" | "type_item"
            | "trait_item" | "union_item"
                if is_pub(ch) =>
            {
                let nm = ch.child_by_field_name("name").map(|x| text(x, src)).unwrap_or("?");
                let norm = if ch.kind() == "function_item" { with_privates(ch, src, &privates) } else { tokens(ch, src) };
                out.push(Item::new("rust", format!("{path}::{nm}"), file, lines(ch), &norm));
            }
            "mod_item" => {
                if let (Some(nm), Some(b)) = (ch.child_by_field_name("name"), ch.child_by_field_name("body")) {
                    scan_items(b, &format!("{path}::{}", text(nm, src)), src, file, out);
                }
            }
            "impl_item" => {
                let ty = ch.child_by_field_name("type").map(|t| text(t, src).to_string()).unwrap_or_default();
                let ty = ty.split('<').next().unwrap_or(&ty).trim().to_string();
                let owner = match ch.child_by_field_name("trait") {
                    Some(t) => format!("<{ty} as {}>", text(t, src)),
                    None => ty,
                };
                let Some(b) = ch.child_by_field_name("body") else { continue };
                let mut c2 = b.walk();
                for f in b.children(&mut c2) {
                    let trait_impl = ch.child_by_field_name("trait").is_some();
                    if f.kind() == "function_item" && (is_pub(f) || trait_impl) {
                        let nm = f.child_by_field_name("name").map(|x| text(x, src)).unwrap_or("?");
                        out.push(Item::new(
                            "rust",
                            format!("{path}::{owner}::{nm}"),
                            file,
                            lines(f),
                            &with_privates(f, src, &privates),
                        ));
                    }
                }
            }
            "macro_invocation" if ch.child_by_field_name("macro").map(|m| text(m, src)) == Some("verus") => {
                verus_scan(ch, path, src, file, out);
            }
            "expression_statement" => {
                let mut c2 = ch.walk();
                for m in ch.children(&mut c2) {
                    if m.kind() == "macro_invocation" && m.child_by_field_name("macro").map(|x| text(x, src)) == Some("verus") {
                        verus_scan(m, path, src, file, out);
                    }
                }
            }
            _ => {}
        }
    }
}

/// `verus! { … }` の中を行で走査し、`pub … fn <名前>` の本文（波括弧の対応まで）を切り出す。
fn verus_scan(m: Node, path: &str, src: &[u8], file: &str, out: &mut Vec<Item>) {
    let body = text(m, src);
    let base = m.start_position().row + 1;
    let ls: Vec<&str> = body.lines().collect();
    let mut i = 0;
    while i < ls.len() {
        let t = ls[i].trim_start();
        if t.starts_with("pub ") && t.contains("fn ") {
            let after = &t[t.find("fn ").unwrap() + 3..];
            let name: String = after.chars().take_while(|c| c.is_alphanumeric() || *c == '_').collect();
            let (mut depth, mut started, mut j) = (0i32, false, i);
            let mut buf = String::new();
            while j < ls.len() {
                for ch in ls[j].chars() {
                    if ch == '{' {
                        depth += 1;
                        started = true;
                    } else if ch == '}' {
                        depth -= 1;
                    }
                }
                let line = ls[j].split("//").next().unwrap_or("");
                buf.push_str(line);
                buf.push('\n');
                if started && depth <= 0 {
                    break;
                }
                j += 1;
            }
            let norm = buf.split_whitespace().collect::<Vec<_>>().join(" ");
            out.push(Item::new("rust", format!("{path}::{name}"), file, [base + i, base + j], &norm));
            i = j + 1;
        } else {
            i += 1;
        }
    }
}

/// モジュールのパス（`src/lib.rs`・`src/main.rs` は crate のルート、`src/a/mod.rs` は `a`）。
pub fn module_path(crate_name: &str, rel_in_src: &str) -> String {
    let p = rel_in_src.trim_end_matches(".rs");
    let mut segs: Vec<&str> = p.split('/').collect();
    if matches!(segs.last(), Some(&"lib") | Some(&"main") | Some(&"mod")) {
        segs.pop();
    }
    std::iter::once(crate_name).chain(segs).collect::<Vec<_>>().join("::")
}

pub fn scan(file: &str, module: &str, source: &str) -> (Vec<Item>, Vec<ModelTag>) {
    let mut parser = Parser::new();
    parser.set_language(&tree_sitter_rust::LANGUAGE.into()).expect("tree-sitter-rust");
    let tree = parser.parse(source, None).expect("parse");
    let mut items = vec![];
    scan_items(tree.root_node(), module, source.as_bytes(), file, &mut items);
    let mut tags = vec![];
    for (i, l) in source.lines().enumerate() {
        let t = l.trim_start();
        if let Some(rest) = t.strip_prefix("/// trace: models ") {
            if let Some((name, h)) = rest.rsplit_once(" @") {
                tags.push(ModelTag { file: file.into(), line: i + 1, name: name.trim().into(), merkle: h.trim().into() });
            }
        }
    }
    (items, tags)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SRC: &str = r#"
/// trace: models TargetModel.Fare.basicFare @0123456789abcdef
pub fn basic_fare(a: u64) -> u64 { helper(a) }
fn helper(a: u64) -> u64 { a * 2 }
pub struct Fare { x: u64 }
impl Fare { pub fn get(&self) -> u64 { self.x } fn hidden(&self) {} }
impl Default for Fare { fn default() -> Self { Fare { x: 0 } } }
pub mod inner { pub const C: u32 = 1; }
verus! {
    pub open spec fn spec_fare(a: int) -> int {
        a + 1
    }
}
"#;

    #[test]
    fn scans_pub_items_and_tags() {
        let (items, tags) = scan("rust/src/fare.rs", &module_path("app", "fare.rs"), SRC);
        let locs: Vec<&str> = items.iter().map(|i| i.locator.as_str()).collect();
        assert!(locs.contains(&"rust:app::fare::basic_fare"));
        assert!(locs.contains(&"rust:app::fare::Fare"));
        assert!(locs.contains(&"rust:app::fare::Fare::get"));
        assert!(locs.contains(&"rust:app::fare::<Fare as Default>::default"));
        assert!(locs.contains(&"rust:app::fare::inner::C"));
        assert!(locs.contains(&"rust:app::fare::spec_fare"));
        assert!(!locs.iter().any(|l| l.contains("helper") || l.contains("hidden")));
        assert_eq!(tags[0].name, "TargetModel.Fare.basicFare");
        assert_eq!(tags[0].merkle, "0123456789abcdef");
        let (items2, _) = scan("f", "app::fare", &SRC.replace("a * 2", "a * 3"));
        let h = |v: &[Item]| v.iter().find(|i| i.locator.ends_with("::basic_fare")).unwrap().hash.clone();
        assert_ne!(h(&items), h(&items2));
    }
}
