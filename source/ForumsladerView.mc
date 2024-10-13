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

            var 
                _displayString = "",
                battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0 as Float,
                capacity = 0;

            if ($.UserSettings[$.BattCalcMethod] == true) { // use coloumb calculation method
                var x1 = _data.FLdata[FL_ccadcValue].toLong() * _data.FLdata[FL_acc2mah].toLong() / 167772.16 as Float;
                var x2 = _data.FLdata[FL_fullChargeCapacity];
                if (x2 > 0) {
                    capacity = (x1 / x2).toNumber();
                }
            } else { // use voltage calculation method
                capacity = _data.FLdata[FL_socState]; 
            }
   
            // display user selected values
            for (var i = 0; i <= $.DisplayField4; i++)
            {  
                switch ($.UserSettings[i] as Number)
                {
                    case 0: // off
                        break;

                    case 10: // remaining battery capacity
                        _displayString += capacity + "%";
                        break;

                    case 9: // speed
                        var speed = _data.FLdata[FL_frequency] * _data.freq2speed as Float;
                        _displayString += speed.format("%.1f") + $.speedunit;
                        break;

                    case 8: // load current
                        _displayString += (_data.FLdata[FL_loadCurrent] / 1000.0).format("%.1f") + "A";
                        break;

                    case 7: // battery current
                        _displayString += (_data.FLdata[FL_battCurrent] / 1000.0).format("%+.1f") + "A";
                        break;

                    case 6: // battery voltage
                        _displayString += battVoltage.format("%.1f") + "V";
                        break;

                    case 5: // dynamo impulse frequency
                        var freq = _data.FLdata[FL_frequency] / ($.isV6 ? 10.0 : 1.0) as Float;
                        _displayString += freq.toNumber() + "Hz";
                        break;

                    case 4: // generator gear
                        _displayString += _data.FLdata[FL_gear];
                        break;

                    case 3: // dynamo power
                        _displayString += (battVoltage * (_data.FLdata[FL_loadCurrent] + _data.FLdata[FL_battCurrent]) / 1000).toNumber() + "W";
                        break;

                    case 2: // temperature
                        _displayString += (_data.FLdata[FL_temperature] / 10.0).format("%.1f") + "°C";
                        break;

                    case 1: // trip energy
                        _displayString += _data.FLdata[FL_tripEnergy] + "Wh";
                        break;
                }
                _displayString += i < $.DisplayField4 ? " " : "";
            }

            // write values to fit file, if FitLogging is enabled by user
            if ($.UserSettings[$.FitLogging] == true) { 
                _fitRecording1.setData(battVoltage);
                _fitRecording2.setData(capacity);
                _fitRecording3.setData(battVoltage * _data.FLdata[FL_loadCurrent] / 1000);
                _fitRecording4.setData(_data.FLdata[FL_battCurrent] / 1000.0);
            }

            return _displayString;
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

//! The data field alert
class DataFieldAlertView extends WatchUi.DataFieldAlert {

    //! Constructor
    public function initialize() {
        DataFieldAlert.initialize();
    }

    //! Update the view
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 30, Graphics.FONT_SMALL, "Alert: 10 sec elapsed", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

//! Data field that shows HR, distance, and time
class DataField extends WatchUi.SimpleDataField {
    private const METERS_TO_MILES = 0.000621371;
    private const MILLISECONDS_TO_SECONDS = 0.001;

    private var _counter as Number;
    private var _alertDisplayed as Boolean;

    //! Constructor
    public function initialize() {
        SimpleDataField.initialize();
        label = "HR, Dist, Timer";
        _counter = 0;
        _alertDisplayed = false;
    }

    //! Get the information to show in the data field
    //! @param info The updated Activity.Info object
    //! @return The data to show
    public function compute(info as Info) as Numeric or Duration or String or Null {
        var value_picked = "--";

        // Cycle between heart rate (int), distance (float), and stopwatch time (Duration)
        if ((_counter == 0) && (info.currentHeartRate != null)) {
            value_picked = info.currentHeartRate;
        } else if (_counter == 1) {
            var elapsedDistance = info.elapsedDistance;
            if (elapsedDistance != null) {
                value_picked = elapsedDistance * METERS_TO_MILES;
            }
        } else if (_counter == 2) {
            var timerTime = info.timerTime;
            if (timerTime != null) {
                var options = {:seconds => (timerTime *  MILLISECONDS_TO_SECONDS).toNumber()};
                value_picked = Time.Gregorian.duration(options);

                if ((WatchUi.DataField has :showAlert) && ((timerTime * MILLISECONDS_TO_SECONDS) > 10.000f)
                    && !_alertDisplayed) {
                    _alertDisplayed = true;
                }
            }
        }

        _counter++;
        if (_counter > 2) {
            _counter = 0;
        }

        return value_picked;
    }
}