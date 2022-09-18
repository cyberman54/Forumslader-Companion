import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;

class ForumsladerView extends WatchUi.SimpleDataField {

    public var
        _displayString as String = "";

    private var 
        _data as DataManager,
        _showList as Array<Number> = [0, 0, 0, 0] as Array<Number>,  // 4 out of 10 fields to show
        _coloumbCalc as Boolean = true,
        _speed as Float = 0.0,       // calculated field from dynamo pulses, poles and wheelsize
        _battVoltage as Float = 0.0, // calculated field from cell voltages
        _connecting as String,
        _initializing as String,
        _loadingdata as String;

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager) {
        SimpleDataField.initialize();
        label = "Forumslader";
        _data = dataManager;
        _connecting = WatchUi.loadResource($.Rez.Strings.connecting) as String;
        _initializing = WatchUi.loadResource($.Rez.Strings.initializing) as String;
        _loadingdata =  WatchUi.loadResource($.Rez.Strings.loadingdata) as String;
        _displayString = _initializing;
        getUserSettings();
    }

    //! process the $FLx data, calculate and show values every one second
    //! @param info The updated Activity.Info object
    //! @return String value to display in the simpledatafield
    public function compute(info as Info) as Numeric or Duration or String or Null {
        
        _data.tick++;    // increase data age seconds counter

        if (!isConnected){
            _displayString = _connecting;
        }
        else
        {
            // we have recent data, thus we display the values        
            if (_data.tick <= _data.MAX_AGE_SEC) {

                _displayString = "";

                for (var i=0; i < _showList.size(); i++)
                {  
                    _displayString += (_displayString.length() > 0) ? " " : "";
                    
                    switch (_showList[i])
                    {
                        case 1: // trip energy
                            _displayString += (_data.FLdata[FL_tripEnergy] >= 0) ? _data.FLdata[FL_tripEnergy] + "Wh" : "--";
                            break;

                        case 2: // temperature
                            _displayString += (_data.FLdata[FL_temperature] / 10.0).format("%.1f") + "°C";
                            break;

                        case 3: // dynamo power
                            _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
                            _displayString += (_data.FLdata[FL_frequency] > 0) ? (_battVoltage * _data.FLdata[FL_loadCurrent] / 1000).toNumber() + "W" : "0W";
                            break;

                        case 4: // generator gear
                            _displayString += (_data.FLdata[FL_gear] >= 0) ? _data.FLdata[FL_gear] : "--";
                            break;

                        case 5: // dynamo frequency
                            _displayString += (_data.FLdata[FL_frequency] >= 0) ? _data.FLdata[FL_frequency] + "Hz" : "--";
                            break;

                        case 6: // battery voltage
                            _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
                            _displayString += (_battVoltage > 0) ? _battVoltage.format("%.1f") + "V" : "--";
                            break;

                        case 7: // battery current
                            _displayString += (_data.FLdata[FL_battCurrent] / 1000.0).format("%+.1f") + "A";
                            break;

                        case 8: // load current
                            _displayString += (_data.FLdata[FL_loadCurrent] >= 0) ? (_data.FLdata[FL_loadCurrent] / 1000.0).format("%.1f") + "A" : "--";
                            break;

                        case 9: // speed
                            _speed = _data.FLdata[FL_frequency] / _data.FLdata[FL_poles] * _data.FLdata[FL_wheelsize] / 277.777;
                            _displayString += (_data.FLdata[FL_poles] > 0) ? _speed.format("%.1f") + "km/h" : "--";
                            break;

                        case 10: // remaining battery capacity
                            var _capacity = 0;
                            if (_coloumbCalc) {
                                var x1 = (_data.FLdata[FL_ccadcValue].toLong() * _data.FLdata[FL_acc2mah].toLong() / 167772.16).toFloat();
                                var x2 = _data.FLdata[FL_fullChargeCapacity];
                                _capacity = (x1 / x2).toNumber();
                            } else {
                                _capacity = _data.FLdata[FL_socState]; 
                            }
                            _displayString += (_capacity > 0) ? _capacity + "%" : "--";
                            break;

                        default: // off
                        break;
                    }
                }
            }
        
            // we don't have recent data
            else 
            {
                // maybe to come: do we want some action for connection handling here?
                _displayString = _loadingdata;
            }
        }
  
        return _displayString;
    }

    //! Called by app when user made changes to settings in GCM while App is running
    public function onSettingsChanged() as Void {
        getUserSettings();
    }

    // Safely read a number value from user settings
    private function propertiesGetNumber(p as String) as Number {
        var v = Application.Properties.getValue(p);
        if ((v == null) || (v instanceof Boolean))
        {
            v = 0;
        }
        else if (!(v instanceof Number))
        {
            v = v as Number;
            if (v == null)
            {
                v = 0;
            }
        }
        return v as Number;
    }

    // Safely read a boolean value from user settings
    public function propertiesGetBoolean(p as String) as Boolean {
        var v = Application.Properties.getValue(p);
        if ((v == null) || !(v instanceof Boolean))
        {
            v = false;
        }
        return v as Boolean;
    }

    // read the user settings and store locally
    public function getUserSettings() as Void {
        _showList[0] = propertiesGetNumber("Item1");
    	_showList[1] = propertiesGetNumber("Item2");
    	_showList[2] = propertiesGetNumber("Item3");
        _showList[3] = propertiesGetNumber("Item4");
        debug("Selected items: " + _showList.toString());
        _coloumbCalc = propertiesGetBoolean("BatteryCalcMethod");
    }

}