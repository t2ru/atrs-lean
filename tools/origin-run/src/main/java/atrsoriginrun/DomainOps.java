package atrsoriginrun;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jp.co.ntt.atrs.app.b0.SelectFlightForm;
import jp.co.ntt.atrs.app.b2.PassengerForm;
import jp.co.ntt.atrs.app.b2.ReserveCompleteOutputDto;
import jp.co.ntt.atrs.app.b2.TicketReserveForm;
import jp.co.ntt.atrs.app.common.exception.BadRequestException;
import jp.co.ntt.atrs.domain.common.exception.AtrsBusinessException;
import jp.co.ntt.atrs.domain.model.BoardingClassCd;
import jp.co.ntt.atrs.domain.model.FareType;
import jp.co.ntt.atrs.domain.model.FareTypeCd;
import jp.co.ntt.atrs.domain.model.Flight;
import jp.co.ntt.atrs.domain.model.FlightType;
import jp.co.ntt.atrs.domain.model.Gender;
import jp.co.ntt.atrs.domain.model.Passenger;
import jp.co.ntt.atrs.domain.service.b0.InvalidFlightException;
import jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto;
import jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException;
import jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto;
import jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto;
import org.terasoluna.gfw.common.exception.BusinessException;
import org.terasoluna.gfw.common.message.ResultMessage;
import specpivot.conformance.Json;
import specpivot.conformance.Op;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * ドメイン層の操作の割当（docs/spec/conformance.md の操作名）。入力の形は lean/Tests/ConformanceFare.lean・
 * ConformanceFlightSearch.lean・ConformanceReservation.lean と同じ。結果は {@code expected.ok} と比べる値で、業務例外は
 * {@code AtrsBusinessException} を {@code business}、{@code FlightNotFoundException} を {@code notFound} として
 * {@code {"error": {kind, code}}} の値にする（{@code reservation.*} では {@code args} も付け、{@code BadRequestException}・
 * {@code InvalidFlightException} を {@code invalidRequest} とする）。ほかの例外はケースの失敗。
 */
final class DomainOps {
    private final Domain d;
    private final String db;

    DomainOps(Domain d, String db) {
        this.d = d;
        this.db = db;
    }

