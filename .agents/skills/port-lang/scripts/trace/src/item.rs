//! インベントリの項目。

use serde::{Deserialize, Serialize};

/// 1 つの追跡単位（ロケータで識別する）。
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct Item {
    /// ロケータ（`<kind>:<body>`）
    pub locator: String,
    /// ロケータの種類（`java`・`sql`・`rust` など）
    pub kind: String,
    /// リポジトリのルートからの相対パス
    pub file: String,
    /// 開始行と終了行（1 始まり）
    pub lines: [usize; 2],
    /// 正規化した本文のハッシュ（references/docs/traceability.md#道具）
    pub hash: String,
    /// `trace/out-of-scope.json` に当たるか
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub out_of_scope: bool,
}

impl Item {
    pub fn new(kind: &str, body: String, file: &str, lines: [usize; 2], normalized: &str) -> Item {
        Item {
            locator: format!("{kind}:{body}"),
            kind: kind.to_string(),
            file: file.to_string(),
            lines,
            hash: crate::normalize::hash(normalized),
            out_of_scope: false,
        }
    }
}
