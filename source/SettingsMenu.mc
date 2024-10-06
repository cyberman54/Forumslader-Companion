import Toybox.Lang;
import Toybox.WatchUi;

class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        // Generate main menu
        Menu2.initialize(null);
        Menu2.setTitle(WatchUi.loadResource($.Rez.Strings.AppName) as String);
        // Add setup menu items
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuSettings) as String, null, :options, null));
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuDatafields) as String, null, :fields, null));
    }    
}