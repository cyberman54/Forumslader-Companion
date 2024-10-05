//
// Copyright 2018-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Properties;

//! This is the menu input delegate for the main menu of the application
class SetupMenuDelegate extends WatchUi.Menu2InputDelegate {

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
            var toggleMenu = new WatchUi.Menu2({:title=>WatchUi.loadResource($.Rez.Strings.MenuSettings) as String, });
            toggleMenu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource($.Rez.Strings.SelectCapacityMethod) as String, 
                null, :battCalc, $.UserSettings[$.BattCalcMethod] as Boolean, null));
            toggleMenu.addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource($.Rez.Strings.SelectFitLogging) as String, 
                null, :fitLog, $.UserSettings[$.FitLogging] as Boolean, null));
            WatchUi.pushView(toggleMenu, new $.SubMenuDelegate(), WatchUi.SLIDE_UP);
        } else if (id == :fields) {
            // When the fields menu item is selected, push a new menu with picklists (custom icons)
            var iconMenu = new WatchUi.Menu2({:title=>WatchUi.loadResource($.Rez.Strings.MenuDatafields) as String});
            var drawable1 = new $.CustomIcon($.DisplayField1, "1");
            var drawable2 = new $.CustomIcon($.DisplayField2, "2");
            var drawable3 = new $.CustomIcon($.DisplayField3, "3");
            var drawable4 = new $.CustomIcon($.DisplayField4, "4");
            iconMenu.addItem(new WatchUi.IconMenuItem(drawable1.getString(), null, "field1", drawable1, null));
            iconMenu.addItem(new WatchUi.IconMenuItem(drawable2.getString(), null, "field2", drawable2, null));
            iconMenu.addItem(new WatchUi.IconMenuItem(drawable3.getString(), null, "field3", drawable3, null));
            iconMenu.addItem(new WatchUi.IconMenuItem(drawable4.getString(), null, "field4", drawable4, null));
            WatchUi.pushView(iconMenu, new $.SubMenuDelegate(), WatchUi.SLIDE_UP);
        } else {
            WatchUi.requestUpdate();
        }
    }

    //! Handle the back key being pressed
    public function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

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
            var thisItem = item.getIcon() as CustomIcon;
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
            } 
        }
        WatchUi.requestUpdate();
    }

    //! Handle the back key being pressed
    public function onBack() as Void {
        // persist all user input to settings
        Properties.setValue("UserSetting1", $.UserSettings[$.DisplayField1] as Number);
        Properties.setValue("UserSetting2", $.UserSettings[$.DisplayField2] as Number);
        Properties.setValue("UserSetting3", $.UserSettings[$.DisplayField3] as Number);
        Properties.setValue("UserSetting4", $.UserSettings[$.DisplayField4] as Number);
        Properties.setValue("BatteryCalcMethod", $.UserSettings[$.BattCalcMethod] as Boolean);
        Properties.setValue("FitLogging", $.UserSettings[$.FitLogging] as Boolean);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

}

//! This is the custom Icon drawable. It changes label each time the next state is
//! triggered, which is done when the item is selected in this application.
class CustomIcon extends WatchUi.Drawable {

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
    public function initialize(field as Number, name as String) {
        Drawable.initialize({});
        _index = $.UserSettings[field] as Number;   
        _field = field;
    }

    //! Advance to the next fieldvalue state for the datafield selector
    //! @return The new fieldvalue string
    public function nextState() as String {
        _index++;
        if (_index >= _settingsStrings.size()) {
            _index = 0;
        }
        return _settingsStrings[_index] as String;
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
}
