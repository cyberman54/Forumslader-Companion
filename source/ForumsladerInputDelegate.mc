import Toybox.Lang;
import Toybox.WatchUi;

//! Forwards tap/key events to ForumsladerView.onFieldAction().
class ForumsladerInputDelegate extends WatchUi.InputDelegate {
    private var _view as Lang.WeakReference;

    public function initialize(view as ForumsladerView) {
        InputDelegate.initialize();
        _view = view.weak();
    }

    //! @param evt click event
    public function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var view = _view;
        if (view.stillAlive()) {
            (view.get() as ForumsladerView).onFieldAction();
        }
        return true;
    }

    //! @param evt key event
    public function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var view = _view;
        if (view.stillAlive()) {
            (view.get() as ForumsladerView).onFieldAction();
        }
        return true;
    }
}
