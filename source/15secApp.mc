import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class _15secApp extends Application.AppBase {

    private var _view as _15secView;

    function initialize() {
        AppBase.initialize();
        _view = new _15secView();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ _view, new _15secDelegate(_view) ];
    }

    // AMOLED only: the display switched between full power, low power
    // (Always On) and off.
    function onDisplayModeChanged() as Void {
        _view.onDisplayModeChanged();
    }

}

function getApp() as _15secApp {
    return Application.getApp() as _15secApp;
}