    Map<String, Op> ops() {
        Map<String, Op> m = new LinkedHashMap<>();
        m.put("fare.basicFare", c -> {
            JsonNode i = c.get("input");
            return (Json.num(d.shared.calculateBasicFare(i.get("routeBasicFare").intValue(),
                    BoardingClassCd.valueOf(i.get("boardingClassCd").asText()), LocalDate.parse(i.get("depDate").asText()))));
        });
        m.put("fare.fare", c -> {
            JsonNode i = c.get("input");
            return (Json.num(d.shared.calculateFare(i.get("basicFare").intValue(), i.get("discountRate").intValue())));
        });
        m.put("fare.totalFare", c -> {
            JsonNode i = c.get("input");
            List<Passenger> ps = new ArrayList<>();
            for (JsonNode p : i.get("passengers")) ps.add(Domain.passenger(p.get("age").intValue()));
            return (Json.num(d.reserve.calculateTotalFare(d.toFlightList(forms(i.get("flights"))), ps)));
        });
        m.put("flightSearch.validateDepartureDate", c -> {
            JsonNode i = c.get("input");
            d.today(LocalDate.parse(i.get("today").asText()));
            try {
                d.shared.validateDepatureDate(LocalDate.parse(i.get("depDate").asText()));
                return (Json.F.nullNode());
            } catch (BusinessException e) {
                return businessError(e);
            }
        });
        m.put("flightSearch.isAvailableFareType", c -> {
            JsonNode i = c.get("input");
            d.today(LocalDate.parse(i.get("today").asText()));
            FareType ft = d.fareTypeProvider.getFareType(FareTypeCd.valueOf(i.get("fareTypeCd").asText()));
            return (Json.F.booleanNode(d.shared.isAvailableFareType(ft, LocalDate.parse(i.get("depDate").asText()))));
        });
        m.put("flightSearch.searchFlight", c -> {
            JsonNode i = c.get("input");
            replaceFlights(i.get("flights"));
            // Spring の SqlSessionTemplate はトランザクションごとに SqlSession を作るので、ケースをまたいで一次キャッシュを残さない
            d.session.clearCache();
            d.today(LocalDate.parse(i.get("today").asText()));
            JsonNode q = i.get("criteria");
            TicketSearchCriteriaDto dto = new TicketSearchCriteriaDto();
            dto.setFlightType(FlightType.valueOf(q.get("flightType").asText()));
            dto.setDepartureAirportCd(q.get("depAirportCd").asText());
            dto.setArrivalAirportCd(q.get("arrAirportCd").asText());
            dto.setDepDate(LocalDate.parse(q.get("depDate").asText()));
            dto.setBoardingClassCd(BoardingClassCd.valueOf(q.get("boardingClassCd").asText()));
            try {
                ArrayNode out = Json.arr();
                for (FlightVacantInfoDto v : d.search.searchFlight(dto)) out.add(info(v));
                return (out);
            } catch (BusinessException e) {
                return businessError(e);
            }
        });
        m.put("reservation.validateFlightList", c -> {
            JsonNode i = c.get("input");
            resetWorld(i);
            return reservationOutcome(() -> {
                d.shared.validateFlightList(d.toFlightList(selects(i.get("selectFlights"))));
                return Json.F.nullNode();
            });
        });
        m.put("reservation.validateReservation", c -> {
            JsonNode i = c.get("input");
            resetWorld(i);
            TicketReserveForm form = reserveForm(i);
            return reservationOutcome(() -> {
                d.reserveTx.validateReservation(d.createReservation(form, d.toFlightList(form.getSelectFlightFormList())));
                return Json.F.nullNode();
            });
        });
        // 入力検証の後のコントローラの流れ（TicketReserveController の confirm・reserve）
        m.put("reservation.confirm", c -> {
            JsonNode i = c.get("input");
            resetWorld(i);
            TicketReserveForm form = reserveForm(i);
            return reservationOutcome(() -> {
                List<Flight> flights = d.toFlightList(form.getSelectFlightFormList());
                d.reserveHelper.validateFlightList(flights);
                ObjectNode o = Json.obj();
                o.set("totalFare", Json.num(d.reserveHelper.reserveConfirm(form, flights).getTotalFare()));
                return o;
            });
        });
        m.put("reservation.reserve", c -> {
            JsonNode i = c.get("input");
            resetWorld(i);
            TicketReserveForm form = reserveForm(i);
            JsonNode result = reservationOutcome(() -> {
                List<Flight> flights = d.toFlightList(form.getSelectFlightFormList());
                d.reserveHelper.validateFlightList(flights);
                ReserveCompleteOutputDto r = d.reserveHelper.reserve(form, flights);
                ObjectNode o = Json.obj();
                o.put("reserveNo", r.getReserveNo());
                o.put("paymentDate", r.getPaymentDate().toString());
                o.set("totalFare", Json.num(r.getTotalFare()));
                return o;
            });
            ObjectNode out = Json.obj();
            out.set("result", result);
            out.set("world", readWorld(i));
            return out;
        });
        return m;
    }

    interface Body {
        JsonNode run() throws Exception;
    }

    /** {@code reservation.*} の結果: 業務例外は {@code business}（code・args）、不正要求は {@code invalidRequest}。 */
    static JsonNode reservationOutcome(Body b) throws Exception {
        try {
            return b.run();
        } catch (AtrsBusinessException e) {
            ResultMessage msg = e.getResultMessages().getList().get(0);
            ObjectNode err = Json.obj();
            err.put("kind", "business");
            err.put("code", msg.getCode());
            ArrayNode args = err.putArray("args");
            if (msg.getArgs() != null) for (Object a : msg.getArgs()) args.add(String.valueOf(a));
            ObjectNode o = Json.obj();
            o.set("error", err);
            return o;
        } catch (BadRequestException | InvalidFlightException e) {
            ObjectNode err = Json.obj();
            err.put("kind", "invalidRequest");
            ObjectNode o = Json.obj();
            o.set("error", err);
            return o;
        }
    }

    static List<SelectFlightForm> selects(JsonNode selects) {
        List<SelectFlightForm> fs = new ArrayList<>();
        for (JsonNode f : selects) {
            SelectFlightForm s = new SelectFlightForm();
            s.setDepDate(LocalDate.parse(f.get("depDate").asText()));
            s.setFlightName(f.get("flightName").asText());
            s.setBoardingClassCd(BoardingClassCd.valueOf(f.get("boardingClassCd").asText()));
            s.setFareTypeCd(FareTypeCd.valueOf(f.get("fareTypeCd").asText()));
            fs.add(s);
        }
        return fs;
    }

    /** 省略・{@code null} は {@code null}。 */
    static String optText(JsonNode o, String k) {
        JsonNode v = o.get(k);
        return v == null || v.isNull() ? null : v.asText();
    }

