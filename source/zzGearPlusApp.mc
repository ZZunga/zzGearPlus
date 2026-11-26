using Toybox.Application;
using Toybox.WatchUi;

class zzGearPlusApp extends Application.AppBase {

    hidden var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        mView = new zzGearPlusView();
        return [ mView ];
    }

    function onSettingsChanged() {
        Config.invalidate();
        if (mView != null) {
            mView.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }

    function onStop(state) {
        if (mView != null) {
            mView.persist();
        }
    }
}
