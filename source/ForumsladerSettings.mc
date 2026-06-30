import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.BluetoothLowEnergy;
import Toybox.Application.Storage;

enum {
    DisplayField1, DisplayField2, DisplayField3, DisplayField4,     // user selected display values
    BattCalcMethod, FitLogging, BrowseFields, Alerts, DeviceLock,   // user configurable switches
    FitField1, FitField2, FitField3, FitField4                      // user selected FIT logging values
    }

(:SettingsMenu)
//! Main settings menu: Options / Datafields / FIT Datafields / Trip Reset.
class SettingsMenu extends WatchUi.Menu2 {

    //! Constructor
    function initialize() {
        Menu2.initialize(null);
        var appName = WatchUi.loadResource($.Rez.Strings.AppName) as String;
        var appVersion = WatchUi.loadResource($.Rez.Strings.AppVersion) as String;
        Menu2.setTitle(appName + " v" + appVersion as String);
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuSettings) as String, null, :options, null));
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuDatafields) as String, null, :fields, null));
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuFitDatafields) as String, null, :fitfields, null));
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuTripReset) as String, null, :counterreset, null));
    }
}

(:SettingsMenu)
//! Handles main menu item selections.
class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var
        _deviceManager as DeviceManager,
        _dataManager as DataManager,
        _sOptionsTitle as String,
        _sCapacity as String,
        _sFitLog as String,
        _sBrowse as String,
        _sAlerts as String,
        _sDeviceLock as String;

    //! Constructor
    public function initialize(deviceManager as DeviceManager, dataManager as DataManager) {
        _deviceManager = deviceManager;
        _dataManager = dataManager;
        Menu2InputDelegate.initialize();
        _sOptionsTitle  = WatchUi.loadResource($.Rez.Strings.MenuSettings) as String;
        _sCapacity      = WatchUi.loadResource($.Rez.Strings.SelectCapacityMethod) as String;
        _sFitLog        = WatchUi.loadResource($.Rez.Strings.SelectFitLogging) as String;
        _sBrowse        = WatchUi.loadResource($.Rez.Strings.SelectBrowseFields) as String;
        _sAlerts        = WatchUi.loadResource($.Rez.Strings.SelectAlerts) as String;
        _sDeviceLock    = WatchUi.loadResource($.Rez.Strings.SelectDeviceLock) as String;
    }

    //! @param item selected item
    public function onSelect(item as MenuItem) as Void {
        var id = item.getId() as Symbol;
        if (id == :options) {
            // When the options menu item is selected, push a new menu with toggle switches (cached strings)
            var menu = new WatchUi.Menu2({:title => _sOptionsTitle});
            menu.addItem(new WatchUi.ToggleMenuItem(_sCapacity, null, :battCalc, $.UserSettings[$.BattCalcMethod] as Boolean, null));
            menu.addItem(new WatchUi.ToggleMenuItem(_sFitLog, null, :fitLog, $.UserSettings[$.FitLogging] as Boolean, null));
            menu.addItem(new WatchUi.ToggleMenuItem(_sBrowse, null, :fieldBrowse, $.UserSettings[$.BrowseFields] as Boolean, null));
            menu.addItem(new WatchUi.ToggleMenuItem(_sAlerts, null, :alerts, $.UserSettings[$.Alerts] as Boolean, null));
            menu.addItem(new WatchUi.ToggleMenuItem(_sDeviceLock, null, :devicelock, $.UserSettings[$.DeviceLock] as Boolean, null));
            WatchUi.pushView(menu, new $.SubMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :fields) {
            // Push a menu to configure four display slots
            var menu = new WatchUi.Menu2({:title=>WatchUi.loadResource($.Rez.Strings.MenuDatafields) as String});
            var drawable1 = new $.PickList($.DisplayField1, 13);
            var drawable2 = new $.PickList($.DisplayField2, 13);
            var drawable3 = new $.PickList($.DisplayField3, 13);
            var drawable4 = new $.PickList($.DisplayField4, 13);
            menu.addItem(new WatchUi.IconMenuItem(drawable1.getString(), null, $.DisplayField1, drawable1, null));
            menu.addItem(new WatchUi.IconMenuItem(drawable2.getString(), null, $.DisplayField2, drawable2, null));
            menu.addItem(new WatchUi.IconMenuItem(drawable3.getString(), null, $.DisplayField3, drawable3, null));
            menu.addItem(new WatchUi.IconMenuItem(drawable4.getString(), null, $.DisplayField4, drawable4, null));
            WatchUi.pushView(menu, new $.SubMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :fitfields) {
            // Push a menu to configure four FIT logging slots
            var fitMenu = new WatchUi.Menu2({:title=>WatchUi.loadResource($.Rez.Strings.MenuFitDatafields) as String});
            var fitDrawable1 = new $.PickList($.FitField1, 10);
            var fitDrawable2 = new $.PickList($.FitField2, 10);
            var fitDrawable3 = new $.PickList($.FitField3, 10);
            var fitDrawable4 = new $.PickList($.FitField4, 10);
            fitMenu.addItem(new WatchUi.IconMenuItem(fitDrawable1.getString(), null, $.FitField1, fitDrawable1, null));
            fitMenu.addItem(new WatchUi.IconMenuItem(fitDrawable2.getString(), null, $.FitField2, fitDrawable2, null));
            fitMenu.addItem(new WatchUi.IconMenuItem(fitDrawable3.getString(), null, $.FitField3, fitDrawable3, null));
            fitMenu.addItem(new WatchUi.IconMenuItem(fitDrawable4.getString(), null, $.FitField4, fitDrawable4, null));
            WatchUi.pushView(fitMenu, new $.SubMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
        } else if (id == :counterreset) {
            // Push a menu to confirm trip reset or tour reset
            var title = ($.FLstate == FL_RUNNING)
                ? WatchUi.loadResource($.Rez.Strings.TripResetConfirm) as String
                : WatchUi.loadResource($.Rez.Strings.NotConnected) as String;
            var menu = new WatchUi.Menu2({:title => title});
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.TripResetYes) as String, null, :tripconfirm, null));
            menu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.TourResetYes) as String, null, :tourconfirm, null));
            WatchUi.pushView(menu, new $.TripResetDelegate(_deviceManager, _dataManager), WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.requestUpdate();
        }
    }

    //! Handle the back key being pressed
    public function onBack() as Void {
        debug("User settings: " + $.UserSettings.toString());
        _deviceManager.saveDevice();
        Menu2InputDelegate.onBack();
    }
}