    static Integer optInt(JsonNode o, String k) {
        JsonNode v = o.get(k);
        return v == null || v.isNull() ? null : v.intValue();
    }

    static Gender optGender(JsonNode o, String k) {
        String v = optText(o, k);
        return v == null ? null : Gender.valueOf(v);
    }

    /** 入力検証の後の予約入力（TicketReserveForm）。搭乗者欄は入力の並びのまま。 */
    static TicketReserveForm reserveForm(JsonNode i) {
        JsonNode f = i.get("form");
        TicketReserveForm t = new TicketReserveForm();
        t.setRepFamilyName(f.get("repFamilyName").asText());
        t.setRepGivenName(f.get("repGivenName").asText());
        t.setRepAge(f.get("repAge").intValue());
        t.setRepGender(Gender.valueOf(f.get("repGender").asText()));
        t.setRepMembershipNumber(optText(f, "repMembershipNumber"));
        t.setRepTel1(f.get("repTel1").asText());
        t.setRepTel2(f.get("repTel2").asText());
        t.setRepTel3(f.get("repTel3").asText());
        t.setRepMail(f.get("repMail").asText());
        List<PassengerForm> ps = new ArrayList<>();
        for (JsonNode p : f.get("passengers")) {
            PassengerForm pf = new PassengerForm();
            pf.setFamilyName(optText(p, "familyName"));
            pf.setGivenName(optText(p, "givenName"));
            pf.setAge(optInt(p, "age"));
            pf.setGender(optGender(p, "gender"));
            pf.setMembershipNumber(optText(p, "membershipNumber"));
            ps.add(pf);
        }
        t.setPassengerFormList(ps);
        List<SelectFlightForm> sel = selects(i.get("selectFlights"));
        t.setSelectFlightFormList(sel);
        t.setFlightType(sel.size() == 2 ? FlightType.RT : FlightType.OW);
        return t;
    }

    static final String[][] SEQUENCES = {{"reserve", "sq_reservation_1"}, {"reserveFlight", "sq_reserve_flight_1"},
            {"passenger", "sq_passenger_1"}};

    /**
     * ケースの状態から始める: FLIGHT・MEMBER・MEMBER_LOGIN・RESERVATION・RESERVE_FLIGHT・PASSENGER を入力の行だけにし、採番の次の値を
     * 合わせる（省略は 1）。会員のほかの項目は既定の値（lean/Tests/ConformanceReservation.lean の memberRows）。「今日」も決める。
     */
    void resetWorld(JsonNode i) throws SQLException {
        d.today(LocalDate.parse(i.has("today") ? i.get("today").asText() : SeedDb.LOAD_DATE));
        try (Connection c = Pg.connect(db)) {
            c.setAutoCommit(false);
            try (Statement s = c.createStatement()) {
                for (String t : List.of("PASSENGER", "RESERVE_FLIGHT", "RESERVATION", "MEMBER_LOGIN", "MEMBER", "FLIGHT")) {
                    s.execute("DELETE FROM " + t);
                }
            }
            JsonNode flights = i.get("flights");
            if (flights != null && !flights.isNull()) insertFlights(c, flights);
            JsonNode members = i.get("members");
            if (members != null && !members.isNull()) {
                try (PreparedStatement m = c.prepareStatement("INSERT INTO MEMBER (CUSTOMER_NO, KANJI_FAMILY_NAME, KANJI_GIVEN_NAME, "
                        + "KANA_FAMILY_NAME, KANA_GIVEN_NAME, BIRTHDAY, GENDER, TEL, ZIP_CODE, ADDRESS, MAIL, CREDIT_NO, CREDIT_TYPE_CD, "
                        + "CREDIT_TERM) VALUES (?, '', '', ?, ?, DATE '1970-01-01', ?, '', '', '', '', '', 'VIS', '')");
                        PreparedStatement l = c.prepareStatement("INSERT INTO MEMBER_LOGIN (CUSTOMER_NO, PASSWORD, LAST_PASSWORD, "
                                + "LOGIN_DATE_TIME, LOGIN_FLG) VALUES (?, '', NULL, NULL, FALSE)")) {
                    for (JsonNode x : members) {
                        m.setString(1, x.get("membershipNumber").asText());
                        m.setString(2, x.get("kanaFamilyName").asText());
                        m.setString(3, x.get("kanaGivenName").asText());
                        m.setString(4, x.get("gender").asText());
                        m.executeUpdate();
                        l.setString(1, x.get("membershipNumber").asText());
                        l.executeUpdate();
                    }
                }
            }
            JsonNode seqs = i.get("sequences");
            for (String[] q : SEQUENCES) {
                long next = seqs != null && seqs.has(q[0]) ? seqs.get(q[0]).longValue() : 1;
                try (PreparedStatement p = c.prepareStatement("SELECT setval(?, ?, ?)")) {
                    p.setString(1, q[1]);
                    // setval(seq, v, true) の次は v + 1、setval(seq, 1, false) の次は 1
                    p.setLong(2, next <= 1 ? 1 : next - 1);
                    p.setBoolean(3, next > 1);
                    p.executeQuery().close();
                }
            }
            c.commit();
        }
    }

