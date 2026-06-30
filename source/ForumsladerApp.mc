import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import Toybox.System;

const MAX_PAYLOAD_SIZE as Number = 300; // max BLE payload buffer size

var
    FLstate as Number = FL_SCANNING,
    isV6 as Boolean = false,
    speedunitFactor as Float = 1.0,
    speedunit as String = "kmh",
    distanceunit as String = "km",
    FLpayload as ByteArray = []b,
    UserSettings as Array = [0, 0, 0, 0, false, false, false, false, false, 0, 0, 0, 0];

//! Forumslader BLE data field: pairs with first device, shows up to 4 user-selectable values.
class ForumsladerApp extends AppBase {

    private var
        _bleDelegate as ForumsladerDelegate?,
        _deviceManager as DeviceManager?,
        _dataManager as DataManager?;

    public function initialize() {
        AppBase.initialize();
    }

    //! @param state startup args
    public function onStart(state as Dictionary?) as Void {
        debug("-- start --");
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

    //! @param state shutdown args
    public function onStop(state as Dictionary?) as Void {
        debug("-- stop --");
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        BluetoothLowEnergy.setDelegate(null as BleDelegate);
        _deviceManager = null;
        _bleDelegate = null;
        _dataManager = null;
    }

    public function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_dataManager != null && _deviceManager != null) {
            var view = new $.ForumsladerView(_dataManager, _deviceManager);
            return [view, new $.ForumsladerInputDelegate(view)] as [Views, InputDelegates];
        }
        System.error("View initialization failure");
    }

    //! Called by GCM when settings change at runtime.
    public function onSettingsChanged() {
        getUserSettings();
        (_deviceManager as DeviceManager).saveDevice();
        WatchUi.requestUpdate();
    }

    //! Loads all user settings into UserSettings[].
    private function getUserSettings() as Void {
        $.UserSettings[$.DisplayField1] = readKey("UserSetting1", 0);
        $.UserSettings[$.DisplayField2] = readKey("UserSetting2", 0);
        $.UserSettings[$.DisplayField3] = readKey("UserSetting3", 0);
        $.UserSettings[$.DisplayField4] = readKey("UserSetting4", 0);
        $.UserSettings[$.FitField1] = readKey("UserSettingFit1", 0);
        $.UserSettings[$.FitField2] = readKey("UserSettingFit2", 0);
        $.UserSettings[$.FitField3] = readKey("UserSettingFit3", 0);
        $.UserSettings[$.FitField4] = readKey("UserSettingFit4", 0);
        $.UserSettings[$.BattCalcMethod] = readKey("BatteryCalcMethod", false);
        $.UserSettings[$.FitLogging] = readKey("FitLogging", false);
        $.UserSettings[$.BrowseFields] = readKey("BrowseFields", false);
        $.UserSettings[$.Alerts] = readKey("Alerts", false);
        $.UserSettings[$.DeviceLock] = readKey("DeviceLock", false);

        // metric vs imperial
        if (System.getDeviceSettings().paceUnits == System.UNIT_METRIC) {
            speedunitFactor = 1.0;
            speedunit = "kmh";
            distanceunit = "km";
        } else {
            speedunitFactor = 1.609344;
            speedunit = "mph";
            distanceunit = "mi";
        }

        debug("Read user settings: " + $.UserSettings.toString() + " unit: " + speedunit);
    }

    //! Safely reads a property; returns thisDefault if null or wrong type.
    //! @return value or thisDefault
    private function readKey(key as PropertyKeyType, thisDefault as Number or Boolean) as Number or Boolean {
        var value = Properties.getValue(key as String) as PropertyValueType;

        if (value instanceof Boolean) {
            return value;
        }

        if (value == null || !(value instanceof Number)) {
            if (value != null) {
                value = value as Number;
            } else {
                value = thisDefault;
            }
        }

        return value;
    }

    (:SettingsMenu)
    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new $.SettingsMenu(), new $.SettingsMenuDelegate(_deviceManager as DeviceManager, _dataManager as DataManager)];
    }

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

