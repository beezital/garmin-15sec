import Toybox.Attention;
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
    // degrees further back (one second), dimmer and smaller.
    private const TRAIL_STEP = 6;
    private const HAND_COLORS = [0xFFFFFF, 0xAAAAAA, 0x666666];
    private const TICK_COLOR = 0x555555;
    private const HAND_SIZES = [0.014, 0.011, 0.008];

    // Full brightness is held for HOLD_MS after the app starts or the user
    // wakes the display; AMOLED burn-in protection caps it at about a minute
    // anyway. After that the system's own timeout applies: if Always On is
    // enabled it switches to low power and we draw a dim, burn-in safe time.
    private const HOLD_MS = 60000;
    private const LOW_POWER_COLOR = 0x555555;

    private var _timer as Timer.Timer?;
    private var _lastSec as Number = -1;
    private var _secondHalf as Boolean = false;
    private var _font as FontType = Graphics.FONT_LARGE;
    private var _visible as Boolean = false;
    private var _holding as Boolean = false;
    private var _holdStart as Number = 0;

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

    function onShow() as Void {
        _visible = true;
        _lastSec = -1;
        startTimer();
        wake();
    }

    function onHide() as Void {
        _visible = false;
        stopTimer();
        _holding = false;
    }

    // Called by the app when the system changes the display mode. Leaving full
    // power ends the hold, so the system's dimming is never overridden; coming
    // back to it (wrist raise, button) starts a new hold.
    function onDisplayModeChanged() as Void {
        if (!_visible) {
            return;
        }
        if (displayMode() != System.DISPLAY_MODE_HIGH_POWER) {
            _holding = false;
        } else if (!_holding) {
            wake();
        }
        startTimer();
        WatchUi.requestUpdate();
    }

    // Poll twice a second and redraw when the second changes, so the display
    // never skips or repeats a second. Display off: no timer at all.
    private function startTimer() as Void {
        stopTimer();
        if (displayMode() == System.DISPLAY_MODE_OFF) {
            return;
        }
        var timer = new Timer.Timer();
        timer.start(method(:onTick), 500, true);
        _timer = timer;
    }

    private function stopTimer() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    // The tick after a new second is its second half: at full power, if an arc
    // is full on this second (every 5 s), redraw so it flashes back to thin.
    function onTick() as Void {
        var sec = System.getClockTime().sec;
        if (sec != _lastSec) {
            _secondHalf = false;
            holdBacklight();
            WatchUi.requestUpdate();
        } else if (!_secondHalf) {
            _secondHalf = true;
            if (sec % 5 == 0 && displayMode() == System.DISPLAY_MODE_HIGH_POWER) {
                WatchUi.requestUpdate();
            }
        }
    }

    // Starts a full-brightness hold (app start, button, tap, wrist raise).
    function wake() as Void {
        _holding = true;
        _holdStart = System.getTimer();
        holdBacklight();
    }

    // Renewing the backlight every second keeps the display at full power
    // until HOLD_MS elapses or the system refuses to hold it any longer. It is
    // only renewed while the display is already at full power, never to turn
    // a dimmed or switched-off display back on.
    private function holdBacklight() as Void {
        if (!_holding) {
            return;
        }
        if (System.getTimer() - _holdStart > HOLD_MS || !(Attention has :backlight)
                || displayMode() != System.DISPLAY_MODE_HIGH_POWER) {
            _holding = false;
            return;
        }
        try {
            Attention.backlight(true);
        } catch (e instanceof Attention.BacklightOnTooLongException) {
            _holding = false;
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

        if (displayMode() == System.DISPLAY_MODE_LOW_POWER) {
            drawLowPower(dc, clock, cx, cy);
            return;
        }

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
        // on that second and starts a new cycle right after (:00 red, :05 green,
        // :10 blue, :15 red ...); the time below uses the same color.
        var ring = dotRingRadius(w);
        var nextTick = (clock.sec + 4) / 5;
        var nextColor = ARC_COLORS[nextTick % 3] as Number;
        dc.setColor(TICK_COLOR, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < 12; k++) {
            drawRingDot(dc, cx, cy, ring, k * 5 * DEG_PER_SEC, w * 0.007);
        }
        dc.setColor(nextColor, Graphics.COLOR_TRANSPARENT);
        drawRingDot(dc, cx, cy, ring, nextTick * 5 * DEG_PER_SEC, w * (HAND_SIZES[0] as Float) * 2);
        // Draw back to front so the leading dot ends up on top.
        for (var i = 2; i >= 0; i--) {
            dc.setColor(HAND_COLORS[i] as Number, Graphics.COLOR_TRANSPARENT);
            drawRingDot(dc, cx, cy, ring, clock.sec * DEG_PER_SEC - i * TRAIL_STEP, w * (HAND_SIZES[i] as Float));
        }

        dc.setColor(nextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, _font, formatTime(clock),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // getDisplayMode() only exists on AMOLED/LCD devices; others are always on.
    private function displayMode() as System.DisplayMode {
        if (System has :getDisplayMode) {
            return System.getDisplayMode();
        }
        return System.DISPLAY_MODE_HIGH_POWER;
    }

    // Low power (Always On) screen: only a dim hh:mm:ss, redrawn every second.
    // It moves each minute by more than a stroke width so no pixel stays lit
    // for long, as AMOLED burn-in protection requires.
    private function drawLowPower(dc as Dc, clock as System.ClockTime, cx as Number, cy as Number) as Void {
        var step = dc.getWidth() / 40;
        var dx = (clock.min % 3 - 1) * step;
        var dy = (clock.min / 3 % 3 - 1) * step;
        dc.setColor(LOW_POWER_COLOR, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx + dx, cy + dy, _font, formatTime(clock),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Thick stroke sits just inside the bezel; the thin track is centered on it.
    private function arcThickness(w as Number) as Number {
        return (w * 0.04).toNumber();
    }

    private function arcRadius(w as Number) as Number {
        return w / 2 - arcThickness(w) / 2 - (w * 0.015).toNumber();
    }

    // The seconds dots run on a circle just inside the arcs, far enough in
    // that the big next-tick dot keeps a clear gap from them.
    private function dotRingRadius(w as Number) as Number {
        return arcRadius(w) - arcThickness(w) / 2 - (w * 0.055).toNumber();
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
