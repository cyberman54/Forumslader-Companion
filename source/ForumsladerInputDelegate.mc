import Toybox.Lang;
import Toybox.WatchUi;

//! InputDelegate for the Forumslader data field.
//! Forwards user interactions (tap on touch devices, key press on Edge devices)
//! to the view. The actual action is defined in ForumsladerView.onFieldAction().
class ForumsladerInputDelegate extends WatchUi.InputDelegate {
    private var _view as Lang.WeakReference;

    public function initialize(view as ForumsladerView) {
        InputDelegate.initialize();
        _view = view.weak();
    }

    //! Touch devices: tap on the data field
    public function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var view = _view;
        if (view.stillAlive()) {
            (view.get() as ForumsladerView).onFieldAction();
        }
        return true;
    }

    //! Key devices (e.g. Garmin Edge): any key press in the data field
    public function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var view = _view;
        if (view.stillAlive()) {
            (view.get() as ForumsladerView).onFieldAction();
        }
        return true;
    }
}
