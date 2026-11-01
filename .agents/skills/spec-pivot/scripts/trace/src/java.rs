//! Java のインベントリ（`java:`・`http:`）。lang/java/locators.md と references/docs/spec/traceability.md#道具 による。
//!
//! - 単位: public・protected・package-private のメソッドとコンストラクタ、`static final` の定数、enum の定数。
//!   private メソッドは単位にせず、同じクラスで呼ぶ側の本文の後に連結する（推移的。初出順、重複なし）。
//! - 引数は単純型名（総称を消し、配列・可変長は保つ）。内部クラスは `Outer$Inner`。
//! - `http:` は、`@RequestMapping` 系の注釈を持つハンドラごと。クラスの `@RequestMapping` のパスと合成する。

use crate::item::Item;
use crate::normalize::ts_tokens;
use std::collections::HashMap;
use tree_sitter::{Node, Parser};

const COMMENTS: &[&str] = &["line_comment", "block_comment"];
const ATOMIC: &[&str] = &["string_literal", "character_literal", "text_block"];

fn text<'a>(n: Node, src: &'a [u8]) -> &'a str {
    n.utf8_text(src).unwrap_or("")
}

fn tokens(n: Node, src: &[u8]) -> String {
    let mut out = vec![];
    ts_tokens(n, src, COMMENTS, ATOMIC, &mut out);
    out.join(" ")
}

fn lines(n: Node) -> [usize; 2] {
    [n.start_position().row + 1, n.end_position().row + 1]
}

fn modifiers<'a>(n: Node<'a>) -> Option<Node<'a>> {
    let mut c = n.walk();
    n.children(&mut c).find(|ch| ch.kind() == "modifiers")
}

fn has_modifier(n: Node, src: &[u8], word: &str) -> bool {
    match modifiers(n) {
        Some(m) => {
            let mut c = m.walk();
            m.children(&mut c).any(|ch| text(ch, src) == word)
        }
        None => false,
    }
}

/// 型の単純名（総称を消し、配列の `[]` は保つ）。
fn simple_type(t: &str) -> String {
    let mut s = String::new();
    let mut depth = 0;
    for ch in t.chars() {
        match ch {
            '<' => depth += 1,
            '>' => depth -= 1,
            _ if depth == 0 && !ch.is_whitespace() => s.push(ch),
            _ => {}
        }
    }
    // 修飾名は最後の要素（配列の [] は残す）
    let (base, arr) = match s.find('[') {
        Some(i) => (s[..i].to_string(), s[i..].to_string()),
        None => (s.clone(), String::new()),
    };
    let simple = base.rsplit('.').next().unwrap_or(&base).to_string();
    simple + &arr
}

fn param_types(n: Node, src: &[u8]) -> Vec<String> {
    let mut out = vec![];
    if let Some(ps) = n.child_by_field_name("parameters") {
        let mut c = ps.walk();
        for p in ps.children(&mut c) {
            match p.kind() {
                "formal_parameter" => {
                    let t = p.child_by_field_name("type").map(|t| text(t, src)).unwrap_or("");
                    // `String args[]` の形の次元も型に含める
                    let dims = p.child_by_field_name("dimensions").map(|d| text(d, src)).unwrap_or("");
                    out.push(simple_type(&format!("{t}{dims}")));
                }
                "spread_parameter" => {
                    let mut c2 = p.walk();
                    let t = p
                        .children(&mut c2)
                        .find(|ch| ch.kind() != "modifiers" && ch.kind() != "variable_declarator" && ch.kind() != "...")
                        .map(|t| text(t, src))
                        .unwrap_or("");
                    out.push(format!("{}...", simple_type(t)));
                }
                _ => {}
            }
        }
    }
    out
}

