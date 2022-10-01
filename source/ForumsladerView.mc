import Toybox.Activity;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

class ForumsladerView extends WatchUi.SimpleDataField {

    public var
        _displayString as String = "";

    private var 
        _data as DataManager,
        _speed as Float = 0.0,       // calculated field from dynamo pulses, poles and wheelsize
        _battVoltage as Float = 0.0, // calculated field from cell voltages
        _connecting as String,
        _initializing as String,
        _loadingdata as String,
        _fitRecording as FitContributor.Field; // fit recording contributor

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager) {
        SimpleDataField.initialize();
        getUserSettings();
        label = "Forumslader";
        _data = dataManager;
        _connecting = WatchUi.loadResource($.Rez.Strings.connecting) as String;
        _initializing = WatchUi.loadResource($.Rez.Strings.initializing) as String;
        _loadingdata =  WatchUi.loadResource($.Rez.Strings.loadingdata) as String;
        _displayString = _initializing;

        // Create the custom FIT data field we want to record
        _fitRecording = createField(
            "Forumslader", 0, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType=>FitContributor.MESG_TYPE_RECORD, :units=>"FL"}
        ) as FitContributor.Field;
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
                var freq = isV6 ? _data.FLdata[FL_frequency] / 10 : _data.FLdata[FL_frequency];

                // display user selected values
                for (var i = 0; i < userSettings.size() / 2 - 1; i++)
                {  
                    _displayString += (_displayString.length() > 0) ? " " : "";
                    
                    switch (userSettings[i] as Number)
                    {
                        case 1: // trip energy
                            _displayString += (_data.FLdata[FL_tripEnergy] >= 0) ? _data.FLdata[FL_tripEnergy] : "--";
                            _displayString += "Wh";
                            break;

                        case 2: // temperature
                            _displayString += (_data.FLdata[FL_temperature] / 10.0).format("%.1f");
                            _displayString += "°C";
                            break;

                        case 3: // dynamo power
                            _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
                            _displayString += (_data.FLdata[FL_frequency] > 0) ? (_battVoltage * _data.FLdata[FL_loadCurrent] / 1000).toNumber() : "0";
                            _displayString += "W";
                            break;

                        case 4: // generator gear
                            _displayString += (_data.FLdata[FL_gear] >= 0) ? _data.FLdata[FL_gear] : "--";
                            break;

                        case 5: // dynamo impulse frequency
                            _displayString += freq >= 0 ? freq.toNumber() : "--";
                            _displayString += "Hz";
                            break;

                        case 6: // battery voltage
                            _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
                            _displayString += (_battVoltage > 0) ? _battVoltage.format("%.1f") : "--";
                            _displayString += "V";
                            break;

                        case 7: // battery current
                            _displayString += (_data.FLdata[FL_battCurrent] / 1000.0).format("%+.1f");
                            _displayString += "A";
                            break;

                        case 8: // load current
                            _displayString += (_data.FLdata[FL_loadCurrent] >= 0) ? (_data.FLdata[FL_loadCurrent] / 1000.0).format("%.1f") : "--";
                            _displayString += "A";
                            break;

                        case 9: // speed
                            if (_data.FLdata[FL_poles] > 0) {
                                _speed = freq / _data.FLdata[FL_poles] * _data.FLdata[FL_wheelsize] / 277.777;
                                _displayString += _speed.toNumber();
                            } else {
                                _displayString += "--";    
                            }
                            _displayString += "km/h";
                            break;

                        case 10: // remaining battery capacity
                            var _capacity = 0;
                            if (userSettings[4] == true) { // use coloumb calculation method
                                var x1 = (_data.FLdata[FL_ccadcValue].toLong() * _data.FLdata[FL_acc2mah].toLong() / 167772.16).toFloat();
                                var x2 = _data.FLdata[FL_fullChargeCapacity];
                                _capacity = (x1 / x2).toNumber();
                            } else { // use voltage calculation method
                                _capacity = _data.FLdata[FL_socState]; 
                            }
                            _displayString += (_capacity > 0) ? _capacity : "--";
                            _displayString += "%";
                            break;

                        default: // off
                        break;
                    }
                }

                // log user selected values
                if (userSettings[9] == true) {
                    for (var i = userSettings.size() / 2; i < userSettings.size() - 1; i++)
                    {  
                        switch (userSettings[i] as Number)
                        {
                            case 1: // trip energy
                                _fitRecording.setData(_data.FLdata[FL_tripEnergy]);
                                break;

                            case 2: // temperature
                                _fitRecording.setData(_data.FLdata[FL_temperature] / 10.0);
                                break;

                            case 3: // dynamo power
                                _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
                                _fitRecording.setData(_battVoltage * _data.FLdata[FL_loadCurrent] / 1000);
                                break;

                            case 4: // generator gear
                                _fitRecording.setData(_data.FLdata[FL_gear]);
                                break;

                            case 5: // dynamo impulse frequency
                                _fitRecording.setData(freq);
                                break;

                            case 6: // battery voltage
                                _battVoltage = (_data.FLdata[FL_battVoltage1] + _data.FLdata[FL_battVoltage2] + _data.FLdata[FL_battVoltage3]) / 1000.0;
                                _fitRecording.setData(_battVoltage);
                                break;

                            case 7: // battery current
                                _fitRecording.setData(_data.FLdata[FL_battCurrent] / 1000.0);
                                break;

                            case 8: // load current
                                _fitRecording.setData(_data.FLdata[FL_loadCurrent]);
                                break;

                            case 9: // speed
                                if (_data.FLdata[FL_poles] > 0) {
                                    _fitRecording.setData(freq / _data.FLdata[FL_poles] * _data.FLdata[FL_wheelsize] / 277.777);
                                }
                                break;

                            case 10: // remaining battery capacity
                                var _capacity = 0;
                                if (userSettings[4] == true) { // use coloumb calculation method
                                    var x1 = (_data.FLdata[FL_ccadcValue].toLong() * _data.FLdata[FL_acc2mah].toLong() / 167772.16).toFloat();
                                    var x2 = _data.FLdata[FL_fullChargeCapacity];
                                    _capacity = (x1 / x2).toNumber();
                                } else { // use voltage calculation method
                                    _capacity = _data.FLdata[FL_socState]; 
                                }
                                _fitRecording.setData(_capacity);
                                break;

                            default: // off
                            break;
                        }
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
}