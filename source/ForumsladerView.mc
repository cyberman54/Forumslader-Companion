import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

var displayString as String = "";

class ForumsladerView extends WatchUi.SimpleDataField {

    private var 
        _unitString as String = "",
        _data as DataManager,
        _device as DeviceManager,
        _searching as String,
        _connecting as String,
        _datastale as String,
        _fitRecording1 as FitContributor.Field,
        _fitRecording2 as FitContributor.Field,
        _fitRecording3 as FitContributor.Field,
        _fitRecording4 as FitContributor.Field;

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager, deviceManager as DeviceManager) {
        SimpleDataField.initialize();
        getUserSettings();
        label = WatchUi.loadResource($.Rez.Strings.AppName) as String;
        _searching = WatchUi.loadResource($.Rez.Strings.searching) as String;
        _connecting = WatchUi.loadResource($.Rez.Strings.connecting) as String;
        _datastale = WatchUi.loadResource($.Rez.Strings.datastale) as String;
        _data = dataManager;
        _device = deviceManager;

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

            $.displayString = "";
            _unitString = "";

            var freq = $.isV6 ? _data.FLdata[FL_frequency] / 10 : _data.FLdata[FL_frequency];
            var battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
            var speed = _data.FLdata[FL_poles] > 0 ? freq / _data.FLdata[FL_poles] * _data.FLdata[FL_wheelsize] / 277.777 : 0.0;
            var capacity = 0;

            if ($.showValues[4] == true) { // use coloumb calculation method
                var x1 = (_data.FLdata[FL_ccadcValue].toLong() * _data.FLdata[FL_acc2mah].toLong() / 167772.16).toFloat();
                var x2 = _data.FLdata[FL_fullChargeCapacity];
                capacity = (x1 / x2).toNumber();
            } else { // use voltage calculation method
                capacity = _data.FLdata[FL_socState]; 
            }
            
            // display user selected values
            for (var i = 0; i < $.showValues.size() - 2; i++)
            {  
                $.displayString += ($.displayString.length() > 0) ? " " : "";
                
                switch ($.showValues[i] as Number)
                {
                    case 1: // trip energy
                        _unitString = "Wh";
                        $.displayString += (_data.FLdata[FL_tripEnergy] >= 0) ? _data.FLdata[FL_tripEnergy] : "--";
                        break;

                    case 2: // temperature
                        _unitString = "°C";
                        $.displayString += (_data.FLdata[FL_temperature] / 10.0).format("%.1f");
                        break;

                    case 3: // dynamo power
                        _unitString = "W";
                        $.displayString += (_data.FLdata[FL_frequency] > 0) ? (battVoltage * _data.FLdata[FL_loadCurrent] / 1000).toNumber() : "0";
                        break;

                    case 4: // generator gear
                        _unitString = "";
                        $.displayString += (_data.FLdata[FL_gear] >= 0) ? _data.FLdata[FL_gear] : "--";
                        break;

                    case 5: // dynamo impulse frequency
                        _unitString = "Hz";
                        $.displayString += freq >= 0 ? freq.toNumber() : "--";
                        break;

                    case 6: // battery voltage
                        _unitString = "V";
                        $.displayString += (battVoltage > 0) ? battVoltage.format("%.1f") : "--";
                        break;

                    case 7: // battery current
                        _unitString = "A";
                        $.displayString += (_data.FLdata[FL_battCurrent] / 1000.0).format("%+.1f");
                        break;

                    case 8: // load current
                        _unitString = "A";
                        $.displayString += (_data.FLdata[FL_loadCurrent] >= 0) ? (_data.FLdata[FL_loadCurrent] / 1000.0).format("%.1f") : "--";
                        break;

                    case 9: // speed
                        _unitString = "km/h";
                        if (_data.FLdata[FL_poles] > 0) {
                            $.displayString += speed.toNumber();
                        } else {
                            $.displayString += "--";
                        }
                        break;

                    case 10: // remaining battery capacity
                        _unitString = "%";
                        $.displayString += (capacity > 0) ? capacity : "--";
                        break;

                    default: // off
                    _unitString = "";
                    break;
                }
                $.displayString += _unitString;
            }

            // write values to fit file, if logging is enabled by user
            if ($.showValues[5] == true) { 
                _fitRecording1.setData(battVoltage);
                _fitRecording2.setData(capacity);
                _fitRecording3.setData(battVoltage * _data.FLdata[FL_loadCurrent] / 1000);
                _fitRecording4.setData(_data.FLdata[FL_battCurrent] / 1000.0);
            }

            return $.displayString;
    }

    //! switch device state, process the $FLx data, calculate and show values every one second
    //! @param info The updated Activity.Info object
    //! @return String value to display in the simpledatafield
    public function compute(info as Info) as Numeric or Duration or String or Null {

        // if we have recent data, we display and log it
        if ($.FLstate == FL_READY) {
            if (_data.tick <= _data.MAX_AGE_SEC) {
                $.displayString = computeDisplayString();
                _data.tick++; // increase data age seconds counter
            }
            else {      
                $.displayString = _datastale;
            }
        } else {
            _device.updateState($.FLstate);
            switch ($.FLstate) 
            {
                case FL_SEARCH:
                    $.displayString = _searching;
                    break;
                case FL_DISCONNECT:
                    $.displayString = _connecting;
                    break;
                }
        }
        return $.displayString;
    }

}