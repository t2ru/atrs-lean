//! MyBatis の Mapper XML のインベントリ（`sql:`）。sql/locators.md と ADR 0040 による。
//!
//! - 単位: `<select|insert|update|delete id=…>`（`<selectKey>`・`<foreach>` などの動的要素を含む）。
//! - 本文: 要素を、タグ（属性を含む）と SQL のトークンの列にしたもの。`<include refid>` は参照する
//!   `<sql>` 断片で置き換え、`resultMap` 属性が参照する `<resultMap>` の定義を後ろに連結する。

use crate::item::Item;
use crate::normalize::sql_tokens;
use roxmltree::{Document, Node, ParsingOptions};
use std::collections::HashMap;

fn tag_tokens(n: Node, frags: &HashMap<String, Node>, out: &mut Vec<String>, depth: usize) {
    if depth > 32 {
        return;
    }
    for ch in n.children() {
        if ch.is_text() {
            sql_tokens(ch.text().unwrap_or(""), out);
        } else if ch.is_element() {
            let name = ch.tag_name().name();
            if name == "include" {
                if let Some(f) = ch.attribute("refid").and_then(|r| frags.get(r)) {
                    tag_tokens(*f, frags, out, depth + 1);
                    continue;
                }
            }
            out.push(open_tag(ch));
            tag_tokens(ch, frags, out, depth + 1);
            out.push(format!("</{name}>"));
        }
    }
}

fn open_tag(n: Node) -> String {
    let mut s = format!("<{}", n.tag_name().name());
    for a in n.attributes() {
        s.push_str(&format!(" {}=\"{}\"", a.name(), crate::normalize::words(a.value())));
    }
    s.push('>');
    s
}

fn line_of(doc: &Document, pos: usize) -> usize {
    doc.text_pos_at(pos).row as usize
}

pub fn scan(file: &str, src: &str) -> Result<Vec<Item>, String> {
    let opts = ParsingOptions { allow_dtd: true, ..ParsingOptions::default() };
    let doc = Document::parse_with_options(src, opts).map_err(|e| format!("{file}: {e}"))?;
    let root = doc.root_element();
    let ns = root.attribute("namespace").unwrap_or_else(|| file.rsplit('/').next().unwrap_or(file));
    let mut frags = HashMap::new();
    let mut maps = HashMap::new();
    for ch in root.children().filter(|c| c.is_element()) {
        match ch.tag_name().name() {
            "sql" => {
                if let Some(id) = ch.attribute("id") {
                    frags.insert(id.to_string(), ch);
                }
            }
            "resultMap" => {
                if let Some(id) = ch.attribute("id") {
                    maps.insert(id.to_string(), ch);
                }
            }
            _ => {}
        }
    }
    let mut out = vec![];
    for ch in root.children().filter(|c| c.is_element()) {
        let tag = ch.tag_name().name();
        if !["select", "insert", "update", "delete"].contains(&tag) {
            continue;
        }
        let Some(id) = ch.attribute("id") else { continue };
        let mut toks = vec![open_tag(ch)];
        tag_tokens(ch, &frags, &mut toks, 0);
        toks.push(format!("</{tag}>"));
        if let Some(m) = ch.attribute("resultMap").and_then(|r| maps.get(r)) {
            toks.push(open_tag(*m));
            tag_tokens(*m, &frags, &mut toks, 0);
            toks.push("</resultMap>".into());
        }
        let r = ch.range();
        out.push(Item::new(
            "sql",
            format!("{ns}#{id}"),
            file,
            [line_of(&doc, r.start), line_of(&doc, r.end)],
            &toks.join(" "),
        ));
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    const X: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="a.b.Repo">
  <resultMap id="m" type="T"><id property="x" column="x"/></resultMap>
  <sql id="cols">x, y</sql>
  <!-- c -->
  <select id="find" resultMap="m">
    select <include refid="cols"/> from t
    <where><if test="a != null">and a = #{a}</if></where>
  </select>
</mapper>"#;

    #[test]
    fn scans_statements() {
        let items = scan("R.xml", X).unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].locator, "sql:a.b.Repo#find");
        // 断片・resultMap の変更はハッシュを変える
        let h2 = scan("R.xml", &X.replace("x, y", "x, z")).unwrap()[0].hash.clone();
        let h3 = scan("R.xml", &X.replace("column=\"x\"", "column=\"w\"")).unwrap()[0].hash.clone();
        assert_ne!(items[0].hash, h2);
        assert_ne!(items[0].hash, h3);
        // 空白と大小文字（予約語）は変えない
        let h4 = scan("R.xml", &X.replace("select <include", "SELECT\n   <include")).unwrap()[0].hash.clone();
        assert_eq!(items[0].hash, h4);
    }
}
