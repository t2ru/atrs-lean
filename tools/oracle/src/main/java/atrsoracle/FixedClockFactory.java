package atrsoracle;

import org.terasoluna.gfw.common.time.ClockFactory;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * 原典の {@code dateFactory}（{@code DefaultClockFactory}）の差し替え。{@code fixed}・{@code tick} とも、決めた時刻で止めた時計を返す
 * （ハーネスの対象外とした構成。docs/spec/assurance.md）。時刻は Asia/Tokyo の現地時刻で与える（D-023。オラクルは JST で実行する）。
 */
final class FixedClockFactory implements ClockFactory {
    static final ZoneId JST = ZoneId.of("Asia/Tokyo");
    private final Instant instant;

    FixedClockFactory(LocalDateTime jst) {
        this.instant = jst.atZone(JST).toInstant();
    }

    @Override
    public Clock fixed(ZoneId zone) { return Clock.fixed(instant, zone); }

    @Override
    public Clock tick(ZoneId zone) { return Clock.fixed(instant, zone); }
}