    /** 実行後の状態（ConformanceReservation.lean の srcWorldJson と同じ形）。フライトは入力の並び、ほかは番号の順。 */
    ObjectNode readWorld(JsonNode i) throws SQLException {
        ObjectNode w = Json.obj();
        try (Connection c = Pg.connect(db)) {
            ArrayNode fs = w.putArray("flights");
            try (PreparedStatement p = c.prepareStatement("SELECT VACANT_NUM FROM FLIGHT WHERE DEPARTURE_DATE = ? AND FLIGHT_NAME = ? "
                    + "AND BOARDING_CLASS_CD = ? AND FARE_TYPE_CD = ?")) {
                JsonNode flights = i.get("flights");
                if (flights != null && !flights.isNull()) {
                    for (JsonNode f : flights) {
                        p.setObject(1, LocalDate.parse(f.get("departureDate").asText()));
                        p.setString(2, f.get("flightName").asText());
                        p.setString(3, f.get("boardingClassCd").asText());
                        p.setString(4, f.get("fareTypeCd").asText());
                        try (ResultSet rs = p.executeQuery()) {
                            if (!rs.next()) throw new IllegalStateException("flight row disappeared: " + f);
                            ObjectNode o = fs.addObject();
                            o.put("departureDate", f.get("departureDate").asText());
                            o.put("flightName", f.get("flightName").asText());
                            o.put("boardingClassCd", f.get("boardingClassCd").asText());
                            o.put("fareTypeCd", f.get("fareTypeCd").asText());
                            o.set("vacantNum", Json.num(rs.getInt(1)));
                        }
                    }
                }
            }
            ArrayNode rs = w.putArray("reservations");
            try (Statement s = c.createStatement();
                    ResultSet r = s.executeQuery("SELECT RESERVE_NO, RESERVE_DATE, TOTAL_FARE, REP_FAMILY_NAME, REP_GIVEN_NAME, REP_AGE, "
                            + "REP_GENDER, REP_TEL, REP_MAIL, REP_CUSTOMER_NO FROM RESERVATION ORDER BY RESERVE_NO COLLATE \"C\"")) {
                while (r.next()) {
                    ObjectNode o = rs.addObject();
                    o.put("reserveNo", r.getString(1));
                    o.put("reserveDate", r.getObject(2, LocalDate.class).toString());
                    o.set("totalFare", Json.num(r.getInt(3)));
                    o.put("repFamilyName", r.getString(4));
                    o.put("repGivenName", r.getString(5));
                    o.set("repAge", Json.num(r.getInt(6)));
                    o.put("repGender", r.getString(7));
                    o.put("repTel", r.getString(8));
                    o.put("repMail", r.getString(9));
                    o.put("repMembershipNumber", r.getString(10));
                    o.set("reserveFlights", reserveFlights(c, r.getString(1)));
                }
            }
            ObjectNode seq = w.putObject("sequences");
            for (String[] q : SEQUENCES) {
                try (Statement s = c.createStatement(); ResultSet r = s.executeQuery("SELECT last_value, is_called FROM " + q[1])) {
                    r.next();
                    seq.set(q[0], Json.num(r.getLong(1) + (r.getBoolean(2) ? 1 : 0)));
                }
            }
        }
        return w;
    }

    static ArrayNode reserveFlights(Connection c, String reserveNo) throws SQLException {
        ArrayNode a = Json.arr();
        try (PreparedStatement p = c.prepareStatement("SELECT RESERVE_FLIGHT_NO, DEPARTURE_DATE, FLIGHT_NAME, BOARDING_CLASS_CD, "
                + "FARE_TYPE_CD FROM RESERVE_FLIGHT WHERE RESERVE_NO = ? ORDER BY RESERVE_FLIGHT_NO")) {
            p.setString(1, reserveNo);
            try (ResultSet r = p.executeQuery()) {
                while (r.next()) {
                    ObjectNode o = a.addObject();
                    o.set("reserveFlightNo", Json.num(r.getInt(1)));
                    o.put("departureDate", r.getObject(2, LocalDate.class).toString());
                    o.put("flightName", r.getString(3));
                    o.put("boardingClassCd", r.getString(4));
                    o.put("fareTypeCd", r.getString(5));
                    o.set("passengers", passengers(c, r.getInt(1)));
                }
            }
        }
        return a;
    }

