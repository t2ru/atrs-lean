package specpivot.conformance.http;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import specpivot.conformance.Json;

import java.io.IOException;
import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;
import java.util.regex.Pattern;

/**
 * 要求（ベクタの {@code input} の形）を実際の HTTP で送り、応答をベクタの値の形に採取する。
 *
 * <p>要求の形: {@code {"method", "path", "query"?: [[k, v], …], "headers"?: [[k, v], …],
 * "json"?: 値, "form"?: [[k, v], …]}}。{@code path} は文脈パスからの相対。</p>
 *
 * <p>応答の形: {@code {"status", "headers": [[k, v], …], "json" | "text"?}}。ヘッダは {@link #KEPT_HEADERS} だけを、
 * 名前の小文字で残す。実行ごとに変わる値は正規化する（{@code Location} のスキーム・ホスト・ポートと
 * {@code ;jsessionid=…}、{@code Set-Cookie} の値）。本文の扱い（JSON・HTML の抜き出し）は呼び出し側が決める。</p>
 *
 * <p>Cookie はセッション（このオブジェクト）ごとに保持する。転送（3xx）は追わない。</p>
 */
public final class HttpCapture {
    public static final List<String> KEPT_HEADERS =
            List.of("content-type", "location", "www-authenticate", "set-cookie", "content-disposition");

    private static final Pattern JSESSIONID = Pattern.compile(";jsessionid=[^?#]*", Pattern.CASE_INSENSITIVE);

    private final String baseUrl;
    private final HttpClient client;
    private final CookieManager cookies = new CookieManager(null, CookiePolicy.ACCEPT_ALL);

    public HttpCapture(String baseUrl) {
        this.baseUrl = baseUrl;
        this.client = HttpClient.newBuilder().cookieHandler(cookies).followRedirects(HttpClient.Redirect.NEVER)
                .proxy(HttpClient.Builder.NO_PROXY).connectTimeout(Duration.ofSeconds(30)).build();
    }

    /** 応答（正規化前の本文付き）。 */
    public record Response(int status, ObjectNode json, String body, String contentType) {}

    public Response send(JsonNode request) throws IOException, InterruptedException {
        String method = request.path("method").asText();
        StringBuilder url = new StringBuilder(baseUrl).append(request.path("path").asText());
        if (request.has("query")) url.append('?').append(encode(request.get("query")));
        HttpRequest.Builder b = HttpRequest.newBuilder(URI.create(url.toString())).timeout(Duration.ofSeconds(60));
        for (JsonNode h : request.path("headers")) b.header(h.get(0).asText(), h.get(1).asText());
        HttpRequest.BodyPublisher body = HttpRequest.BodyPublishers.noBody();
        if (request.has("json")) {
            b.header("Content-Type", "application/json;charset=UTF-8");
            body = HttpRequest.BodyPublishers.ofString(request.get("json").toString(), StandardCharsets.UTF_8);
        } else if (request.has("form")) {
            b.header("Content-Type", "application/x-www-form-urlencoded;charset=UTF-8");
            body = HttpRequest.BodyPublishers.ofString(encode(request.get("form")), StandardCharsets.UTF_8);
        }
        b.method(method, body);
        HttpResponse<String> r = client.send(b.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        ObjectNode out = Json.obj();
        out.put("status", r.statusCode());
        var headers = Json.arr();
        for (String name : KEPT_HEADERS) {
            for (String v : r.headers().allValues(name)) {
                var pair = Json.arr();
                pair.add(name);
                pair.add(normalizeHeader(name, v));
                headers.add(pair);
            }
        }
        out.set("headers", headers);
        String ct = r.headers().firstValue("content-type").orElse("");
        return new Response(r.statusCode(), out, r.body(), ct);
    }

    /** 応答の本文を JSON として足す（{@code json}）。本文が空なら何もしない。 */
    public static ObjectNode withJsonBody(Response r) {
        ObjectNode o = r.json().deepCopy();
        if (!r.body().isEmpty()) o.set("json", Json.parse(r.body()));
        return o;
    }

    static String normalizeHeader(String name, String v) {
        if (name.equals("location")) {
            String s = JSESSIONID.matcher(v).replaceAll("");
            return s.replaceFirst("^https?://[^/]+", "");
        }
        if (name.equals("set-cookie")) {
            int eq = v.indexOf('=');
            int semi = v.indexOf(';');
            if (eq > 0) return v.substring(0, eq + 1) + "…" + (semi > eq ? v.substring(semi) : "");
        }
        return v;
    }

    private static String encode(JsonNode pairs) {
        StringJoiner j = new StringJoiner("&");
        for (JsonNode p : pairs) {
            j.add(URLEncoder.encode(p.get(0).asText(), StandardCharsets.UTF_8) + "="
                    + URLEncoder.encode(p.get(1).asText(), StandardCharsets.UTF_8));
        }
        return j.toString();
    }

    /** 応答の JSON の中で、{@code keys} に当たる項目の値を {@code "…"} に置き換える（採番・トークンなど）。 */
    public static void mask(JsonNode n, List<String> keys) {
        if (n instanceof ObjectNode o) {
            for (Iterator<Map.Entry<String, JsonNode>> it = o.fields(); it.hasNext();) {
                Map.Entry<String, JsonNode> e = it.next();
                if (keys.contains(e.getKey()) && e.getValue().isValueNode()) e.setValue(Json.F.textNode("…"));
                else mask(e.getValue(), keys);
            }
        } else if (n != null && n.isArray()) {
            for (JsonNode c : n) mask(c, keys);
        }
    }
}
