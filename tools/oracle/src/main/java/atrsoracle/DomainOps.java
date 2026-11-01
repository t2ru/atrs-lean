package atrsoracle;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import jp.co.ntt.atrs.app.b0.SelectFlightForm;
import jp.co.ntt.atrs.domain.model.BoardingClassCd;
import jp.co.ntt.atrs.domain.model.FareType;
import jp.co.ntt.atrs.domain.model.FareTypeCd;
import jp.co.ntt.atrs.domain.model.FlightType;
import jp.co.ntt.atrs.domain.model.Passenger;
import jp.co.ntt.atrs.domain.service.b1.FareTypeVacantInfoDto;
import jp.co.ntt.atrs.domain.service.b1.FlightNotFoundException;
import jp.co.ntt.atrs.domain.service.b1.FlightVacantInfoDto;
import jp.co.ntt.atrs.domain.service.b1.TicketSearchCriteriaDto;
import org.terasoluna.gfw.common.exception.BusinessException;
import specpivot.conformance.Json;
import specpivot.conformance.Op;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * ドメイン層の操作の割当（docs/spec/conformance.md の操作名）。入力の形は lean/Tests/ConformanceFare.lean・
 * ConformanceFlightSearch.lean と同じ。結果は {@code expected.ok} と比べる値で、業務例外は {@code AtrsBusinessException} を
 * {@code business}、{@code FlightNotFoundException} を {@code notFound} として {@code {"error": {kind, code}}} の値にする。
 * ほかの例外はケースの失敗。
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
        return m;
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

    /** FLIGHT 表を、ケースの {@code flights} の行だけにする。 */
    void replaceFlights(JsonNode flights) throws SQLException {
        try (Connection c = Pg.connect(db)) {
            c.setAutoCommit(false);
            try (Statement s = c.createStatement()) {
                s.execute("DELETE FROM FLIGHT");
            }
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
            c.commit();
        }
    }
}
