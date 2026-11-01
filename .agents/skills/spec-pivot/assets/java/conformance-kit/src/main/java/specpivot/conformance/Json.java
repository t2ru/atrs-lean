package specpivot.conformance;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Iterator;
import java.util.Map;

/**
 * ベクタの JSON の読み書き（references/docs/spec/conformance.md#値の表現）。
 * ハーネス自身の ObjectMapper は原典の設定と分ける（harness.md）。数は整数だけを扱い、書き出しは
 * Python の {@code json.dumps(indent=2, ensure_ascii=False)} と同じ字面にする（差分を読みやすくするため）。
 * ケースのように 1 行に収めたい値は {@link #write(JsonNode, int)} の折り返しの深さで指定する。
 */
public final class Json {
    private Json() {}

    /** ハーネス専用の ObjectMapper。数は BigInteger・BigDecimal のまま読む。 */
    public static final ObjectMapper MAPPER = new ObjectMapper()
            .enable(com.fasterxml.jackson.databind.DeserializationFeature.USE_BIG_INTEGER_FOR_INTS)
            .enable(com.fasterxml.jackson.databind.DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);

    public static final JsonNodeFactory F = JsonNodeFactory.instance;

    public static JsonNode read(Path p) {
        try {
            return MAPPER.readTree(Files.readString(p, StandardCharsets.UTF_8));
        } catch (IOException e) {
            throw new UncheckedIOException(p.toString(), e);
        }
    }

    public static JsonNode parse(String s) {
        try {
            return MAPPER.readTree(s);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    public static ObjectNode obj() { return F.objectNode(); }
    public static ArrayNode arr() { return F.arrayNode(); }

    public static ObjectNode ok(JsonNode v) { ObjectNode o = obj(); o.set("ok", v); return o; }

    public static ObjectNode error(String kind, String code) {
        ObjectNode e = obj();
        e.put("kind", kind);
        e.put("code", code);
        ObjectNode o = obj();
        o.set("error", e);
        return o;
    }

    /** 整数としての比較を含む、値の等しさ（JSON オブジェクトはキーの順に依らない）。 */
    public static boolean same(JsonNode a, JsonNode b) {
        if (a == null || b == null) return a == b;
        if (a.isNumber() && b.isNumber()) {
            if (a.isIntegralNumber() && b.isIntegralNumber()) return a.bigIntegerValue().equals(b.bigIntegerValue());
            return a.decimalValue().compareTo(b.decimalValue()) == 0;
        }
        if (a.getNodeType() != b.getNodeType()) return false;
        if (a.isArray()) {
            if (a.size() != b.size()) return false;
            for (int i = 0; i < a.size(); i++) if (!same(a.get(i), b.get(i))) return false;
            return true;
        }
        if (a.isObject()) {
            if (a.size() != b.size()) return false;
            for (Iterator<Map.Entry<String, JsonNode>> it = a.fields(); it.hasNext();) {
                Map.Entry<String, JsonNode> e = it.next();
                if (!b.has(e.getKey()) || !same(e.getValue(), b.get(e.getKey()))) return false;
            }
            return true;
        }
        return a.equals(b);
    }

    /** Python の json.dumps(indent=2, ensure_ascii=False) と同じ字面（末尾の改行付き）。 */
    public static String write(JsonNode n) { return write(n, Integer.MAX_VALUE); }

    /**
     * 深さ {@code flatDepth} 以上の値を 1 行に書く（{@code json.dumps(..., separators=(", ", ": "))} の字面）。
     * 生成するベクタを小さくするために、ケースの中身を 1 行にするときに使う。
     */
    public static String write(JsonNode n, int flatDepth) {
        StringBuilder sb = new StringBuilder();
        emit(sb, n, 0, flatDepth);
        sb.append('\n');
        return sb.toString();
    }

    public static void save(Path p, JsonNode n, int flatDepth) {
        try {
            Files.createDirectories(p.toAbsolutePath().getParent());
            Files.writeString(p, write(n, flatDepth), StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new UncheckedIOException(p.toString(), e);
        }
    }

    private static void indent(StringBuilder sb, int depth) {
        sb.append('\n');
        for (int i = 0; i < depth; i++) sb.append("  ");
    }

    private static void emit(StringBuilder sb, JsonNode n, int depth, int flatDepth) {
        boolean flat = depth >= flatDepth;
        if (n.isObject()) {
            if (n.isEmpty()) { sb.append("{}"); return; }
            sb.append('{');
            boolean first = true;
            for (Iterator<Map.Entry<String, JsonNode>> it = n.fields(); it.hasNext();) {
                Map.Entry<String, JsonNode> e = it.next();
                if (!first) sb.append(',');
                if (flat) { if (!first) sb.append(' '); } else indent(sb, depth + 1);
                first = false;
                string(sb, e.getKey());
                sb.append(": ");
                emit(sb, e.getValue(), depth + 1, flatDepth);
            }
            if (!flat) indent(sb, depth);
            sb.append('}');
        } else if (n.isArray()) {
            if (n.isEmpty()) { sb.append("[]"); return; }
            sb.append('[');
            for (int i = 0; i < n.size(); i++) {
                if (i > 0) sb.append(',');
                if (flat) { if (i > 0) sb.append(' '); } else indent(sb, depth + 1);
                emit(sb, n.get(i), depth + 1, flatDepth);
            }
            if (!flat) indent(sb, depth);
            sb.append(']');
        } else if (n.isTextual()) {
            string(sb, n.textValue());
        } else if (n.isIntegralNumber()) {
            sb.append(n.bigIntegerValue().toString());
        } else if (n.isNumber()) {
            throw new IllegalArgumentException("non-integer number in a vector: " + n);
        } else if (n.isBoolean()) {
            sb.append(n.booleanValue() ? "true" : "false");
        } else if (n.isNull()) {
            sb.append("null");
        } else {
            throw new IllegalArgumentException("unsupported JSON node: " + n.getNodeType());
        }
    }

    private static void string(StringBuilder sb, String s) {
        sb.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                case '\b' -> sb.append("\\b");
                case '\f' -> sb.append("\\f");
                default -> {
                    if (c < 0x20 || Character.isSurrogate(c) && !validPair(s, i)) sb.append(String.format("\\u%04x", (int) c));
                    else sb.append(c);
                }
            }
        }
        sb.append('"');
    }

    private static boolean validPair(String s, int i) {
        char c = s.charAt(i);
        if (Character.isHighSurrogate(c)) return i + 1 < s.length() && Character.isLowSurrogate(s.charAt(i + 1));
        return i > 0 && Character.isHighSurrogate(s.charAt(i - 1));
    }

    public static JsonNode num(long v) { return F.numberNode(BigInteger.valueOf(v)); }
}