/// 本文の中で呼ぶ、同じクラスの private メソッドの名前（初出順）。
fn private_calls(n: Node, src: &[u8], privates: &HashMap<String, Vec<Node>>, out: &mut Vec<String>) {
    if n.kind() == "method_invocation" {
        let obj = n.child_by_field_name("object").map(|o| text(o, src));
        if obj.is_none() || obj == Some("this") {
            if let Some(name) = n.child_by_field_name("name").map(|x| text(x, src).to_string()) {
                if privates.contains_key(&name) && !out.contains(&name) {
                    out.push(name);
                }
            }
        }
    }
    let mut c = n.walk();
    for ch in n.children(&mut c) {
        // 局所クラス・匿名クラスの中も、同じ本文の一部として見る
        private_calls(ch, src, privates, out);
    }
}

/// 本文 + 推移的に呼ぶ private メソッドの本文。
fn body_with_privates(n: Node, src: &[u8], privates: &HashMap<String, Vec<Node>>) -> String {
    let mut parts = vec![tokens(n, src)];
    let mut seen: Vec<String> = vec![];
    let mut queue: Vec<String> = vec![];
    private_calls(n, src, privates, &mut queue);
    let mut i = 0;
    while i < queue.len() {
        let name = queue[i].clone();
        i += 1;
        if seen.contains(&name) {
            continue;
        }
        seen.push(name.clone());
        for m in &privates[&name] {
            parts.push(tokens(*m, src));
            let mut more = vec![];
            private_calls(*m, src, privates, &mut more);
            for x in more {
                if !queue.contains(&x) {
                    queue.push(x);
                }
            }
        }
    }
    parts.join(" ")
}

/// 注釈の情報（名前と引数の原文）。
struct Annot {
    name: String,
    args: String,
}

fn annotations(n: Node, src: &[u8]) -> Vec<Annot> {
    let mut out = vec![];
    if let Some(m) = modifiers(n) {
        let mut c = m.walk();
        for a in m.children(&mut c) {
            if a.kind() == "annotation" || a.kind() == "marker_annotation" {
                let name = a.child_by_field_name("name").map(|x| text(x, src)).unwrap_or("");
                let name = name.rsplit('.').next().unwrap_or(name).to_string();
                let args = a.child_by_field_name("arguments").map(|x| text(x, src)).unwrap_or("").to_string();
                out.push(Annot { name, args });
            }
        }
    }
    out
}

/// 注釈の引数から、指定した要素の値（無ければ位置引数）の文字列リテラルを取り出す。
fn annot_strings(args: &str, keys: &[&str], positional: bool) -> Vec<String> {
    // 引数を最上位の `,` で分ける
    let inner = args.trim().trim_start_matches('(').trim_end_matches(')');
    let mut parts = vec![];
    let (mut depth, mut start, mut in_str) = (0, 0, false);
    let cs: Vec<char> = inner.chars().collect();
    for (i, ch) in cs.iter().enumerate() {
        match ch {
            '"' => in_str = !in_str,
            '{' | '(' if !in_str => depth += 1,
            '}' | ')' if !in_str => depth -= 1,
            ',' if !in_str && depth == 0 => {
                parts.push(cs[start..i].iter().collect::<String>());
                start = i + 1;
            }
            _ => {}
        }
    }
    parts.push(cs[start..].iter().collect::<String>());
    let mut out = vec![];
    for p in parts {
        let p = p.trim();
        let (key, val) = match p.split_once('=') {
            Some((k, v)) if !k.contains('"') => (Some(k.trim()), v.trim()),
            _ => (None, p),
        };
        let take = match key {
            Some(k) => keys.contains(&k),
            None => positional,
        };
        if take {
            out.extend(string_literals(val));
        }
    }
    out
}

fn string_literals(s: &str) -> Vec<String> {
    let mut out = vec![];
    let mut cur: Option<String> = None;
    let mut esc = false;
    for ch in s.chars() {
        match (&mut cur, ch) {
            (None, '"') => cur = Some(String::new()),
            (Some(_), '\\') if !esc => esc = true,
            (Some(b), '"') if !esc => {
                out.push(std::mem::take(b));
                cur = None;
            }
            (Some(b), c) => {
                b.push(c);
                esc = false;
            }
            _ => {}
        }
    }
    out
}

