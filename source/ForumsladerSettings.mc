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
        Menu2.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.MenuKonfig) as String, null, :forumslader, null));
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
        _sDeviceLock as String,
        _sKonfigTitle as String;

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
        _sKonfigTitle   = WatchUi.loadResource($.Rez.Strings.MenuKonfig) as String;
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
        } else if (id == :forumslader) {
            // Push a combined menu for FL hardware config and odometer resets.
            // Config values are sent automatically when the user navigates back.
            var flMenu = new WatchUi.Menu2({:title => _sKonfigTitle});
            var flWs = _dataManager.FLdata[$.FL_wheelsize];
            var flPo = _dataManager.FLdata[$.FL_poles];
            // Rows 0-1: odometer resets (most frequently used, at top)
            flMenu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.ResetTripAction) as String, null, :tripreset, null));
            flMenu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.ResetTourAction) as String, null, :tourreset, null));
            // Rows 2-4: hardware config
            flMenu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.KonfigWheelsize) as String, null, :wheelsize, null));
            flMenu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.KonfigPoles) as String, null, :poles, null));
            flMenu.addItem(new WatchUi.MenuItem(WatchUi.loadResource($.Rez.Strings.KonfigPoweroff) as String, null, :poweroff, null));

            WatchUi.pushView(flMenu, new $.ForumsladerMenuDelegate(_deviceManager, _dataManager, flMenu, flWs, flPo), WatchUi.SLIDE_IMMEDIATE);
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

(:SettingsMenu)
//! Delegate for the combined Forumslader menu (hardware config + odometer resets).
//! Config values (tire size, pole count, poweroff time) are sent to the device automatically
//! when the user navigates back. Odometer resets require a confirmation sub-menu.
class ForumsladerMenuDelegate extends WatchUi.Menu2InputDelegate {

    // Common ISO tire circumferences (mm) ordered by size
    private const WHEEL_SIZES = [
        1578, 1686, 1796, 1952, 2026, 2051, 2068, 2086,
        2105, 2130, 2146, 2168, 2180, 2199, 2224, 2247,
        2268, 2288, 2326
    ] as Array<Number>;

    // Predefined poweroff steps in seconds (0 = never)
    private const POWEROFF_STEPS = [0, 30, 60, 90, 120, 150, 180, 210, 240, 255] as Array<Number>;

    private var
        _deviceManager as DeviceManager,
        _dataManager   as DataManager,
        _menu          as WatchUi.Menu2,
        _wheelIdx      as Number,
        _polesVal      as Number,
        _poweroffIdx   as Number,
        _wheelPolesChanged as Boolean,
        _poweroffChanged   as Boolean;

    //! @param deviceManager  used to send commands to the Forumslader
    //! @param dataManager    used to update pulse offsets after an odometer reset
    //! @param menu           the Menu2 view whose item sub-labels will be updated
    //! @param flWheelsize    wheel circumference from live FLP data (0 if not yet received)
    //! @param flPoles        pole count from live FLP data (0 if not yet received)
    public function initialize(deviceManager as DeviceManager, dataManager as DataManager,
                               menu as WatchUi.Menu2,
                               flWheelsize as Number, flPoles as Number) {
        Menu2InputDelegate.initialize();
        _deviceManager = deviceManager;
        _dataManager   = dataManager;
        _menu          = menu;
        _wheelPolesChanged = false;
        _poweroffChanged   = false;

        // Priority: Storage (user's last saved values) > FLP live data > built-in defaults
        var storedWs  = Storage.getValue("KonfigWS")  as Number?;
        var storedPo  = Storage.getValue("KonfigPO")  as Number?;
        var storedOff = Storage.getValue("KonfigOFF") as Number?;

        var ws = (storedWs != null)  ? storedWs  : ((flWheelsize > 0) ? flWheelsize : 2199);
        var po = (storedPo != null)  ? storedPo  : ((flPoles >= 1 && flPoles <= 32) ? flPoles : 14);
        var off = (storedOff != null) ? storedOff : 120;

        _wheelIdx    = _findNearest(ws, WHEEL_SIZES);
        _polesVal    = (po >= 1 && po <= 32) ? po : 14;
        _poweroffIdx = _findNearest(off, POWEROFF_STEPS);

        // Set all three sub-labels to the resolved values (indices 2-4, rows 0-1 are resets)
        (_menu.getItem(2) as WatchUi.MenuItem).setSubLabel(WHEEL_SIZES[_wheelIdx].toString() + " mm");
        (_menu.getItem(3) as WatchUi.MenuItem).setSubLabel(_polesVal.toString());
        (_menu.getItem(4) as WatchUi.MenuItem).setSubLabel(POWEROFF_STEPS[_poweroffIdx].toString() + " s");
    }

    //! Returns the index of the element in arr closest to target.
    private function _findNearest(target as Number, arr as Array<Number>) as Number {
        var best = 0;
        var bestDiff = arr[0] - target;
        if (bestDiff < 0) { bestDiff = -bestDiff; }
        for (var i = 1; i < arr.size(); i++) {
            var diff = arr[i] - target;
            if (diff < 0) { diff = -diff; }
            if (diff < bestDiff) { bestDiff = diff; best = i; }
        }
        return best;
    }

    //! Handles item selection: cycles through config values or opens a reset confirmation.
    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Symbol;
        if (id == :wheelsize) {
            _wheelIdx = (_wheelIdx + 1) % WHEEL_SIZES.size();
            item.setSubLabel(WHEEL_SIZES[_wheelIdx].toString() + " mm");
            _wheelPolesChanged = true;
        } else if (id == :poles) {
            _polesVal = (_polesVal % 32) + 1;
            item.setSubLabel(_polesVal.toString());
            _wheelPolesChanged = true;
        } else if (id == :poweroff) {
            _poweroffIdx = (_poweroffIdx + 1) % POWEROFF_STEPS.size();
            item.setSubLabel(POWEROFF_STEPS[_poweroffIdx].toString() + " s");
            _poweroffChanged = true;
        } else if (id == :tripreset || id == :tourreset) {
            // Push a single-item confirmation sub-menu; TripResetDelegate handles the action.
            var confirmId = (id == :tripreset) ? :tripconfirm : :tourconfirm;
            var title = ($.FLstate == FL_RUNNING)
                ? WatchUi.loadResource($.Rez.Strings.TripResetConfirm) as String
                : WatchUi.loadResource($.Rez.Strings.NotConnected) as String;
            var confirmMenu = new WatchUi.Menu2({:title => title});
            confirmMenu.addItem(new WatchUi.MenuItem(
                WatchUi.loadResource($.Rez.Strings.TripResetYes) as String, null, confirmId, null));
            WatchUi.pushView(confirmMenu, new $.TripResetDelegate(_deviceManager, _dataManager), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        WatchUi.requestUpdate();
    }

    //! Sends only changed config values to the Forumslader and persists them before closing the menu.
    public function onBack() as Void {
        if (_wheelPolesChanged) {
            Storage.setValue("KonfigWS", WHEEL_SIZES[_wheelIdx]);
            Storage.setValue("KonfigPO", _polesVal);
            _deviceManager.sendWheelConfig(WHEEL_SIZES[_wheelIdx], _polesVal);
        }
        if (_poweroffChanged) {
            Storage.setValue("KonfigOFF", POWEROFF_STEPS[_poweroffIdx]);
            _deviceManager.sendPoweroff(POWEROFF_STEPS[_poweroffIdx]);
        }
        Menu2InputDelegate.onBack();
    }
}

