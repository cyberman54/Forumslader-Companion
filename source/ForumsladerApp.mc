/* 
to do:
[ ] Bluetooth Bonding mit SDK v7 implementieren
[ ] Klären: Speed Wert vom Forumslader als Garmin-Input Speed Sensor nutzbar?
[ ] Klären: Welche Forumslader Werte sollen / können in Garmin .FIT Datensatz geloggt werden?
[ ] Widget oder App mit Tasten für Tour- und Trip Reset sowie Verbraucher Ein/Aus
 */

import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.WatchUi;

var UserSettings as Array = [10, 3, 6, 7, false, false, false];

// settings adjustable by user in garmin mobile app / garmin express
enum {
        DisplayField1,
        DisplayField2,
        DisplayField3,
        DisplayField4,
        BattCalcMethod, 
        FitLogging,
        DeviceLock
    }

//! This data field app uses the BLE data interface of a forumslader.
//! The field will pair with the first Forumslader it encounters and will
//! show up to 4 user selectable values every 1 second in a simpledatafield.
class ForumsladerApp extends Application.AppBase {

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
        getUserSettings();
        _dataManager = new $.DataManager();
        _bleDelegate = new $.ForumsladerDelegate();
        _deviceManager = new $.DeviceManager(_bleDelegate, _dataManager);
        BluetoothLowEnergy.setDelegate(_bleDelegate as ForumsladerDelegate);
        (_deviceManager as DeviceManager).startScan();
    }

    //! Handle app shutdown
    //! @param state Shutdown arguments
    public function onStop(state as Dictionary?) as Void {
        _deviceManager = null;
        _bleDelegate = null;
        _dataManager = null;
        debug("--- stopped ---");
    }

    //! Return the initial view for the app
    //! @return Array [View]
    public function getInitialView() as [Views] or [Views, InputDelegates] {
        if (_dataManager != null && _deviceManager != null) {
            return [new $.ForumsladerView(_dataManager, _deviceManager)];
        }
        System.error("View nitialization failure");
    }

    //! Handle change of settings by user in GCM while App is running
	public function onSettingsChanged() {
    	getUserSettings();
        WatchUi.requestUpdate();
	}

    //! read user settings from GCM properties in UserSettings array
    function getUserSettings() as Void {
        $.UserSettings[$.DisplayField1] = Application.Properties.getValue("UserSetting1") as Number;
        $.UserSettings[$.DisplayField2] = Application.Properties.getValue("UserSetting2") as Number;
        $.UserSettings[$.DisplayField3] = Application.Properties.getValue("UserSetting3") as Number;
        $.UserSettings[$.DisplayField4] = Application.Properties.getValue("UserSetting4") as Number;
        $.UserSettings[$.BattCalcMethod] = Application.Properties.getValue("BatteryCalcMethod") as Boolean;
        $.UserSettings[$.FitLogging] = Application.Properties.getValue("FitLogging") as Boolean;
        $.UserSettings[$.DeviceLock] = Application.Properties.getValue("DeviceLock") as Boolean;
        if ($.UserSettings[$.DeviceLock] == false) { 
            Storage.deleteValue("MyDevice");
        }
        debug("User Settings: " + $.UserSettings.toString());
    }

}