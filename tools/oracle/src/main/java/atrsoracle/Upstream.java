package atrsoracle;

import com.fasterxml.jackson.databind.JsonNode;
import specpivot.conformance.Json;

import java.nio.file.Path;

/** 原典の場所と版（trace/upstream.json）。 */
final class Upstream {
    private Upstream() {}

    static Path atrs(Path repo) {
        return repo.resolve("upstream/atrs/JavaConfig-Thymeleaf/atrs");
    }

    /** 複写してビルドした原典（build-upstream.sh）。webapp の docBase に使う。 */
    static Path built(Path repo) {
        return repo.resolve("tools/oracle/target/upstream");
    }

    /** ベクタの {@code upstream}（{@code {"release", "commit"}}）。 */
    static JsonNode version(Path repo) {
        JsonNode u = Json.read(repo.resolve("trace/upstream.json"));
        var o = Json.obj();
        o.put("release", u.get("release").asText());
        o.put("commit", u.get("commit").asText());
        return o;
    }
}
