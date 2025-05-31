import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

class ForumsladerView extends SimpleDataField {

    private const 
        _alertLockTime as Number = 100,     // when an alarm occurs, no consecutive alarms for this time
        _capacityAlarmMin as Number = 20,   // battery low alarm threshold
        _capacityAlarmMax as Number = 30;   // battery low alarm clear threshold
 
    private var 
        _data as DataManager,
        _device as DeviceManager,
        _battVoltage as Float,
        _capacity as Number,
        _index as Number,
        _alertMute as Number,
        _capacityAlertLock as Boolean,
        _fitRecording1 as Field,
        _fitRecording2 as Field,
        _fitRecording3 as Field,
        _fitRecording4 as Field,
        _stateDisplayString as Array<String>;

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager, deviceManager as DeviceManager) {
        SimpleDataField.initialize();
        label = WatchUi.loadResource($.Rez.Strings.AppName) as String;
        _stateDisplayString = [
            WatchUi.loadResource($.Rez.Strings.searching) as String,
            WatchUi.loadResource($.Rez.Strings.connecting) as String,
            WatchUi.loadResource($.Rez.Strings.initializing) as String,
            WatchUi.loadResource($.Rez.Strings.initializing) as String,
            WatchUi.loadResource($.Rez.Strings.initializing) as String,
            WatchUi.loadResource($.Rez.Strings.connecting) as String,
            WatchUi.loadResource($.Rez.Strings.connecting) as String,
            WatchUi.loadResource($.Rez.Strings.connecting) as String] as Array<String>;
        _data = dataManager;
        _device = deviceManager;
        _battVoltage = 0f;
        _capacity = 0;
        _index = 0;
        _alertMute = 0;
        _capacityAlertLock = false;

        // Create custom FIT data fields for recording of 4 forumslader values
        // Battery Voltage
        _fitRecording1 = createField(WatchUi.loadResource($.Rez.Strings.BatteryVoltage) as String, 
            1, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryVoltageLabel) as String}) 
            as FitContributor.Field;
        // Battery Capacity
        _fitRecording2 = createField(WatchUi.loadResource($.Rez.Strings.BatteryCapacity) as String, 
            2, FitContributor.DATA_TYPE_UINT8,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryCapacityLabel) as String}) 
            as FitContributor.Field;
        // Dynamo Power
        _fitRecording3 = createField(WatchUi.loadResource($.Rez.Strings.DynamoPower) as String, 
            3, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.DynamoPowerLabel) as String}) 
            as FitContributor.Field;
        // Electrical Load
        _fitRecording4 = createField(WatchUi.loadResource($.Rez.Strings.Load) as String, 
            4, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.LoadLabel) as String}) 
            as FitContributor.Field;
    }

    //! generate, display and log forumslader values
    //! @return String value to display in the simpledatafield
    private function computeDisplayString() as String {

            // calculate battery voltage and capacity
            _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0 as Float;
            if ($.UserSettings[$.BattCalcMethod] == true) { // use coloumb calculation method
                var x1 = _data.FLdata[FL_ccadcValue].toLong() * _data.FLdata[FL_acc2mah].toLong() / 167772.16 as Float;
                var x2 = _data.FLdata[FL_fullChargeCapacity];
                if (x2 > 0) {
                    _capacity = (x1 / x2).toNumber();
                }
            } else { // use voltage calculation method
                _capacity = _data.FLdata[FL_socState]; 
            }

            // write values to fit file, if FitLogging is enabled by user
            if ($.UserSettings[$.FitLogging] == true) { 
                _fitRecording1.setData(_battVoltage);
                _fitRecording2.setData(_capacity);
                _fitRecording3.setData(_battVoltage * (_data.FLdata[FL_loadCurrent] + _data.FLdata[FL_battCurrent]) / 1000);
                _fitRecording4.setData(_battVoltage * _data.FLdata[FL_loadCurrent] / 1000);
            }

            // display forumslader alarms
            if (ForumsladerView has :showAlert && $.UserSettings[$.Alerts] == true) {
                checkAlarms();
            }            
            
            // display up to 4 show fields, either as concatenated string or selective with rotation
            if ($.UserSettings.slice(0,4).toString().equals("[0, 0, 0, 0]")) {
                return "--";
            }
            var displayString = "";
            if ($.UserSettings[$.RotateFields] == false) { 
                for (var i = 0; i < 4; i++)
                {  
                    if ($.UserSettings[i] > 0) { 
                        displayString += computeFieldValue($.UserSettings[i] as Number);
                        displayString += i == 3 ? "" : " "; // no blank after last show field
                    }
                }
            } else {
                    do {
                        _index = (_index + 1) % 4; // rotating index 0..3
                        if ($.UserSettings[_index] > 0) {
                            displayString = computeFieldValue($.UserSettings[_index] as Number);
                            break;
                        }
                    } while (_index < 4);
            }

            return displayString;
    }

    //! generate a single field value
    //! @param Number of selected field value
    //! @return String value for the selected field
    private function computeFieldValue(fieldvalue as Number) as String {
        switch (fieldvalue)
                {
                    case 11:    // charger state
                        var char = _data.FLdata[FL_status] & 0x8000 ? "-" : "+"; // bit 15: discharge -> "-" / "+"
                        char = _data.FLdata[FL_status] & 0x100 ? "*" : char; // bit 9: overload powerreduce
                        char = _data.FLdata[FL_status] & 0x200 ? "o" : char; // bit 8: overload (dynamo input off for max. 3 mins)
                        return char;
                    case 10:    // remaining battery capacity
                        return _capacity + "%";
                    case 9: {   // speed
                        var speed = _data.FLdata[FL_frequency] * _data.freq2speed as Float;
                        return speed.format("%.1f") + $.speedunit; }
                    case 8:     // electrical load
                        return (_battVoltage * _data.FLdata[FL_loadCurrent] / 1000).format("%.1f") + "W";
                    case 7:     // battery current
                        return (_data.FLdata[FL_battCurrent] / 1000.0).format("%+.1f") + "A";
                    case 6:     // battery voltage
                        return _battVoltage.format("%.1f") + "V";
                    case 5: {   // dynamo impulse frequency
                        var freq = _data.FLdata[FL_frequency] / ($.isV6 ? 10.0 : 1.0) as Float;
                        return freq.toNumber() + "Hz"; }
                    case 4:     // generator gear
                        return _data.FLdata[FL_gear] + "";
                    case 3:     // dynamo power
                        return (_battVoltage * (_data.FLdata[FL_loadCurrent] + _data.FLdata[FL_battCurrent]) / 1000).toNumber() + "W";
                    case 2:     // temperature
                        return (_data.FLdata[FL_temperature] / 10.0).format("%.1f") + "°";
                    case 1:     // trip energy
                        return (_data.FLdata[FL_tripEnergy] / 10.0).format("%.1f") + "Wh";
                    default:
                        return "";
                }
    }

    //! Check forumslader status for alarms
    //! @param forumslader status bitmap
    private function checkAlarms() as Void {
        // no alarms if alertMute is active
        if (_alertMute > 0) { 
            _alertMute--;
            return; 
        } 
        // check for forumslader alarms
        if (_data.FLdata[FL_status] & 0x8) { // bit3: short circuit
            _alertMute = _alertLockTime;
            ForumsladerView.showAlert(new $.ForumsladerAlertView(WatchUi.loadResource($.Rez.Strings.ShortCircuit) as String));
            return;
        }
        if (_data.FLdata[FL_status] & 0x800000) { // system interrupt
            _alertMute = _alertLockTime;
            ForumsladerView.showAlert(new $.ForumsladerAlertView(WatchUi.loadResource($.Rez.Strings.SystemInterrupt) as String));
            return;
        }
        if (_capacity > 0 && _capacity < _capacityAlarmMin && ! _capacityAlertLock) { // battery low
            ForumsladerView.showAlert(new $.ForumsladerAlertView(WatchUi.loadResource($.Rez.Strings.BatteryLow) as String));
            _capacityAlertLock = true;
        }
        else if (_capacity > _capacityAlarmMax && _capacityAlertLock) { 
            _capacityAlertLock = false; 
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