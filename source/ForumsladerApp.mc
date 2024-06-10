/* 
to do:
[ ] Garmin Connect Settings-Menü: "Lock to Device" Schalter
[ ] Bluetooth Bonding mit SDK v7 implementieren
[ ] Klären: Speed Wert vom Forumslader als Garmin-Input Speed Sensor nutzbar?
[ ] Klären: Welche Forumslader Werte sollen / können in Garmin .FIT Datensatz geloggt werden?
[ ] Widget oder App mit Tasten für Tour- und Trip Reset sowie Verbraucher Ein/Aus
 */

import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

(:debug) function debug(val as String or Char or Number) as Void {
    switch(val) {
        case instanceof Lang.Number:
            System.println(val as Number);
            break;
        case instanceof Lang.Char:
            System.print(val as Char);
            break;
        case instanceof Lang.String:
            System.println(val as String);
            break;
    }
}

//! This data field app uses the BLE data interface of a forumslader.
//! The field will pair with the first Forumslader it encounters and will
//! show up to 4 user selectable values every 1 second in a simpledatafield.
class ForumsladerApp extends Application.AppBase {

private var
    _profileManager as ProfileManager?,
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
        //debug("--- started ---");
        getUserSettings();
        _profileManager = new $.ProfileManager();
        _dataManager = new $.DataManager();
        _bleDelegate = new $.ForumsladerDelegate();
        if (_bleDelegate != null && _profileManager != null && _dataManager != null)
        {
            _deviceManager = new $.DeviceManager(_bleDelegate, _profileManager, _dataManager);
        } else 
        {
            System.error("App initialization failure");
        }
    }

    //! Handle app shutdown
    //! @param state Shutdown arguments
    public function onStop(state as Dictionary?) as Void {
        _deviceManager = null;
        _bleDelegate = null;
        _profileManager = null;
        _dataManager = null;
        //debug("--- stopped ---");
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
}