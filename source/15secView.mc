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
    private const ARC_COLORS = [0xFF8800, 0x00FF22, 0x00CCFF];
    private const ARC_DIM_COLORS = [0x663600, 0x006611, 0x005566];

    // Seconds hand, leading dot first: each trailing dot sits TRAIL_STEP
    // degrees further back (one second), dimmer and smaller. Sizes are
    // radii as a fraction of the screen width.
    private const TRAIL_STEP = 6;
    private const HAND_COLORS = [0xFFFFFF, 0xAAAAAA, 0x666666];
    private const HAND_SIZES = [0.02, 0.016, 0.012];
    private const HAND_FRAME = 0.006;
    private const TICK_COLOR = 0x555555;
    private const TICK_SIZE = 0.01;

    // Tall, narrow digits; plain Roboto where the condensed face is missing.
    private const TIME_FACES = ["RobotoCondensedBold", "RobotoRegular"];

    private var _timer as Timer.Timer?;
    private var _lastSec as Number = -1;
    private var _secondHalf as Boolean = false;
    private var _font as FontType = Graphics.FONT_NUMBER_MILD;

    function initialize() {
        View.initialize();
    }

    // Scale a vector font so the time is as large as possible while its box
    // stays clear of the big next-tick dot on the seconds ring.
    function onLayout(dc as Dc) as Void {
        if (!(Graphics has :getVectorFont)) {
            return;
        }
        var w = dc.getWidth();
        var size = (w * 0.12).toNumber();
        var font = Graphics.getVectorFont({:face => TIME_FACES, :size => size});
        if (font == null) {
            return;
        }
        var dims = dc.getTextDimensions("00:00:00", font);
        var halfDiagonal = Math.sqrt(dims[0] * dims[0] + dims[1] * dims[1]) / 2;
        var inner = dotRingRadius(w) - bigTickRadius(w) - (w * 0.02).toNumber();
        size = (size * inner / halfDiagonal).toNumber();
        font = Graphics.getVectorFont({:face => TIME_FACES, :size => size});
        if (font != null) {
            _font = font;
        }
    }

    // Poll twice a second and redraw when the second changes, so the display
    // never skips or repeats a second.
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

    // The tick after a new second is its second half: if an arc is full on
    // this second (every 5 s), redraw so it flashes back to its thin track.
    function onTick() as Void {
        var sec = System.getClockTime().sec;
        if (sec != _lastSec) {
            _secondHalf = false;
            WatchUi.requestUpdate();
        } else if (!_secondHalf) {
            _secondHalf = true;
            if (sec % 5 == 0) {
                WatchUi.requestUpdate();
            }
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
        var thin = (w * 0.018).toNumber();
        if (thin < 2) {
            thin = 2;
        }
        var radius = arcRadius(w);

        for (var i = 0; i < 3; i++) {
            var start = ARC_STARTS[i] as Number;

            dc.setColor(ARC_DIM_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(thin);
            drawWatchArc(dc, cx, cy, radius, start, start + ARC_SPAN);

            // A full arc shows thick for the first half of its second, then
            // only the thin track, marking the restart before 1/15.
            var fill = fillSeconds(clock.sec, ARC_OFFSETS[i] as Number);
            if (fill < 15 || !_secondHalf) {
                dc.setColor(ARC_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(thick);
                drawWatchArc(dc, cx, cy, radius, start, start + fill * DEG_PER_SEC);
            }
        }

        // Seconds ring: a gray tick every 5 s, run over by a three-dot white
        // hand whose trail fades out behind the leading dot. The tick the hand
        // is heading to is drawn big, in the color of the arc that completes
        // on that second and starts a new cycle right after (:00 orange,
        // :05 green, :10 blue, :15 orange ...); the time uses the same color.
        var ring = dotRingRadius(w);
        var nextTick = (clock.sec + 4) / 5;
        var nextColor = ARC_COLORS[nextTick % 3] as Number;
        dc.setColor(TICK_COLOR, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < 12; k++) {
            drawRingDot(dc, cx, cy, ring, k * 5 * DEG_PER_SEC, w * TICK_SIZE);
        }
        dc.setColor(nextColor, Graphics.COLOR_TRANSPARENT);
        drawRingDot(dc, cx, cy, ring, nextTick * 5 * DEG_PER_SEC, bigTickRadius(w));
        // Draw back to front so the leading dot ends up on top. Each dot sits
        // on a slightly larger black disc, a frame that keeps it readable
        // over the big next tick.
        for (var i = 2; i >= 0; i--) {
            var deg = clock.sec * DEG_PER_SEC - i * TRAIL_STEP;
            var dotRadius = w * (HAND_SIZES[i] as Float);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            drawRingDot(dc, cx, cy, ring, deg, dotRadius + w * HAND_FRAME);
            dc.setColor(HAND_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
            drawRingDot(dc, cx, cy, ring, deg, dotRadius);
        }

        dc.setColor(nextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, _font, formatTime(clock),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Thick stroke sits just inside the bezel; the thin track is centered on it.
    private function arcThickness(w as Number) as Number {
        return (w * 0.06).toNumber();
    }

    private function arcRadius(w as Number) as Number {
        return w / 2 - arcThickness(w) / 2 - (w * 0.01).toNumber();
    }

    // The seconds dots run on a circle just inside the arcs, far enough in
    // that the big next-tick dot keeps a clear gap from them.
    private function dotRingRadius(w as Number) as Number {
        return arcRadius(w) - arcThickness(w) / 2 - (w * 0.065).toNumber();
    }

    // The next tick is twice the size of the hand's leading dot.
    private function bigTickRadius(w as Number) as Float {
        return w * (HAND_SIZES[0] as Float) * 2;
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
