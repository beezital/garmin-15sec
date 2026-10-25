import Toybox.Lang;
import Toybox.WatchUi;

class _15secDelegate extends WatchUi.BehaviorDelegate {

    private var _view as _15secView;

    function initialize(view as _15secView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Any button or screen press restarts the full-brightness hold. Returning
    // false lets the press keep its normal meaning, so BACK still exits.
    function onKeyPressed(evt as KeyEvent) as Boolean {
        _view.wake();
        return false;
    }

    function onTap(evt as ClickEvent) as Boolean {
        _view.wake();
        return false;
    }

}
