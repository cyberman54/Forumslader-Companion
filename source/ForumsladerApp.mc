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

// forumslader data fields we use
enum {
    // FL5/6 sentence
    FL_gear, FL_frequency, FL_battVoltage1, FL_battVoltage2, FL_battVoltage3,
    FL_battCurrent, FL_loadCurrent, FL_intTemp,
    // FLB sentence
    FL_temperature, FL_pressure, FL_sealevel, FL_incline,
    // FLP sentence
    FL_wheelsize, FL_poles, FL_acc2mah,
    // FLC sentence
    FL_tourElevation, FL_tourInclineMax, FL_tourTempMax, FL_tourAltitudeMax, FL_tourPulseMax,   // set 0
    FL_tripElevation, FL_tripInclineMax, FL_tripTempMax, FL_tripAltitudeMax, FL_tripPulseMax,   // set 1
    FL_Elevation, FL_tourInclineMin, FL_tourTempMin, FL_tripInclineMin, FL_tripTempMin,         // set 2
    FL_Energy, FL_tourEnergy, FL_tripEnergy, FL_BTsaveCount, FL_empty1,                         // set 3
    FL_tripSpeedAvg, FL_tourSpeedAvg, FL_tripClimbAvg, FL_tourClimbAvg, FL_empty2,              // set 4
    FL_startCount, FL_socState, FL_fullChargeCapacity, FL_cycleCount, FL_ccadcValue,            // set 5
    // size of FLdata array
    FL_tablesize
}

// settings adjustable by user in garmin mobile app / garmin express
enum {
    DisplayField1, DisplayField2, DisplayField3, DisplayField4, // user selected display values
    BattCalcMethod, FitLogging                                  // user configurable switches
    }

// app states
enum {
    FL_SEARCH,      // 0 = entry state (waiting for pairing & connect)
    FL_COLDSTART,   // 1 = request $FLP data and start $FLx data stream
    FL_CONFIG1,     // 2 = configuration step 1
    FL_CONFIG2,     // 3 = configuration step 2
    FL_CONFIG3,     // 4 = configuration step 3
    FL_DISCONNECT,  // 5 = forumslader has disconnected
    FL_WARMSTART,   // 6 = start data stream, skip configuration
    FL_READY = 9    // 9 = running state (all setup is done)
}

// global variables
var 
    FLstate as Number = FL_SEARCH,  // current state of state engine
    isV6 as Boolean = false,        // forumslader type V5/V6 identifier
    speedunitFactor as Float = 1.0, // changed according to FL type
    speedunit as String = "kmh",    // changed according to garmin device settings
    FLpayload as ByteArray = []b,   // $FLx data buffer
    UserSettings as Array = [0, 0, 0, 0, false, false];

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
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
        BluetoothLowEnergy.setDelegate(null as BleDelegate);
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
        System.error("View initialization failure");
    }

    //! Return the settings view and delegate for the app
    //! @return Array Pair [View, Delegate]
    (:SettingsMenu) 
    public function getSettingsView() as [Views] or [Views, InputDelegates] or Null {
        return [new $.SettingsMenu(), new $.SettingsMenuDelegate()];
    }

    //! Handle change of settings by user in GCM while App is running
	public function onSettingsChanged() {
    	getUserSettings();
        WatchUi.requestUpdate();
	}

    //! get user settings and store them in UserSettings array
    private function getUserSettings() as Void {
        // get user settings from application properties
        $.UserSettings[$.DisplayField1] = Properties.getValue("UserSetting1") as Number;
        $.UserSettings[$.DisplayField2] = Properties.getValue("UserSetting2") as Number;
        $.UserSettings[$.DisplayField3] = Properties.getValue("UserSetting3") as Number;
        $.UserSettings[$.DisplayField4] = Properties.getValue("UserSetting4") as Number;
        $.UserSettings[$.BattCalcMethod] = Properties.getValue("BatteryCalcMethod") as Boolean;
        $.UserSettings[$.FitLogging] = Properties.getValue("FitLogging") as Boolean;
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

}