    static ArrayNode passengers(Connection c, int reserveFlightNo) throws SQLException {
        ArrayNode a = Json.arr();
        try (PreparedStatement p = c.prepareStatement("SELECT PASSENGER_NO, FAMILY_NAME, GIVEN_NAME, AGE, GENDER, CUSTOMER_NO "
                + "FROM PASSENGER WHERE RESERVE_FLIGHT_NO = ? ORDER BY PASSENGER_NO")) {
            p.setInt(1, reserveFlightNo);
            try (ResultSet r = p.executeQuery()) {
                while (r.next()) {
                    ObjectNode o = a.addObject();
                    o.set("passengerNo", Json.num(r.getInt(1)));
                    o.put("familyName", r.getString(2));
                    o.put("givenName", r.getString(3));
                    o.set("age", Json.num(r.getInt(4)));
                    o.put("gender", r.getString(5));
                    o.put("membershipNumber", r.getString(6));
                }
            }
        }
        return a;
    }

    static List<SelectFlightForm> forms(JsonNode flights) {
        List<SelectFlightForm> fs = new ArrayList<>();
        for (JsonNode f : flights) {
            SelectFlightForm s = new SelectFlightForm();
            s.setDepDate(LocalDate.parse(f.get("departureDate").asText()));
            s.setFlightName(f.get("flightName").asText());
            s.setBoardingClassCd(BoardingClassCd.valueOf(f.get("boardingClassCd").asText()));
            s.setFareTypeCd(FareTypeCd.valueOf(f.get("fareTypeCd").asText()));
            fs.add(s);
        }
        return fs;
    }

    static ObjectNode businessError(BusinessException e) {
        String code = e.getResultMessages().getList().get(0).getCode();
        return Json.error(e instanceof FlightNotFoundException ? "notFound" : "business", code);
    }

    static ObjectNode info(FlightVacantInfoDto v) {
        ObjectNode o = Json.obj();
        o.put("flightName", v.getFlightName());
        o.put("depAirportName", v.getDepAirportName());
        o.put("arrAirportName", v.getArrAirportName());
        o.put("depTime", v.getDepTime());
        o.put("arrTime", v.getArrTime());
        o.put("depDate", v.getDepDate());
        o.put("boardingClassCd", v.getBoardingClassCd().name());
        ArrayNode fts = Json.arr();
        for (Map.Entry<String, FareTypeVacantInfoDto> e : v.getFareTypes().entrySet()) {
            ObjectNode f = Json.obj();
            f.put("fareTypeCd", e.getKey());
            f.put("fareTypeName", e.getValue().getFareTypeName());
            f.put("fare", e.getValue().getFare());
            f.set("vacantNum", Json.num(e.getValue().getVacantNum()));
            fts.add(f);
        }
        o.set("fareTypes", fts);
        return o;
    }

    /** FLIGHT 表を、ケースの {@code flights} の行だけにする（FLIGHT を参照する予約の表も空にする）。 */
    void replaceFlights(JsonNode flights) throws SQLException {
        try (Connection c = Pg.connect(db)) {
            c.setAutoCommit(false);
            try (Statement s = c.createStatement()) {
                for (String t : List.of("PASSENGER", "RESERVE_FLIGHT", "RESERVATION", "FLIGHT")) s.execute("DELETE FROM " + t);
            }
            insertFlights(c, flights);
            c.commit();
        }
    }

    static void insertFlights(Connection c, JsonNode flights) throws SQLException {
        try (PreparedStatement p = c.prepareStatement(
                "INSERT INTO FLIGHT (DEPARTURE_DATE, FLIGHT_NAME, BOARDING_CLASS_CD, FARE_TYPE_CD, VACANT_NUM) VALUES (?, ?, ?, ?, ?)")) {
            for (JsonNode f : flights) {
                p.setObject(1, LocalDate.parse(f.get("departureDate").asText()));
                p.setString(2, f.get("flightName").asText());
                p.setString(3, f.get("boardingClassCd").asText());
                p.setString(4, f.get("fareTypeCd").asText());
                p.setInt(5, f.get("vacantNum").intValue());
                p.addBatch();
            }
            p.executeBatch();
        }
    }
}