(:SettingsMenu)
//! Shared delegate for options toggles and field picklists.
class SubMenuDelegate extends WatchUi.Menu2InputDelegate {

    //! Constructor
    public function initialize() {
        Menu2InputDelegate.initialize();
    }

    //! @param item selected item
    public function onSelect(item as MenuItem) as Void {
        // picklist: advance to next value
        if (item instanceof WatchUi.IconMenuItem) {
            var thisItem = item.getIcon() as PickList;
            item.setLabel(thisItem.nextState());
            $.UserSettings[thisItem.getField()] = thisItem.getValue();
        }
        // toggle: save to UserSettings
        if (item instanceof WatchUi.ToggleMenuItem) {
            var id = item.getId();
            if (id == :fitLog) {
                $.UserSettings[$.FitLogging] = item.isEnabled();
            } else if (id == :battCalc) {
                $.UserSettings[$.BattCalcMethod] = item.isEnabled();
            } else if (id == :fieldBrowse) {
                $.UserSettings[$.BrowseFields] = item.isEnabled();
            } else if (id == :alerts) {
                $.UserSettings[$.Alerts] = item.isEnabled();
            } else if (id == :devicelock) {
                $.UserSettings[$.DeviceLock] = item.isEnabled();
            }
        }
        WatchUi.requestUpdate();
    }

    public function onBack() as Void {
        // persist to storage
        Properties.setValue("UserSetting1", $.UserSettings[$.DisplayField1] as Number);
        Properties.setValue("UserSetting2", $.UserSettings[$.DisplayField2] as Number);
        Properties.setValue("UserSetting3", $.UserSettings[$.DisplayField3] as Number);
        Properties.setValue("UserSetting4", $.UserSettings[$.DisplayField4] as Number);
        Properties.setValue("UserSettingFit1", $.UserSettings[$.FitField1] as Number);
        Properties.setValue("UserSettingFit2", $.UserSettings[$.FitField2] as Number);
        Properties.setValue("UserSettingFit3", $.UserSettings[$.FitField3] as Number);
        Properties.setValue("UserSettingFit4", $.UserSettings[$.FitField4] as Number);
        Properties.setValue("BatteryCalcMethod", $.UserSettings[$.BattCalcMethod] as Boolean);
        Properties.setValue("FitLogging", $.UserSettings[$.FitLogging] as Boolean);
        Properties.setValue("BrowseFields", $.UserSettings[$.BrowseFields] as Boolean);
        Properties.setValue("Alerts", $.UserSettings[$.Alerts] as Boolean);
        Properties.setValue("DeviceLock", $.UserSettings[$.DeviceLock] as Boolean);
        Menu2InputDelegate.onBack();
    }
}

(:SettingsMenu)
//! Cyclic picklist drawable; cycles through field-name strings on each selection.
class PickList extends WatchUi.Drawable {

    // [0.._maxSetting] are loaded
    private const _stringIds = [
        $.Rez.Strings.Off,            $.Rez.Strings.TripEnergy,     $.Rez.Strings.Temperature,
        $.Rez.Strings.DynamoPower,    $.Rez.Strings.DynamoGear,     $.Rez.Strings.Distance,
        $.Rez.Strings.BatteryVoltage, $.Rez.Strings.BatteryCurrent, $.Rez.Strings.Load,
        $.Rez.Strings.Speed,          $.Rez.Strings.BatteryCapacity,$.Rez.Strings.ChargingState,
        $.Rez.Strings.DayDistance,    $.Rez.Strings.TourDistance
    ];

    private var
        _settingsStrings as Array<Object>,
        _index as Number,
        _field as Number,
        _maxSetting as Number;

    //! Constructor
    public function initialize(field as Number, maxSetting as Number) {
        Drawable.initialize({});
        _maxSetting = maxSetting;
        _index = $.UserSettings[field] as Number;
        if (_index > _maxSetting) {
            _index = 0;
        }
        _field = field;
        _settingsStrings = new [maxSetting + 1] as Array<Object>;
        for (var i = 0; i <= maxSetting; i++) {
            _settingsStrings[i] = WatchUi.loadResource(_stringIds[i]);
        }
    }

    //! @return next field label
    public function nextState() as String {
        _index++;
        if (_index > _maxSetting) {
            _index = 0;
        }
        return self.getString();
    }

    //! @return current field label
    public function getString() as String {
        return _settingsStrings[_index] as String;
    }

    //! @return current index value
    public function getValue() as Number {
        return _index;
    }

    //! @return settings key for this picklist
    public function getField() as Number {
        return _field;
    }
}

