package atrsoriginrun;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import specpivot.conformance.Json;
import specpivot.conformance.Runner;
import specpivot.conformance.http.HttpCapture;
import specpivot.conformance.http.WebappServer;

import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * HTTP レベルの原典実行（backlog f18c）。Spring を起動した原典（組み込み Tomcat に、原典の web.xml のままの webapp を載せる）に
 * 要求を送り、応答をベクタの形で採取して {@code tools/origin-run/http/*.json} に書く（{@code SourceModel.Http} ができるまで
 * {@code conformance/} の外に置く。backlog 4e0e・a89e で移す）。
 *
 * <p>ケースは要求の列（{@code input.requests}）で、同じ HTTP セッション（Cookie）で順に送る。要求の値 {@code "{{_csrf}}"} は、
 * 直前の応答の HTML の CSRF トークンで置き換える。DB を観測するケースは、要求の前後の表の行（{@code observe}）を期待値に含める。</p>
 */
final class HttpOriginRun {
    private HttpOriginRun() {}

    static final String DB = "atrs_origin_run_http";
    static final String CONTEXT = "/atrs";
    /** 原典の時計（{@code dateFactory}）の時刻。投入日と違う日にして、ログイン日時の更新を観測できるようにする。 */
    static final String NOW = "2026-11-03T10:00:00";
    static final Pattern CSRF = Pattern.compile("name=\"_csrf\"\\s+value=\"([^\"]+)\"");
    /** 採取した値のうち、実行ごとに変わらないが読みにくいので伏せる項目（なし）。 */
    static final int FLAT = 4;

    static void run(Path repo, boolean write, List<String> problems) throws Exception {
        SeedDb.load(repo, DB, SeedDb.FULL);
        System.setProperty("originrun.now", NOW);
        System.setProperty(OriginRunContextInitializer.PREFIX + "database.url", Pg.url(DB));
        System.setProperty(OriginRunContextInitializer.PREFIX + "database.username", Pg.props().getProperty("user"));
        System.setProperty(OriginRunContextInitializer.PREFIX + "database.password", Pg.props().getProperty("password", ""));
        // 作業ディレクトリ（java_origin_run.sh の一時ディレクトリ）の下
        System.setProperty(OriginRunContextInitializer.PREFIX + "report.dir", Files.createDirectories(Path.of("report")).toAbsolutePath().toString());
        Path docBase = Upstream.built(repo).resolve("atrs-web/src/main/webapp");
        try (WebappServer server = WebappServer.start(docBase, CONTEXT,
                Map.of("globalInitializerClasses", OriginRunContextInitializer.class.getName()))) {
            for (ObjectNode doc : List.of(ticket(repo), login(repo))) {
                for (JsonNode c : doc.withArray("cases")) {
                    ((ObjectNode) c).set("expected", Json.ok(exchange(server, c)));
                    ((ObjectNode) c).put("source", Generate.SOURCE);
                }
                String file = doc.remove("file").asText();
                String p = Runner.saveOrCompare(repo.resolve("tools/origin-run/http").resolve(file), doc, FLAT, write);
                if (p != null) problems.add(p);
                System.out.println("  " + (write ? "wrote" : (p == null ? "ok   " : "FAIL ")) + " tools/origin-run/http/" + file + " ("
                        + doc.get("cases").size() + " cases)");
                findings(doc);
            }
        }
    }

    static ObjectNode doc(Path repo, String file, String operation, String specRef, String note) {
        ObjectNode d = Runner.header(operation, Json.F.nullNode(), specRef, Upstream.version(repo), null,
                note + " SourceModel.Http はまだ無いので modelDef は null（backlog a89e・4e0e で conformance/source-model/http/ へ移す）。"
                        + "Java の原典実行で採取した（tools/origin-run の HttpOriginRun。手で編集しない）。");
        d.put("file", file);
        return d;
    }

    static ObjectNode request(String method, String path) {
        ObjectNode r = Json.obj();
        r.put("method", method);
        r.put("path", path);
        return r;
    }

    static ArrayNode pair(String k, String v) {
        ArrayNode a = Json.arr();
        a.add(k);
        a.add(v);
        return a;
    }

    static ObjectNode testCase(String id, String description, ArrayNode requests, String observe) {
        ObjectNode c = Json.obj();
        c.put("id", id);
        c.put("description", description);
        c.put("now", NOW);
        ObjectNode in = c.putObject("input");
        in.set("requests", requests);
        if (observe != null) in.put("observe", observe);
        return c;
    }

    // ---------------------------------------------------------------- REST: POST /api/v1/ticket

    static ObjectNode ticketBody(String depDate) {
        ObjectNode b = Json.obj();
        b.put("repMembershipNumber", "0000000001");
        b.put("repFamilyName", "デンデン");
        b.put("repGivenName", "ハナコ");
        b.put("repAge", "44");
        b.put("repGender", "F");
        b.put("repTel1", "111");
        b.put("repTel2", "1111");
        b.put("repTel3", "1111");
        b.put("repMail", "xxxxxx@ntt.co.jp");
        b.put("flightType", "OW");
        ObjectNode f = b.putArray("selectFlightResourceList").addObject();
        f.put("flightName", "NTT001");
        f.put("depDate", depDate);
        f.put("boardingClassCd", "N");
        f.put("fareTypeCd", "OW");
        ObjectNode p = b.putArray("passengerResourceList").addObject();
        p.put("membershipNumber", "0000000001");
        p.put("familyName", "デンデン");
        p.put("givenName", "ハナコ");
        p.put("age", "44");
        p.put("gender", "F");
        return b;
    }

    static ObjectNode ticket(Path repo) {
        ObjectNode d = doc(repo, "postTicket.json", "http.postTicket", "lean/Spec/Http.lean#rest-apiapiv1",
                "REST の日付の JSON 表現の確認（Spec.Http の TODO。本文は atrs-selenium の RestAPITest に倣う）。");
        ArrayNode cases = d.withArray("cases");
        ArrayNode r1 = Json.arr();
        r1.add(request("POST", "/api/v1/ticket").set("json", ticketBody("2026-11-04")));
        cases.add(testCase("postTicket-isoDate", "要求の搭乗日 depDate を \"yyyy-MM-dd\" で送ると予約され、応答の LocalDate の項目"
                + "（paymentDate・selectFlightResourceList[].depDate）も \"yyyy-MM-dd\" になる", r1, null));
        ArrayNode r2 = Json.arr();
        r2.add(request("POST", "/api/v1/ticket").set("json", ticketBody("2026/11/04")));
        cases.add(testCase("postTicket-slashDate", "SelectFlightResource.depDate の @DateTimeFormat(pattern = \"yyyy/MM/dd\") は Jackson の"
                + "変換に効かないので、\"yyyy/MM/dd\" の搭乗日は読めない", r2, null));
        return d;
    }

    // ---------------------------------------------------------------- 画面ログイン

    static ObjectNode login(Path repo) {
        ObjectNode d = doc(repo, "login.json", "http.login", "lean/Spec/Auth.lean#ログインlogin",
                "画面ログインで MEMBER_LOGIN の LOGIN_DATE_TIME・LOGIN_FLG が更新されるかの確認（Spec.Authentication の TODO、D-028）。");
        ArrayNode cases = d.withArray("cases");
        for (String[] k : new String[][] {{"login-success", "aaaaa11111", "正しいパスワードでの画面ログイン"},
                {"login-wrongPassword", "aaaaa00000", "誤ったパスワード（過去のパスワード）での画面ログイン"}}) {
            ArrayNode rs = Json.arr();
            rs.add(request("GET", "/auth/login"));
            ObjectNode post = request("POST", "/auth/dologin");
            ArrayNode form = post.putArray("form");
            form.add(pair("membershipNumber", "0000000001"));
            form.add(pair("password", k[1]));
            form.add(pair("_csrf", "{{_csrf}}"));
            rs.add(post);
            cases.add(testCase(k[0], k[2] + "（会員 0000000001）。前後の MEMBER_LOGIN の行を観測する", rs, "memberLogin:0000000001"));
        }
        ArrayNode rs = Json.arr();
        ObjectNode get = request("GET", "/api/v1/flight");
        ArrayNode q = get.putArray("query");
        q.add(pair("flightType", "OW"));
        q.add(pair("depAirportCd", "HND"));
        q.add(pair("arrAirportCd", "ITM"));
        q.add(pair("depDate", "2026/11/04"));
        q.add(pair("boardingClassCd", "N"));
        ArrayNode h = get.putArray("headers");
        h.add(pair("Authorization", "Basic " + java.util.Base64.getEncoder().encodeToString(
                "0000000001:aaaaa11111".getBytes(java.nio.charset.StandardCharsets.UTF_8))));
        rs.add(get);
        cases.add(testCase("login-restBasic", "REST の HTTP Basic 認証（正しい資格情報。会員 0000000001）。前後の MEMBER_LOGIN の行を観測する"
                + "（画面ログインとの比較のため）", rs, "memberLogin:0000000001"));
        return d;
    }

    // ---------------------------------------------------------------- 実行

    static JsonNode exchange(WebappServer server, JsonNode c) throws Exception {
        HttpCapture cap = new HttpCapture(server.baseUrl());
        JsonNode in = c.get("input");
        String observe = in.path("observe").asText(null);
        ObjectNode out = Json.obj();
        if (observe != null) out.set("before", observe(observe));
        ArrayNode responses = out.putArray("responses");
        String csrf = null;
        for (JsonNode r : in.get("requests")) {
            ObjectNode req = r.deepCopy();
            if (req.has("form")) {
                for (JsonNode p : req.get("form")) {
                    if (p.get(1).asText().equals("{{_csrf}}")) {
                        if (csrf == null) throw new IllegalStateException("no CSRF token in the previous response");
                        ((ArrayNode) p).set(1, Json.F.textNode(csrf));
                    }
                }
            }
            HttpCapture.Response resp = cap.send(req);
            ObjectNode o = resp.contentType().contains("json") ? HttpCapture.withJsonBody(resp) : resp.json().deepCopy();
            // 空席照会の応答は長いので、件数だけを残す（この採取の目的は認証の観測）
            if (req.path("path").asText().equals("/api/v1/flight") && o.path("json").isArray()) {
                o.put("jsonArraySize", o.get("json").size());
                o.remove("json");
            }
            if (resp.contentType().startsWith("text/html")) {
                Matcher m = CSRF.matcher(resp.body());
                csrf = m.find() ? m.group(1) : null;
                o.put("htmlHasCsrfToken", csrf != null);
            }
            responses.add(o);
        }
        if (observe != null) out.set("after", observe(observe));
        return out;
    }

    /** {@code memberLogin:<会員番号>}: MEMBER_LOGIN の LOGIN_DATE_TIME・LOGIN_FLG。 */
    static JsonNode observe(String what) throws Exception {
        String[] k = what.split(":", 2);
        if (!k[0].equals("memberLogin")) throw new IllegalArgumentException(what);
        try (Connection c = Pg.connect(DB);
                PreparedStatement p = c.prepareStatement("SELECT login_date_time, login_flg FROM member_login WHERE customer_no = ?")) {
            p.setString(1, k[1]);
            try (ResultSet rs = p.executeQuery()) {
                ObjectNode o = Json.obj();
                if (!rs.next()) return Json.F.nullNode();
                Timestamp t = rs.getTimestamp(1);
                o.put("loginDateTime", t == null ? null : rs.getObject(1, java.time.LocalDateTime.class).toString());
                o.put("loginFlg", rs.getBoolean(2));
                return o;
            }
        }
    }

    /** 採取結果から、文書の TODO を解く観測を標準出力に要約する。 */
    static void findings(ObjectNode doc) {
        for (JsonNode c : doc.get("cases")) {
            JsonNode e = c.get("expected").get("ok");
            if (e.has("before")) {
                System.out.println("    " + c.get("id").asText() + ": MEMBER_LOGIN " + e.get("before") + " -> " + e.get("after"));
            }
            for (JsonNode r : e.get("responses")) {
                System.out.println("    " + c.get("id").asText() + ": " + r.get("status") + " " + r.get("headers")
                        + (r.has("json") ? " " + r.get("json") : ""));
            }
        }
    }
}
