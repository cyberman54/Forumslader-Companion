import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

class ForumsladerView extends SimpleDataField {

    private const 
        _alertLockTime as Number = 100,     // Sperrzeit in Sekunden nach Alarm-Auslösung
        _capacityAlarmMin as Number = 20,   // Warnung unter 20% Kapazität
        _capacityAlarmMax as Number = 28;   // Entwarnung/Reset erst ab 28% (Hystereseschutz)
 
    private var 
        _data as DataManager,               // Reference to the DataManager for accessing Forumslader data
        _device as DeviceManager,           // Reference to the DeviceManager for accessing Forumslader device state
        _battVoltage as Float,              //  Current battery voltage, calculated from raw sensor values
        _capacity as Number,                //  Current battery capacity in %, calculated from either coulomb counting or voltage method based on user settings 
        _index as Number,                   //  Index for rotating display fields
        _alertMute as Number,               //  Counter to mute alarms for a certain time after they are triggered
        _capacityAlertLock as Boolean,      //  Lock to prevent repeated triggering of battery low alarm until capacity recovers
        _fitRecording1 as Field,            //  Custom FIT data field for recording battery voltage
        _fitRecording2 as Field,            //  Custom FIT data field for recording battery capacity
        _fitRecording3 as Field,            //  Custom FIT data field for recording other values
        _fitRecording4 as Field,            //  Custom FIT data field for recording additional values
        _alertBatteryLowStr as String,      //  String für Batterie-Alarm
        _alertShortCircuitStr as String,    //  String für Kurzschluss-Alarm
        _alertSystemInterruptStr as String, //  String für Systemunterbrechungs-Alarm
        _stateDisplayString as Array<String>;// Array mit Status-Strings für die verschiedenen FL-States (z.B. "Suchen...", "Verbinden...", etc.)

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager, deviceManager as DeviceManager) {
        SimpleDataField.initialize();
        label = WatchUi.loadResource($.Rez.Strings.AppName) as String;
        var initStr = WatchUi.loadResource($.Rez.Strings.initializing) as String;
        var connStr = WatchUi.loadResource($.Rez.Strings.connecting) as String;
        _stateDisplayString = [
            WatchUi.loadResource($.Rez.Strings.searching) as String,
            connStr, initStr, initStr, initStr, connStr, connStr, connStr
        ] as Array<String>;
        _alertBatteryLowStr = WatchUi.loadResource($.Rez.Strings.BatteryLow) as String;
        _alertShortCircuitStr = WatchUi.loadResource($.Rez.Strings.ShortCircuit) as String;
        _alertSystemInterruptStr = WatchUi.loadResource($.Rez.Strings.SystemInterrupt) as String;
        _data = dataManager;
        _device = deviceManager;
        _battVoltage = 0.0f;
        _capacity = 0;
        _index = 0;
        _alertMute = 0;
        _capacityAlertLock = false;

        // Create custom FIT data fields for recording of 4 forumslader values
        _fitRecording1 = createField(WatchUi.loadResource($.Rez.Strings.BatteryVoltage) as String, 
            1, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryVoltageLabel) as String}) as Field;

        _fitRecording2 = createField(WatchUi.loadResource($.Rez.Strings.BatteryCapacity) as String, 
            2, FitContributor.DATA_TYPE_UINT8,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryCapacityLabel) as String}) as Field;

        _fitRecording3 = createField(WatchUi.loadResource($.Rez.Strings.DynamoPower) as String, 
            3, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.DynamoPowerLabel) as String}) as Field;

        _fitRecording4 = createField(WatchUi.loadResource($.Rez.Strings.Load) as String, 
            4, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.LoadLabel) as String}) as Field;
    }

    //! generate, display and log forumslader values
    //! @return String value to display in the simpledatafield
    private function computeDisplayString() as String {
        // calculate battery voltage and capacity
        var flData = _data.FLdata;
        _battVoltage = (flData[FL_battVoltage1] + flData[FL_battVoltage2] + flData[FL_battVoltage3]) / 1000.0 as Float;
        
        if ($.UserSettings[$.BattCalcMethod] == true) { // use coloumb calculation method
            var x1 = flData[FL_ccadcValue].toLong() * flData[FL_acc2mah].toLong() / 167772.16 as Float;
            var x2 = flData[FL_fullChargeCapacity];
            if (x2 > 0) {
                _capacity = (x1 / x2).toNumber();
            }
        } else { // use voltage calculation method
            _capacity = flData[FL_socState]; 
        }

        // Pre-calculate powers to avoid redundant math
        var loadCurrent = flData[FL_loadCurrent];
        var dynamoPower = _battVoltage * (loadCurrent + flData[FL_battCurrent]) / 1000;
        var electricalLoad = _battVoltage * loadCurrent / 1000;

        // write values to fit file, if FitLogging is enabled by user
        if ($.UserSettings[$.FitLogging] == true) { 
            _fitRecording1.setData(_battVoltage);
            _fitRecording2.setData(_capacity);
            _fitRecording3.setData(dynamoPower);
            _fitRecording4.setData(electricalLoad);
        }

        // display forumslader alarms
        if (ForumsladerView has :showAlert && $.UserSettings[$.Alerts] == true) {
            checkAlarms();
        }            
        
        // check if nothing is selected for display, if so return "--"
        if ($.UserSettings[0] == 0 && $.UserSettings[1] == 0 && $.UserSettings[2] == 0 && $.UserSettings[3] == 0) {
            return "--";
        }

        // generate display string based on user settings and rotation mode
        var displayString = "";
        // In non-rotation mode, concatenate all selected fields with a separation blank
        if ($.UserSettings[$.RotateFields] == false) { 
            for (var i = 0; i < 4; i++) {  
                var setting = $.UserSettings[i];
                if (setting > 0) { 
                    displayString += computeFieldValue(setting as Number);
                    if (i < 3 && $.UserSettings[i+1] > 0) {
                        displayString += " "; // separation blank
                    }
                }
            }
        } else {
            // In rotation mode, find the next selected field to display based on the current index
            for (var count = 0; count < 4; count++) {
                _index = (_index + 1) % 4;
                var setting = $.UserSettings[_index];
                if (setting > 0) {
                    displayString = computeFieldValue(setting as Number);
                    break;
                }
            }
        }

        return displayString;
    }

    //! generate a single field value
    //! @param Number of selected field value
    //! @return String value for the selected field
    private function computeFieldValue(fieldvalue as Number) as String {
        var flData = _data.FLdata;
        switch (fieldvalue) {
            case 11:    // charger state
                var status = flData[FL_status];
                var char = (status & 0x8000) ? "-" : "+"; // bit 15: discharge -> "-" / "+"
                char = (status & 0x100) ? "*" : char; // bit 9: overload powerreduce
                char = (status & 0x200) ? "o" : char; // bit 8: overload
                return char;
            case 10:    // remaining battery capacity
                return _capacity + "%";
            case 9:     // speed
                var speed = flData[FL_frequency] * _data.freq2speed;
                return speed.format("%.1f") + $.speedunit;
            case 8:     // electrical load
                return (_battVoltage * flData[FL_loadCurrent] / 1000).format("%.1f") + "W";
            case 7:     // battery current
                return (flData[FL_battCurrent] / 1000.0).format("%+.1f") + "A";
            case 6:     // battery voltage
                return _battVoltage.format("%.1f") + "V";
            case 5:     // odometer
                var tourkm = flData[FL_impulseCounter].toDouble() * _data.imp2odo;
                return tourkm.format("%.1f") + $.distanceunit;
            case 4:     // generator gear
                return flData[FL_gear] + "";
            case 3:     // dynamo power
                return (_battVoltage * (flData[FL_loadCurrent] + flData[FL_battCurrent]) / 1000).toNumber() + "W";
            case 2:     // temperature
                return (flData[FL_temperature] / 10.0).format("%.1f") + "°";
            case 1:     // trip energy
                return (flData[FL_tripEnergy] / 10.0).format("%.1f") + "Wh";
            default:
                return "";
        }
    }

    
    //! Checks background alarm states for battery capacity and forumslader status and shows alert if necessary
    //! Optimized for 1Hz execution loop
    private function checkAlarms() as Void {
        // 1. Early Exit: Wenn der Alarm stummgeschaltet ist, zähle nur den Timer runter
        if (_alertMute > 0) {
            _alertMute--;
            return; 
        }

        // 2. Alarm auslösen (State-Trigger statt dauerhaftem Abfragen)
        if (!_capacityAlertLock) {
            if (_capacity > 0 &&_capacity < _capacityAlarmMin) {
                _capacityAlertLock = true;
                _alertMute = _alertLockTime;
                // Defensiver API-Check: Verhindert Abstürze auf inkompatiblen Garmin-Firmwares
                if (DataField has :showAlert) {
                    showAlert(new $.ForumsladerAlertView(_alertBatteryLowStr));
                }
            }
        } else {
        // 3. Alarm zurücksetzen, wenn die Kapazität sich erholt hat (z. B. durch Ladung)
            if (_capacity > _capacityAlarmMax) {
                _capacityAlertLock = false;
            }
        }
 
        // 4. Weitere Alarme prüfen (z. B. Kurzschluss, Systemunterbrechung) - ebenfalls mit State-Triggern
        if (_data.FLdata[FL_status] & 0x8) { // short circuit
            _alertMute = _alertLockTime;
                if (DataField has :showAlert) {
                    showAlert(new $.ForumsladerAlertView(_alertShortCircuitStr));
                }
            return;
        }
        if (_data.FLdata[FL_status] & 0x800000) { // system interrupt
            _alertMute = _alertLockTime;
            if (DataField has :showAlert) {
                showAlert(new $.ForumsladerAlertView(_alertSystemInterruptStr));
            }
            return;
        }
    }

    //! switch device state, process the $FLx data, calculate and show values every one second
    //! @param info The updated Activity.Info object
    //! @return String value to display in the simpledatafield
    public function compute(info as Info) as Numeric or Duration or String or Null {

        // decode input data
		var size = $.FLpayload.slice(0, 300).size(); // slicing buffer to 300 is for timeout protection
        for (var i = 0; i < size; i++) {
            _data.encode($.FLpayload[i]);
        }
        $.FLpayload = []b; // clear buffer
        //debug("data.age=" + _data.age.format("%d") + " | state=" + $.FLstate.format("%d") + " | buffer=" + _size.format("%d"));

        // toggle device state machine and store current device state
        var deviceState = _device.updateState();

        // if we have recent data, and are fully initialized, display data, else display device state
        if (_data.age <= _data.MAX_AGE_SEC && $.FLstate > FL_CONFIG3) {
            _data.age++; // increase data age seconds counter
            return computeDisplayString(); // display data
        } else {
            return _stateDisplayString[deviceState]; // display state
        }
    }
}