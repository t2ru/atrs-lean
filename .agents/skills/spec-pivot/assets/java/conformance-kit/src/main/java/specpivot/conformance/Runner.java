package specpivot.conformance;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

/**
 * ベクタのファイルを、操作の割当（operation → {@link Op}）で実行する（references/docs/lang/java/harness.md）。
 *
 * <ul>
 * <li>{@link #check}: 各ケースの結果を {@code expected.ok} と比べる（原典実行として [Source] のベクタを確かめる）。</li>
 * <li>{@link #fill}: 入力だけのケースの {@code expected} を埋め、{@code source} と {@code upstream} を付けた文書を返す
 * （原典実行が期待値を採取する）。</li>
 * </ul>
 */
public final class Runner {
    private Runner() {}

    /** 1 つのファイルの結果。 */
    public record FileResult(Path path, String operation, int passed, List<String> failures) {
        public boolean ok() { return failures.isEmpty() && passed > 0; }
    }

    /** ファイルの {@code operation} の割当を引く。無ければ null。 */
    public static Op opOf(JsonNode doc, Map<String, Op> ops) {
        return ops.get(doc.path("operation").asText());
    }

    public static FileResult check(Path path, Map<String, Op> ops) {
        JsonNode doc = Json.read(path);
        String operation = doc.path("operation").asText();
        Op op = ops.get(operation);
        List<String> failures = new ArrayList<>();
        if (op == null) {
            failures.add("no adapter for operation " + operation);
            return new FileResult(path, operation, 0, failures);
        }
        int passed = 0;
        for (JsonNode c : doc.path("cases")) {
            String id = c.path("id").asText();
            try {
                JsonNode got = Json.ok(op.run(c));
                if (Json.same(got, c.get("expected"))) passed++;
                else failures.add(id + ": expected " + c.get("expected") + ", got " + got);
            } catch (Exception | AssertionError e) {
                failures.add(id + ": " + e);
            }
        }
        return new FileResult(path, operation, passed, failures);
    }

    /** ディレクトリの直下の *.json を名前の順に。 */
    public static List<Path> jsonFiles(Path dir) {
        if (!Files.isDirectory(dir)) return List.of();
        try (Stream<Path> s = Files.list(dir)) {
            return s.filter(p -> p.toString().endsWith(".json")).sorted().toList();
        } catch (java.io.IOException e) {
            throw new java.io.UncheckedIOException(e);
        }
    }

    /**
     * 文書の各ケースの {@code expected} を埋める。ケースのキーの順は {@code id, description, today, now, world, input,
     * expected, source, …} とし、既にある {@code expected}・{@code source} は置き換える。
     */
    public static ObjectNode fill(ObjectNode doc, Op op, String source) throws Exception {
        ArrayNode out = Json.arr();
        for (JsonNode c : doc.withArray("cases")) {
            JsonNode expected = Json.ok(op.run(c));
            ObjectNode n = Json.obj();
            for (String k : List.of("id", "description", "today", "now", "world", "environment", "input")) {
                if (c.has(k)) n.set(k, c.get(k));
            }
            n.set("expected", expected);
            n.put("source", source);
            for (Iterator<Map.Entry<String, JsonNode>> it = c.fields(); it.hasNext();) {
                Map.Entry<String, JsonNode> e = it.next();
                if (!n.has(e.getKey())) n.set(e.getKey(), e.getValue());
            }
            out.add(n);
        }
        doc.set("cases", out);
        return doc;
    }

    /** 期待値の文書の頭（operation・modelDef・specRef・upstream・fixtures・note）。 */
    public static ObjectNode header(String operation, JsonNode modelDef, String specRef, JsonNode upstream, JsonNode fixtures,
            String note) {
        ObjectNode d = Json.obj();
        d.put("operation", operation);
        d.set("modelDef", modelDef);
        d.put("specRef", specRef);
        if (note != null) d.put("note", note);
        if (upstream != null) d.set("upstream", upstream);
        if (fixtures != null) d.set("fixtures", fixtures);
        d.set("cases", Json.arr());
        return d;
    }

    /** 文書の書き出しを、既存のファイルと比べる（--check）か、書き込む（--write）。差があれば説明を返す。 */
    public static String saveOrCompare(Path path, JsonNode doc, int flatDepth, boolean write) {
        String text = Json.write(doc, flatDepth);
        try {
            if (write) {
                Files.createDirectories(path.toAbsolutePath().getParent());
                Files.writeString(path, text, java.nio.charset.StandardCharsets.UTF_8);
                return null;
            }
            if (!Files.exists(path)) return path + ": missing (run with --write)";
            String old = Files.readString(path, java.nio.charset.StandardCharsets.UTF_8);
            if (old.equals(text)) return null;
            String[] a = old.split("\n", -1), b = text.split("\n", -1);
            for (int i = 0; i < Math.min(a.length, b.length); i++) {
                if (!a[i].equals(b[i])) return path + ": differs at line " + (i + 1) + "\n  - " + a[i] + "\n  + " + b[i];
            }
            return path + ": differs in length (" + a.length + " vs " + b.length + " lines)";
        } catch (java.io.IOException e) {
            throw new java.io.UncheckedIOException(e);
        }
    }
}
