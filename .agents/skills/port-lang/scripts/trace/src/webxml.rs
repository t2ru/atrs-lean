//! `web.xml` のインベントリ（`xml:`）。references/docs/spec/traceability.md#道具 による。
//!
//! - 単位: `<web-app>` 直下の要素。ロケータは `xml:web.xml#<要素>[<識別子の子要素>=<値>]`。
//!   識別子が無い要素、同じものが複数ある要素は `[n]` を付ける。
//! - ハッシュ: 要素を、タグとテキストのトークンの列にしたもの。

use crate::item::Item;
use crate::normalize::words;
use roxmltree::{Document, Node, ParsingOptions};
use std::collections::HashMap;

const IDS: &[&str] = &["param-name", "filter-name", "servlet-name", "listener-class", "error-code", "exception-type"];

fn tokens(n: Node, out: &mut Vec<String>) {
    for ch in n.children() {
        if ch.is_text() {
            let t = words(ch.text().unwrap_or(""));
            if !t.is_empty() {
                out.push(t);
            }
        } else if ch.is_element() {
            out.push(format!("<{}>", ch.tag_name().name()));
            tokens(ch, out);
            out.push(format!("</{}>", ch.tag_name().name()));
        }
    }
}

pub fn scan(file: &str, src: &str) -> Result<Vec<Item>, String> {
    let opts = ParsingOptions { allow_dtd: true, ..ParsingOptions::default() };
    let doc = Document::parse_with_options(src, opts).map_err(|e| format!("{file}: {e}"))?;
    let name = file.rsplit('/').next().unwrap_or(file);
    let mut raw = vec![];
    for ch in doc.root_element().children().filter(|c| c.is_element()) {
        let tag = ch.tag_name().name().to_string();
        let id = IDS.iter().find_map(|k| {
            ch.children()
                .find(|c| c.is_element() && c.tag_name().name() == *k)
                .map(|c| format!("[{k}={}]", words(c.text().unwrap_or(""))))
        });
        let mut toks = vec![format!("<{tag}>")];
        tokens(ch, &mut toks);
        let r = ch.range();
        let lines = [doc.text_pos_at(r.start).row as usize, doc.text_pos_at(r.end).row as usize];
        raw.push((format!("{tag}{}", id.unwrap_or_default()), lines, toks.join(" ")));
    }
    let mut count: HashMap<String, usize> = HashMap::new();
    for (k, _, _) in &raw {
        *count.entry(k.clone()).or_default() += 1;
    }
    let mut seen: HashMap<String, usize> = HashMap::new();
    Ok(raw
        .into_iter()
        .map(|(k, lines, norm)| {
            let key = if count[&k] > 1 {
                let c = seen.entry(k.clone()).or_default();
                *c += 1;
                format!("{k}[{c}]")
            } else {
                k
            };
            Item::new("xml", format!("{name}#{key}"), file, lines, &norm)
        })
        .collect())
}