fn annot_methods(a: &Annot) -> Vec<String> {
    match a.name.as_str() {
        "GetMapping" => vec!["GET".into()],
        "PostMapping" => vec!["POST".into()],
        "PutMapping" => vec!["PUT".into()],
        "DeleteMapping" => vec!["DELETE".into()],
        "PatchMapping" => vec!["PATCH".into()],
        _ => {
            let mut v = vec![];
            for m in ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"] {
                if a.args.contains(&format!("RequestMethod.{m}")) {
                    v.push(m.to_string());
                }
            }
            if v.is_empty() {
                v.push("*".into());
            }
            v
        }
    }
}

const MAPPINGS: &[&str] =
    &["RequestMapping", "GetMapping", "PostMapping", "PutMapping", "DeleteMapping", "PatchMapping"];

fn join_path(a: &str, b: &str) -> String {
    let segs: Vec<&str> = a.split('/').chain(b.split('/')).filter(|s| !s.is_empty()).collect();
    format!("/{}", segs.join("/"))
}

struct Ctx<'s> {
    src: &'s [u8],
    file: &'s str,
    out: Vec<Item>,
}

fn scan_type(n: Node, prefix: &str, ctx: &mut Ctx) {
    let src = ctx.src;
    let name = n.child_by_field_name("name").map(|x| text(x, src)).unwrap_or("?");
    let fqcn = format!("{prefix}{name}");
    let class_paths: Vec<String> = annotations(n, src)
        .iter()
        .filter(|a| a.name == "RequestMapping")
        .flat_map(|a| annot_strings(&a.args, &["value", "path"], true))
        .collect();
    let class_paths = if class_paths.is_empty() { vec![String::new()] } else { class_paths };
    let Some(body) = n.child_by_field_name("body") else { return };
    // enum の本体は enum_body（定数と enum_body_declarations）
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
    let is_interface = n.kind() == "interface_declaration" || n.kind() == "annotation_type_declaration";
    let mut privates: HashMap<String, Vec<Node>> = HashMap::new();
    for m in &members {
        if m.kind() == "method_declaration" && has_modifier(*m, src, "private") {
            let nm = m.child_by_field_name("name").map(|x| text(x, src).to_string()).unwrap_or_default();
            privates.entry(nm).or_default().push(*m);
        }
    }
    for m in members {
        match m.kind() {
            "method_declaration" | "constructor_declaration" => {
                if !is_interface && has_modifier(m, src, "private") {
                    continue;
                }
                let mname = if m.kind() == "constructor_declaration" {
                    "<init>".to_string()
                } else {
                    m.child_by_field_name("name").map(|x| text(x, src).to_string()).unwrap_or_default()
                };
                let sig = param_types(m, src).join(",");
                let norm = body_with_privates(m, src, &privates);
                ctx.out.push(Item::new("java", format!("{fqcn}#{mname}({sig})"), ctx.file, lines(m), &norm));
                for a in annotations(m, src).iter().filter(|a| MAPPINGS.contains(&a.name.as_str())) {
                    let paths = annot_strings(&a.args, &["value", "path"], true);
                    let paths = if paths.is_empty() { vec![String::new()] } else { paths };
                    let params = annot_strings(&a.args, &["params"], false);
                    let q = if params.is_empty() { String::new() } else { format!("?{}", params.join("&")) };
                    for meth in annot_methods(a) {
                        for cp in &class_paths {
                            for p in &paths {
                                let body = format!("{meth} {}{q}", join_path(cp, p));
                                ctx.out.push(Item::new("http", body, ctx.file, lines(m), &norm));
                            }
                        }
                    }
                }
            }
            "field_declaration" | "constant_declaration" => {
                let is_const = m.kind() == "constant_declaration"
                    || (has_modifier(m, src, "static") && has_modifier(m, src, "final"));
                if !is_const {
                    continue;
                }
                let norm = tokens(m, src);
                let mut c2 = m.walk();
                for d in m.children(&mut c2).filter(|d| d.kind() == "variable_declarator") {
                    let v = d.child_by_field_name("name").map(|x| text(x, src)).unwrap_or("?");
                    ctx.out.push(Item::new("java", format!("{fqcn}.{v}"), ctx.file, lines(m), &norm));
                }
            }
            "enum_constant" => {
                let v = m.child_by_field_name("name").map(|x| text(x, src)).unwrap_or("?");
                ctx.out.push(Item::new("java", format!("{fqcn}.{v}"), ctx.file, lines(m), &tokens(m, src)));
            }
            "class_declaration" | "interface_declaration" | "enum_declaration" | "record_declaration"
            | "annotation_type_declaration" => {
                scan_type(m, &format!("{fqcn}$"), ctx);
            }
            _ => {}
        }
    }
}

