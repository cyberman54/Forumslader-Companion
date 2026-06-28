import Toybox.Lang;
import Toybox.WatchUi;

//! InputDelegate für das Forumslader-Datenfeld.
//! Leitet Benutzerinteraktionen (Antippen auf Touch-Geräten, Tastendruck auf Edge-Geräten)
//! an die Ansicht weiter. Die eigentliche Aktion ist in ForumsladerView.onFieldAction() definiert.
class ForumsladerInputDelegate extends WatchUi.InputDelegate {
    private var _view as Lang.WeakReference;

    public function initialize(view as ForumsladerView) {
        InputDelegate.initialize();
        _view = view.weak();
    }

    //! Touch-Geräte: Antippen des Datenfelds
    public function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var view = _view;
        if (view.stillAlive()) {
            (view.get() as ForumsladerView).onFieldAction();
        }
        return true;
    }

    //! Tastengeräte (z. B. Garmin Edge): beliebige Taste im Datenfeld
    public function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var view = _view;
        if (view.stillAlive()) {
            (view.get() as ForumsladerView).onFieldAction();
        }
        return true;
    }
}
