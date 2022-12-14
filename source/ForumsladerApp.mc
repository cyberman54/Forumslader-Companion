/* 
to do:
[ ] Garmin Connect Settings-Menü: "Lock to Device" Schalter zum direkten BLE connecten ohne vorheriges scannen
[ ] Garmin Connect Settings-Menü: "Log values" Schalter um Werte in fit Dateien zu loggen
[ ] Berechnung Verbraucherleistung Watt prüfen
[ ] Klären: Speed Wert vom Forumslader als Garmin-Input Speed Sensor nutzbar?
[ ] Klären: Welche Forumslader Werte sollen / können in Garmin .FIT Datensatz geloggt werden?
[ ] Widget oder App mit Tasten für Tour- und Trip Reset sowie Verbraucher Ein/Aus
[ ] Testdatensatz für Mockup erweitern (hierzu reale Testdaten während der Fahrt loggen)
 */

import Toybox.Application;
import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.System;

function debug(str as String) as Void {
    System.println(str);
}

//! This data field app uses the BLE data interface of a forumslader.
//! The field will pair with the first Forumslader it encounters and will
//! show up to 4 user selectable values every 1 second in a simpledatafield.
class ForumsladerApp extends Application.AppBase {

    private var _profileManager as ProfileManager?;
    private var _bleDelegate as ForumsladerDelegate?;
    private var _deviceManager as DeviceManager?;
    private var _dataManager as DataManager?;
    
    //! Constructor
    public function initialize() {
        AppBase.initialize();
    }

    //! Handle app startup
    //! @param state Startup arguments
    public function onStart(state as Dictionary?) as Void {
        debug("--- Field started ---");
        _profileManager = new $.ProfileManager();
        _dataManager = new $.DataManager();
        _bleDelegate = new $.ForumsladerDelegate(_profileManager as ProfileManager);
        // initialize Bluetooth Delegate    
        _deviceManager = new $.DeviceManager(_bleDelegate as ForumsladerDelegate, _profileManager as ProfileManager, _dataManager as DataManager);
        BluetoothLowEnergy.setDelegate(_bleDelegate as ForumsladerDelegate);
        (_profileManager as ProfileManager).registerProfiles();
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }

    //! Handle app shutdown
    //! @param state Shutdown arguments
    public function onStop(state as Dictionary?) as Void {
        _deviceManager = null;
        _bleDelegate = null;
        _profileManager = null;
        _dataManager = null;
        debug("--- Field stopped ---");
    }

    //! Return the initial view for the app
    //! @return Array [View]
    public function getInitialView() as Array<Views or InputDelegates>? {
        var dataManager = _dataManager;
        if (dataManager != null) {
            return [new $.ForumsladerView(dataManager as DataManager)] as Array<Views>;
        } 
        return null; 
    }

    //! Handle change of settings by user in GCM while App is running
	public function onSettingsChanged() {
    	getUserSettings();
        WatchUi.requestUpdate();
	}
}