//! 本文の正規化とハッシュ（references/docs/traceability.md#道具）。
//!
//! - 正規化した本文は、構文解析器のトークン列（コメントを除く）を空白 1 つでつないだもの。
//!   空白・改行・インデントの違いは無視し、文字列リテラルの中身は保つ。
//! - ハッシュは、正規化した本文の SHA-256 の先頭 16 桁（小文字 16 進）。

use sha2::{Digest, Sha256};
use tree_sitter::Node;

/// 正規化した本文のハッシュ。
pub fn hash(normalized: &str) -> String {
    let digest = Sha256::digest(normalized.as_bytes());
    digest.iter().take(8).map(|b| format!("{b:02x}")).collect()
}

/// tree-sitter の構文木の葉を、コメントを除いて空白 1 つでつなぐ。
/// `atomic` に含まれる種類の節（文字列リテラルなど）は、子に下りずに原文のまま 1 トークンとする。
pub fn ts_tokens(node: Node, src: &[u8], comments: &[&str], atomic: &[&str], out: &mut Vec<String>) {
    let kind = node.kind();
    if comments.contains(&kind) {
        return;
    }
    if atomic.contains(&kind) || node.child_count() == 0 {
        if let Ok(t) = node.utf8_text(src) {
            if !t.trim().is_empty() {
                out.push(t.to_string());
            }
        }
        return;
    }
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        ts_tokens(child, src, comments, atomic, out);
    }
}

/// SQL の予約語（大文字にするもの）。
const SQL_KEYWORDS: &[&str] = &[
    "ADD", "ALL", "ALTER", "AND", "ANY", "AS", "ASC", "BEGIN", "BETWEEN", "BY", "CASCADE", "CASE", "CAST",
    "CHAR", "CHARACTER", "CHECK", "COALESCE", "COMMIT", "CONSTRAINT", "COUNT", "CREATE", "CROSS", "CURRENT_DATE",
    "CURRENT_TIMESTAMP", "DATE", "DECIMAL", "DECLARE", "DEFAULT", "DELETE", "DESC", "DISTINCT", "DO", "DROP",
    "ELSE", "END", "EXISTS", "FALSE", "FOR", "FOREIGN", "FROM", "FULL", "FUNCTION", "GROUP", "HAVING", "IF",
    "IN", "INDEX", "INNER", "INSERT", "INT", "INTEGER", "INTO", "IS", "JOIN", "KEY", "LANGUAGE", "LEFT",
    "LIKE", "LIMIT", "LOOP", "MAX", "MIN", "NEXTVAL", "NOT", "NULL", "NUMERIC", "OFFSET", "ON", "OR", "ORDER",
    "OUTER", "PRIMARY", "REFERENCES", "REPLACE", "RETURN", "RETURNS", "RIGHT", "SELECT", "SEQUENCE", "SET",
    "SMALLINT", "SUM", "TABLE", "THEN", "TIMESTAMP", "TO", "TO_CHAR", "TRUE", "UNIQUE", "UPDATE", "USING",
    "VALUES", "VARCHAR", "VOID", "WHEN", "WHERE", "WHILE", "WITH",
];

/// SQL の字句解析。コメント（`--`・`/* */`）を除き、予約語を大文字にする。
/// 文字列（`'…'`）・識別子の引用（`"…"`）・MyBatis の `#{…}`・`${…}` は 1 トークンとし、原文のまま保つ。
pub fn sql_tokens(s: &str, out: &mut Vec<String>) {
    let cs: Vec<char> = s.chars().collect();
    let n = cs.len();
    let mut i = 0;
    while i < n {
        let c = cs[i];
        if c.is_whitespace() {
            i += 1;
        } else if c == '-' && i + 1 < n && cs[i + 1] == '-' {
            while i < n && cs[i] != '\n' {
                i += 1;
            }
        } else if c == '/' && i + 1 < n && cs[i + 1] == '*' {
            i += 2;
            while i + 1 < n && !(cs[i] == '*' && cs[i + 1] == '/') {
                i += 1;
            }
            i = (i + 2).min(n);
        } else if c == '\'' || c == '"' {
            let start = i;
            i += 1;
            while i < n {
                if cs[i] == c {
                    if i + 1 < n && cs[i + 1] == c {
                        i += 2;
                        continue;
                    }
                    break;
                }
                i += 1;
            }
            i = (i + 1).min(n);
            out.push(cs[start..i].iter().collect());
        } else if (c == '#' || c == '$') && i + 1 < n && cs[i + 1] == '{' {
            let start = i;
            while i < n && cs[i] != '}' {
                i += 1;
            }
            i = (i + 1).min(n);
            out.push(cs[start..i].iter().collect());
        } else if c.is_alphanumeric() || c == '_' {
            let start = i;
            while i < n && (cs[i].is_alphanumeric() || cs[i] == '_' || cs[i] == '.') {
                i += 1;
            }
            let w: String = cs[start..i].iter().collect();
            let up = w.to_uppercase();
            out.push(if SQL_KEYWORDS.contains(&up.as_str()) { up } else { w });
        } else {
            // 演算子・区切り（`<=`・`<>`・`>=`・`!=`・`||`・`::`・`:=`・`$$` は 2 文字で 1 トークン）
            if i + 1 < n {
                let two: String = cs[i..i + 2].iter().collect();
                if ["<=", ">=", "<>", "!=", "||", "::", ":=", "$$"].contains(&two.as_str()) {
                    out.push(two);
                    i += 2;
                    continue;
                }
            }
            out.push(c.to_string());
            i += 1;
        }
    }
}

/// 空白で区切った一般のテキスト（属性値などの正規化に使う）。
pub fn words(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hash_is_16_hex() {
        let h = hash("abc");
        assert_eq!(h.len(), 16);
        assert_eq!(h, "ba7816bf8f01cfea");
    }

    #[test]
    fn sql_ignores_whitespace_and_comments_but_keeps_literals() {
        let mut a = vec![];
        sql_tokens("select  a -- c\n from t where x = 'a  b' /* x */ and y = #{p}", &mut a);
        let mut b = vec![];
        sql_tokens("SELECT a\nFROM t\nWHERE x='a  b' AND y=#{p}", &mut b);
        assert_eq!(a, b);
        assert!(a.contains(&"'a  b'".to_string()));
    }
}
