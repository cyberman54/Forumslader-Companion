import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

class ForumsladerView extends SimpleDataField {

    private var 
        _data as DataManager,
        _device as DeviceManager,
        _deviceState as String,
        _searching as String,
        _connecting as String,
        _initializing as String,
        _battVoltage as Float,
        _capacity as Number,
        _index as Number,
        _fitRecording1 as Field,
        _fitRecording2 as Field,
        _fitRecording3 as Field,
        _fitRecording4 as Field;

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager, deviceManager as DeviceManager) {
        SimpleDataField.initialize();
        label = WatchUi.loadResource($.Rez.Strings.AppName) as String;
        _searching = WatchUi.loadResource($.Rez.Strings.searching) as String;
        _connecting = WatchUi.loadResource($.Rez.Strings.connecting) as String;
        _initializing = WatchUi.loadResource($.Rez.Strings.initializing) as String;
        _data = dataManager;
        _device = deviceManager;
        _deviceState = _searching;
        _battVoltage = 0f;
        _capacity = 0;
        _index = 0;

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
        // Battery Current
        _fitRecording4 = createField(WatchUi.loadResource($.Rez.Strings.BatteryCurrent) as String, 
            4, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryCurrentLabel) as String}) 
            as FitContributor.Field;
    }

    //! generate, display and log forumslader values
    //! @return String value to display in the simpledatafield
    private function computeDisplayString() as String {
            
            var displayString = "";

            // early exit if no show fields are configured
            if ($.UserSettings.slice(0,4).toString().equals("[0, 0, 0, 0]")) {
                return "--";
            }

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

            // display up to 4 show fields, either as concatenated string or selective with rotation
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

            // write values to fit file, if FitLogging is enabled by user
            if ($.UserSettings[$.FitLogging] == true) { 
                _fitRecording1.setData(_battVoltage);
                _fitRecording2.setData(_capacity);
                _fitRecording3.setData(_battVoltage * _data.FLdata[FL_loadCurrent] / 1000);
                _fitRecording4.setData(_data.FLdata[FL_battCurrent] / 1000.0);
            }

            return displayString;
    }

    //! generate a single field value
    //! @param Number of selected field value
    //! @return String value for the selected field
    private function computeFieldValue(fieldvalue as Number) as String {
        switch (fieldvalue)
                {
                    case 10: // remaining battery capacity
                        return _capacity + "%";
                    case 9: // speed
                        var speed = _data.FLdata[FL_frequency] * _data.freq2speed as Float;
                        return speed.format("%.1f") + $.speedunit;
                    case 8: // load current
                        return (_data.FLdata[FL_loadCurrent] / 1000.0).format("%.1f") + "A";
                    case 7: // battery current
                        return (_data.FLdata[FL_battCurrent] / 1000.0).format("%+.1f") + "A";
                    case 6: // battery voltage
                        return _battVoltage.format("%.1f") + "V";
                    case 5: // dynamo impulse frequency
                        var freq = _data.FLdata[FL_frequency] / ($.isV6 ? 10.0 : 1.0) as Float;
                        return freq.toNumber() + "Hz";
                    case 4: // generator gear
                        return _data.FLdata[FL_gear] + "";
                    case 3: // dynamo power
                        return (_battVoltage * (_data.FLdata[FL_loadCurrent] + _data.FLdata[FL_battCurrent]) / 1000).toNumber() + "W";
                    case 2: // temperature
                        return (_data.FLdata[FL_temperature] / 10.0).format("%.1f") + "°C";
                    case 1: // trip energy
                        return _data.FLdata[FL_tripEnergy] + "Wh";
                    default:
                        return "";
                }
    }

    //! switch device state, process the $FLx data, calculate and show values every one second
    //! @param info The updated Activity.Info object
    //! @return String value to display in the simpledatafield
    public function compute(info as Info) as Numeric or Duration or String or Null {

        // decode input data
		var _size = $.FLpayload.slice(0, 300).size(); // slicing buffer to 300 is for timeout protection
        for (var i = 0; i < _size; i++) {
            _data.encode($.FLpayload[i]);
        }
        $.FLpayload = []b; // clear buffer
        //debug("tick=" + _data.tick.format("%d") + " | state=" + $.FLstate.format("%d") + " | buffer=" + _size.format("%d"));

        // toggle device state machine and set displaystring to device state
        switch (_device.updateState()) 
        {
            case FL_SEARCH:
                _deviceState = _searching;
                break;
            case FL_DISCONNECT:
            case FL_COLDSTART:
            case FL_WARMSTART:
            case FL_READY:
                _deviceState = _connecting;
                break;
            case FL_CONFIG1:
            case FL_CONFIG2:
            case FL_CONFIG3:
                _deviceState = _initializing;
                break;
            }
        
        // if we have recent data, and are fully initialized we display data, else we display device state
        if (_data.tick <= _data.MAX_AGE_SEC && $.FLstate > FL_CONFIG3) {
            _data.tick++; // increase data age seconds counter
            return computeDisplayString(); // display data
        } else {
            return _deviceState; // display state
        }
    }

}