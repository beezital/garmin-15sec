import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class _15secView extends WatchUi.View {

    // Each arc spans 90 degrees = 15 seconds, so 6 degrees per second.
    // Angles are "watch" angles: 0 at 12 o'clock, increasing clockwise.
    private const ARC_SPAN = 90;
    private const DEG_PER_SEC = 6;

    // Per arc: start angle, seconds offset, bright color, dim color.
    private const ARC_STARTS = [0, 120, 240];
    private const ARC_OFFSETS = [0, 5, 10];
    private const ARC_COLORS = [0xFF0000, 0x00FF22, 0x00CCFF];
    private const ARC_DIM_COLORS = [0x660000, 0x006611, 0x005566];

    // Seconds hand, leading dot first: each trailing dot sits TRAIL_STEP
    // degrees further back (one second), dimmer and smaller.
    private const TRAIL_STEP = 6;
    private const HAND_COLORS = [0xFFFFFF, 0xAAAAAA, 0x666666];
    private const HAND_SIZES = [0.014, 0.011, 0.008];

    private var _timer as Timer.Timer?;
    private var _lastSec as Number = -1;
    private var _font as FontType = Graphics.FONT_LARGE;

    function initialize() {
        View.initialize();
    }

    // The built-in number fonts jump from MILD straight to the much smaller LARGE,
    // so scale a vector font until the time fills ~60% of the dot ring instead.
    function onLayout(dc as Dc) as Void {
        if (!(Graphics has :getVectorFont)) {
            return;
        }
        var targetWidth = 2 * dotRingRadius(dc.getWidth()) * 0.6;
        var size = (dc.getWidth() * 0.12).toNumber();
        var font = Graphics.getVectorFont({:face => "RobotoRegular", :size => size});
        if (font == null) {
            return;
        }
        size = (size * targetWidth / dc.getTextWidthInPixels("00:00:00", font)).toNumber();
        font = Graphics.getVectorFont({:face => "RobotoRegular", :size => size});
        if (font != null) {
            _font = font;
        }
    }

    // Poll twice a second and redraw only when the second changes,
    // so the display never skips or repeats a second.
    function onShow() as Void {
        _lastSec = -1;
        _timer = new Timer.Timer();
        _timer.start(method(:onTick), 500, true);
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        if (System.getClockTime().sec != _lastSec) {
            WatchUi.requestUpdate();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var clock = System.getClockTime();
        _lastSec = clock.sec;

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var thick = arcThickness(w);
        var thin = (w * 0.012).toNumber();
        if (thin < 2) {
            thin = 2;
        }
        var radius = arcRadius(w);

        for (var i = 0; i < 3; i++) {
            var start = ARC_STARTS[i] as Number;

            dc.setColor(ARC_DIM_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(thin);
            drawWatchArc(dc, cx, cy, radius, start, start + ARC_SPAN);

            dc.setColor(ARC_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(thick);
            drawWatchArc(dc, cx, cy, radius, start, start + fillSeconds(clock.sec, ARC_OFFSETS[i] as Number) * DEG_PER_SEC);
        }

        // Seconds ring: a tick every 5 s, run over by a three-dot white hand
        // whose trail fades out behind the leading dot. Each tick takes the
        // color of the arc that completes its cycle on that second
        // (:00 red, :05 green, :10 blue, :15 red ...), so four of each.
        var ring = dotRingRadius(w);
        for (var k = 0; k < 12; k++) {
            dc.setColor(ARC_COLORS[k % 3] as Number, Graphics.COLOR_TRANSPARENT);
            drawRingDot(dc, cx, cy, ring, k * 5 * DEG_PER_SEC, w * 0.007);
        }
        // Draw back to front so the leading dot ends up on top.
        for (var i = 2; i >= 0; i--) {
            dc.setColor(HAND_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
            drawRingDot(dc, cx, cy, ring, clock.sec * DEG_PER_SEC - i * TRAIL_STEP, w * (HAND_SIZES[i] as Float));
        }

        // The time takes the color of the tick the hand is heading to, i.e. the
        // arc that completes next and starts a new cycle right after.
        var nextTick = (clock.sec + 4) / 5;
        dc.setColor(ARC_COLORS[nextTick % 3] as Number, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, _font, formatTime(clock),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Thick stroke sits just inside the bezel; the thin track is centered on it.
    private function arcThickness(w as Number) as Number {
        return (w * 0.04).toNumber();
    }

    private function arcRadius(w as Number) as Number {
        return w / 2 - arcThickness(w) / 2 - (w * 0.015).toNumber();
    }

    // The seconds dots run on a circle just inside the arcs.
    private function dotRingRadius(w as Number) as Number {
        return arcRadius(w) - arcThickness(w) / 2 - (w * 0.04).toNumber();
    }

    // Draws a dot on a circle at a watch angle (0 = 12 o'clock, clockwise).
    private function drawRingDot(dc as Dc, cx as Number, cy as Number, r as Number,
            deg as Number, dotRadius as Float) as Void {
        var rad = Math.toRadians(deg);
        dc.fillCircle(Math.round(cx + r * Math.sin(rad)), Math.round(cy - r * Math.cos(rad)), dotRadius);
    }

    // Seconds of the 15 s cycle elapsed for an arc, in 1..15:
    // a remainder of 0 means the cycle just completed, so the arc is full.
    private function fillSeconds(sec as Number, offset as Number) as Number {
        var v = (sec - offset + 15) % 15;
        return v == 0 ? 15 : v;
    }

    // Draws an arc clockwise between two watch angles (0 = 12 o'clock, clockwise).
    // Garmin angles start at 3 o'clock and grow counter-clockwise, hence 90 - a.
    private function drawWatchArc(dc as Dc, cx as Number, cy as Number, r as Number,
            fromDeg as Number, toDeg as Number) as Void {
        dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, (450 - fromDeg) % 360, (450 - toDeg) % 360);
    }

    private function formatTime(clock as System.ClockTime) as String {
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return Lang.format("$1$:$2$:$3$", [
            hour.format("%02d"), clock.min.format("%02d"), clock.sec.format("%02d")
        ]);
    }

}
