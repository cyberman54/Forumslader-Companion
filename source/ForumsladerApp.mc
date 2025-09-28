/* 
to do:
[ ] Bluetooth Bonding mit SDK v7 implementieren
[ ] Klären: Speed Wert vom Forumslader als Garmin-Input Speed Sensor nutzbar?
[ ] Klären: Welche Forumslader Werte sollen / können in Garmin .FIT Datensatz geloggt werden?
[ ] Widget oder App mit Tasten für Tour- und Trip Reset sowie Verbraucher Ein/Aus
 */

import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;

// global variables
var 
    FLstate as Number = FL_SEARCH,      // current state of state engine
    isV6 as Boolean = false,            // forumslader type V5/V6 identifier
    speedunitFactor as Float = 1.0,     // changed according to FL type
    speedunit as String = "kmh",        // changed according to garmin device settings
    FLpayload as ByteArray = []b,       // $FLx data buffer
    UserSettings as Array = [0, 0, 0, 0, false, false, false, false, false];

//! This data field app uses the BLE data interface of a forumslader.
//! The field will pair with the first Forumslader it encounters and will
//! show up to 4 user selectable values every 1 second in a simpledatafield.
class ForumsladerApp extends AppBase {

    private var
    _bleDelegate as ForumsladerDelegate?,
    _deviceManager as DeviceManager?,
    _dataManager as DataManager?;

    //! Constructor
    public function initialize() {
        AppBase.initialize();
    }

    //! Handle app startup
    //! @param state Startup arguments
    public function onStart(state as Dictionary?) as Void {
        debug("--- started ---");
        if (state != null) {
            debug("state: " + state.toString());
        }
        getUserSettings();
        _dataManager = new $.DataManager();
        _bleDelegate = new $.ForumsladerDelegate();
        if (_bleDelegate == null || _dataManager == null) {
            System.error("Initialization failure");
        }
        _deviceManager = new $.DeviceManager(_bleDelegate, _dataManager);
        BluetoothLowEnergy.setDelegate(_bleDelegate as ForumsladerDelegate);
        (_deviceManager as DeviceManager).startScan();
    }

    //! Handle app shutdown
    //! @param state Shutdown arguments
    public function onStop(state as Dictionary?) as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        BluetoothLowEnergy.setDelegate(null as BleDelegate);
        _deviceManager = null;
        _bleDelegate = null;
        _dataManager = null;
        debug("--- stopped ---");
        if (state != null) {
            debug("state: " + state.toString());
        }
    }

    //! Return the initial view for the app
    //! @return Array [View]
    public function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_dataManager != null && _deviceManager != null) {
            return [new $.ForumsladerView(_dataManager, _deviceManager)];
        }
        System.error("View initialization failure");
    }

    //! Handle change of settings by user in GCM while App is running
	public function onSettingsChanged() {
    	getUserSettings();
        WatchUi.requestUpdate();
	}

    //! get user settings and store them in UserSettings array
    private function getUserSettings() as Void {
        // get user settings from application properties
        $.UserSettings[$.DisplayField1] = readKey("UserSetting1", 0);
        $.UserSettings[$.DisplayField2] = readKey("UserSetting2", 0);
        $.UserSettings[$.DisplayField3] = readKey("UserSetting3", 0);
        $.UserSettings[$.DisplayField4] = readKey("UserSetting4", 0);
        $.UserSettings[$.BattCalcMethod] = readKey("BatteryCalcMethod", false);
        $.UserSettings[$.FitLogging] = readKey("FitLogging", false);
        $.UserSettings[$.RotateFields] = readKey("RotateFields", false);       
        $.UserSettings[$.Alerts] = readKey("Alerts", false);
        $.UserSettings[$.DeviceLock] = Properties.getValue("DeviceLock") as Boolean;
        if ($.UserSettings[$.DeviceLock] == false) { 
            if (Storage.getValue("MyDevice") != null) {
                Storage.deleteValue("MyDevice");
                debug("DeviceLock: device cleared");
            }
        }

        // get speedunit from garmin device settings
        if (System.getDeviceSettings().paceUnits == System.UNIT_METRIC) {
            speedunitFactor = 1.0;
            speedunit = "kmh";
        } else {
            speedunitFactor = 1.609344;
            speedunit = "mph";
        }
        debug("User Settings: " + $.UserSettings.toString() + " " + speedunit);
        // get app version from resources.xml file and write it to properties for display in settings menu
        Properties.setValue("appVersion", Application.loadResource($.Rez.Strings.AppVersion) as String);
    }

    //! helper to safely convert a property's value with maybe unexpected type to a Nunmber or a Boolean
    //! @param property key, default value
    //! @return value as Number
    private function readKey(key as PropertyKeyType, thisDefault as Number or Boolean) as Number or Boolean {
    var value = Properties.getValue(key) as PropertyValueType;
    if(value instanceof Boolean) {
        return value;
    }
    if(value == null || !(value instanceof Number)) {
        if(value != null) {
            value = value as Number;
        } else {
            value = thisDefault;
        }
    }
    return value;
    }

    //! Return the settings view and delegate for the app
    //! @return Array Pair [View, Delegate]
    (:SettingsMenu) 
    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new $.SettingsMenu(), new $.SettingsMenuDelegate()];
    }

    // debug functions
    (:debug)
    public function onActive(state as Dictionary?) as Void {
        debug("App is active");
        if (state != null) {
            debug("state: " + state.toString());
        }
    }
    (:debug)
    public function onInactive(state as Dictionary?) as Void {
        debug("App is inactive");
        if (state != null) {
            debug("state: " + state.toString());
        }
    }
}