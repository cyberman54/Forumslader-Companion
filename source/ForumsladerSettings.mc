import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Properties;
//import Toybox.Graphics;

(:SettingsMenu)
//! This is the settings main menu called by getSettingsView of the application
class SettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        // Generate main setup menu
        Menu2.initialize(null);
        Menu2.setTitle(WatchUi.loadResource($.Rez.Strings.AppName) + " v" + Application.loadResource($.Rez.Strings.AppVersion) as String);
        // Add setup menu items
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuSettings) as String, null, :options, null));
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuDatafields) as String, null, :fields, null));
    }    
}

(:SettingsMenu)
//! This is the menu input delegate for the settings main menu of the application
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    //! Constructor
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    //! Handle an item being selected
    //! @param item The selected menu item
    public function onSelect(item as MenuItem) as Void {
        var id = item.getId() as String;
        if (id == :options) {
            // When the options menu item is selected, push a new menu with toggle switches
            var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource($.Rez.Strings.MenuSettings) as String});
            menu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource($.Rez.Strings.SelectCapacityMethod) as String, 
                null, :battCalc, $.UserSettings[$.BattCalcMethod] as Boolean, null));
            menu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource($.Rez.Strings.SelectFitLogging) as String, 
                null, :fitLog, $.UserSettings[$.FitLogging] as Boolean, null));
            menu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource($.Rez.Strings.SelectRotateFields) as String, 
                null, :fieldRoll, $.UserSettings[$.RotateFields] as Boolean, null));
            WatchUi.pushView(menu, new $.SubMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :fields) {
            // When the fields menu item is selected, push a new menu with picklists generated by custom icons
            var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource($.Rez.Strings.MenuDatafields) as String});
            var drawable1 = new $.PickList($.DisplayField1);
            var drawable2 = new $.PickList($.DisplayField2);
            var drawable3 = new $.PickList($.DisplayField3);
            var drawable4 = new $.PickList($.DisplayField4);
            menu.addItem(new WatchUi.IconMenuItem(drawable1.getString(), null, $.DisplayField1, drawable1, null));
            menu.addItem(new WatchUi.IconMenuItem(drawable2.getString(), null, $.DisplayField2, drawable2, null));
            menu.addItem(new WatchUi.IconMenuItem(drawable3.getString(), null, $.DisplayField3, drawable3, null));
            menu.addItem(new WatchUi.IconMenuItem(drawable4.getString(), null, $.DisplayField4, drawable4, null));
            WatchUi.pushView(menu, new $.SubMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.requestUpdate();
        }
    }

    //! Handle the back key being pressed
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:SettingsMenu)
//! This is the menu input delegate shared by all the basic sub-menus in the application
class SubMenuDelegate extends WatchUi.Menu2InputDelegate {

    //! Constructor
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    //! Handle an item being selected
    //! @param item The selected menu item
    public function onSelect(item as MenuItem) as Void {
        // for IconMenuItems, change to the next icon state and save setting
        if (item instanceof WatchUi.IconMenuItem) {
            var thisItem = item.getIcon() as PickList;
            item.setLabel(thisItem.nextState());
            $.UserSettings[thisItem.getField()] = thisItem.getValue();
        }
        // for ToggleMenuItems, save setting
        if (item instanceof WatchUi.ToggleMenuItem) {
            var id = item.getId();
            if (id == :fitLog) {
                $.UserSettings[$.FitLogging] = item.isEnabled();
            } else if (id == :battCalc) {
                $.UserSettings[$.BattCalcMethod] = item.isEnabled();
            } else if (id == :fieldRoll) {
                $.UserSettings[$.RotateFields] = item.isEnabled();
            }
        }
        WatchUi.requestUpdate();
    }

    //! Handle the back key being pressed
    public function onBack() as Void {
        // persist all user input by writing it to property keys
        Properties.setValue("UserSetting1", $.UserSettings[$.DisplayField1] as Number);
        Properties.setValue("UserSetting2", $.UserSettings[$.DisplayField2] as Number);
        Properties.setValue("UserSetting3", $.UserSettings[$.DisplayField3] as Number);
        Properties.setValue("UserSetting4", $.UserSettings[$.DisplayField4] as Number);
        Properties.setValue("BatteryCalcMethod", $.UserSettings[$.BattCalcMethod] as Boolean);
        Properties.setValue("FitLogging", $.UserSettings[$.FitLogging] as Boolean);
        Properties.setValue("RotateFields", $.UserSettings[$.RotateFields] as Boolean);
        // go back
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}

(:SettingsMenu)
//! This is the custom Icon drawable, forming a picklist. It changes label each time the next state is
//! triggered, which is done when the item is selected in this application.
class PickList extends WatchUi.Drawable {

    // This constant stores the fieldvalue strings
    private const _settingsStrings = [
        WatchUi.loadResource($.Rez.Strings.Off), 
        WatchUi.loadResource($.Rez.Strings.TripEnergy), 
        WatchUi.loadResource($.Rez.Strings.Temperature),
        WatchUi.loadResource($.Rez.Strings.DynamoPower),
        WatchUi.loadResource($.Rez.Strings.DynamoGear),
        WatchUi.loadResource($.Rez.Strings.DynamoFrequency),
        WatchUi.loadResource($.Rez.Strings.BatteryVoltage),
        WatchUi.loadResource($.Rez.Strings.BatteryCurrent),
        WatchUi.loadResource($.Rez.Strings.LoadCurrent),
        WatchUi.loadResource($.Rez.Strings.Speed),
        WatchUi.loadResource($.Rez.Strings.BatteryCapacity)];

    private var 
        _index as Number, 
        _field as Number;

    //! Constructor
    public function initialize(field as Number) {
        Drawable.initialize({});
        _index = $.UserSettings[field] as Number;   
        _field = field;
    }

    //! Advance to the next fieldvalue state
    //! @return The new fieldvalue string
    public function nextState() as String {
        _index++;
        if (_index >= _settingsStrings.size()) {
            _index = 0;
        }
        return self.getString();
    }

    //! Return the fieldvalue string for the menu to use as its label
    //! @return The current fieldvalue string
    public function getString() as String {
        return _settingsStrings[_index] as String;
    }

    //! Return the value of the selected field
    //! @return The current field's value
    public function getValue() as Number {
        return _index;
    }

    //! Return the field number of the selected field
    //! @return The current field number
    public function getField() as Number {
        return _field;
    }

    /*
    public function draw(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,                      // gets the width of the device and divides by 2
            dc.getHeight() / 2,                     // gets the height of the device and divides by 2
            Graphics.FONT_MEDIUM,                   // sets the font size
            (_field + 1).toString(),                // the String to display
            Graphics.TEXT_JUSTIFY_CENTER |          // sets the justification for the text
            Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
    */
}