//! Thymeleaf のテンプレートのインベントリ（`tmpl:`）。ADR 0eea による。
//!
//! - 単位: `th:*` 属性を持つ要素。
//! - ロケータ: `tmpl:<WEB-INF/views/ からのパス>#<id>`、`id` が無ければ
//!   `#<タグ>[@<最初の th: 属性>='<値>']`。同じものが複数あれば `[n]`（1 始まり）を付ける。
//! - ハッシュ: 開始タグ（全属性）を正規化したもの。

use crate::item::Item;
use crate::normalize::words;
use std::collections::HashMap;

/// 開始タグ（名前・属性の列・行）を順に返す。コメント・`<!…>`・`<?…>` は飛ばす。
pub fn start_tags(src: &str) -> Vec<(String, Vec<(String, String)>, usize)> {
    let cs: Vec<char> = src.chars().collect();
    let n = cs.len();
    let mut out = vec![];
    let (mut i, mut line) = (0usize, 1usize);
    while i < n {
        if cs[i] == '\n' {
            line += 1;
        }
        if cs[i] != '<' {
            i += 1;
            continue;
        }
        if src_starts(&cs, i, "<!--") {
            i += 4;
            while i < n && !src_starts(&cs, i, "-->") {
                if cs[i] == '\n' {
                    line += 1;
                }
                i += 1;
            }
            i += 3;
            continue;
        }
        if i + 1 < n && (cs[i + 1] == '!' || cs[i + 1] == '?' || cs[i + 1] == '/') {
            i += 1;
            continue;
        }
        let tag_line = line;
        i += 1;
        let mut name = String::new();
        while i < n && !cs[i].is_whitespace() && cs[i] != '>' && cs[i] != '/' {
            name.push(cs[i]);
            i += 1;
        }
        let mut attrs = vec![];
        loop {
            while i < n && cs[i].is_whitespace() {
                if cs[i] == '\n' {
                    line += 1;
                }
                i += 1;
            }
            if i >= n || cs[i] == '>' || (cs[i] == '/' && i + 1 < n && cs[i + 1] == '>') {
                break;
            }
            let mut an = String::new();
            while i < n && !cs[i].is_whitespace() && cs[i] != '=' && cs[i] != '>' && cs[i] != '/' {
                an.push(cs[i]);
                i += 1;
            }
            if an.is_empty() {
                i += 1;
                continue;
            }
            let mut val = String::new();
            if i < n && cs[i] == '=' {
                i += 1;
                if i < n && (cs[i] == '"' || cs[i] == '\'') {
                    let q = cs[i];
                    i += 1;
                    while i < n && cs[i] != q {
                        if cs[i] == '\n' {
                            line += 1;
                        }
                        val.push(cs[i]);
                        i += 1;
                    }
                    i += 1;
                } else {
                    while i < n && !cs[i].is_whitespace() && cs[i] != '>' {
                        val.push(cs[i]);
                        i += 1;
                    }
                }
            }
            attrs.push((an, val));
        }
        out.push((name.to_lowercase(), attrs, tag_line));
    }
    out
}

fn src_starts(cs: &[char], i: usize, s: &str) -> bool {
    let t: Vec<char> = s.chars().collect();
    i + t.len() <= cs.len() && cs[i..i + t.len()] == t[..]
}

/// `rel` は `WEB-INF/views/` からの相対パス。
pub fn scan(file: &str, rel: &str, src: &str) -> Vec<Item> {
    let mut raw = vec![];
    for (name, attrs, line) in start_tags(src) {
        let Some((th_name, th_val)) = attrs.iter().find(|(a, _)| a.starts_with("th:")) else { continue };
        let key = match attrs.iter().find(|(a, _)| a == "id") {
            Some((_, id)) => id.clone(),
            None => format!("{name}[@{th_name}='{}']", words(th_val)),
        };
        let norm = std::iter::once(name.clone())
            .chain(attrs.iter().map(|(a, v)| format!("{a}=\"{}\"", words(v))))
            .collect::<Vec<_>>()
            .join(" ");
        raw.push((key, line, norm));
    }
    let mut count: HashMap<String, usize> = HashMap::new();
    for (k, _, _) in &raw {
        *count.entry(k.clone()).or_default() += 1;
    }
    let mut seen: HashMap<String, usize> = HashMap::new();
    raw.into_iter()
        .map(|(k, line, norm)| {
            let body = if count[&k] > 1 {
                let c = seen.entry(k.clone()).or_default();
                *c += 1;
                format!("{rel}#{k}[{c}]")
            } else {
                format!("{rel}#{k}")
            };
            Item::new("tmpl", body, file, [line, line], &norm)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scans_th_elements() {
        let src = "<html>\n<!-- <span th:text=\"x\"> -->\n<span th:text=\"${a}\">a</span>\n<div id=\"d\" th:if=\"${b}\"/>\n\
                   <span th:text=\"${a}\"></span>\n<p class='x'>no</p>";
        let items = scan("v/B1/x.html", "B1/x.html", src);
        let locs: Vec<&str> = items.iter().map(|i| i.locator.as_str()).collect();
        assert_eq!(
            locs,
            vec!["tmpl:B1/x.html#span[@th:text='${a}'][1]", "tmpl:B1/x.html#d", "tmpl:B1/x.html#span[@th:text='${a}'][2]"]
        );
        assert_eq!(items[1].lines, [4, 4]);
    }
}