/// 1 ファイルを走査する。`file` はリポジトリのルートからの相対パス。
pub fn scan(file: &str, source: &str) -> Vec<Item> {
    let mut parser = Parser::new();
    parser.set_language(&tree_sitter_java::LANGUAGE.into()).expect("tree-sitter-java");
    let tree = parser.parse(source, None).expect("parse");
    let root = tree.root_node();
    let src = source.as_bytes();
    let mut package = String::new();
    let mut ctx = Ctx { src, file, out: vec![] };
    let mut c = root.walk();
    for n in root.children(&mut c) {
        match n.kind() {
            "package_declaration" => {
                let mut c2 = n.walk();
                if let Some(id) =
                    n.children(&mut c2).find(|x| x.kind() == "scoped_identifier" || x.kind() == "identifier")
                {
                    package = format!("{}.", text(id, src));
                }
            }
            "class_declaration" | "interface_declaration" | "enum_declaration" | "record_declaration"
            | "annotation_type_declaration" => scan_type(n, &package, &mut ctx),
            _ => {}
        }
    }
    ctx.out
}

#[cfg(test)]
mod tests {
    use super::*;

    const SRC: &str = r#"
package com.example;

@RequestMapping("orders")
public class OrderController {
    public static final int LIMIT = 10;
    private static final String P = "a";
    private int count;

    @RequestMapping(method = RequestMethod.GET, params = "confirm")
    public String confirm(Map<String, List<Integer>> m, int[] xs, String... rest) {
        return helper(1); // comment
    }

    @PostMapping("save")
    String save() { return "x"; }

    private String helper(int n) { return inner(); }
    private String inner() { return "inner"; }

    public OrderController(int a) {}

    enum Kind { A, B; }

    static class Inner { void run() {} }
}
"#;

    #[test]
    fn scans_members_and_handlers() {
        let items = scan("F.java", SRC);
        let locs: Vec<&str> = items.iter().map(|i| i.locator.as_str()).collect();
        assert!(locs.contains(&"java:com.example.OrderController.LIMIT"));
        assert!(locs.contains(&"java:com.example.OrderController.P"));
        assert!(locs.contains(&"java:com.example.OrderController#confirm(Map,int[],String...)"));
        assert!(locs.contains(&"java:com.example.OrderController#save()"));
        assert!(locs.contains(&"java:com.example.OrderController#<init>(int)"));
        assert!(locs.contains(&"java:com.example.OrderController$Kind.A"));
        assert!(locs.contains(&"java:com.example.OrderController$Inner#run()"));
        assert!(locs.contains(&"http:GET /orders?confirm"));
        assert!(locs.contains(&"http:POST /orders/save"));
        assert!(!locs.iter().any(|l| l.contains("helper") || l.contains("count")));
    }

    #[test]
    fn private_callee_changes_caller_hash() {
        let a = scan("F.java", SRC);
        let b = scan("F.java", &SRC.replace("return \"inner\"", "return \"changed\""));
        let h = |items: &[Item]| {
            items.iter().find(|i| i.locator.ends_with("#confirm(Map,int[],String...)")).unwrap().hash.clone()
        };
        assert_ne!(h(&a), h(&b));
    }

    #[test]
    fn whitespace_and_comments_do_not_change_hash() {
        let a = scan("F.java", SRC);
        let b = scan("F.java", &SRC.replace("return helper(1); // comment", "return   helper( 1 ) ;"));
        assert_eq!(a, b.into_iter().map(|mut i| { i.lines = a.iter().find(|x| x.locator == i.locator).unwrap().lines; i }).collect::<Vec<_>>());
    }
}
