import Toybox.Lang;
import Toybox.Test;
import Toybox.Activity;

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


class DataManager {

    // types of forumslader data sentences
    enum {
        SENTENCE_OTHER = -1,
        SENTENCE_FL5, 
        SENTENCE_FL6,
        SENTENCE_FLB,
        SENTENCE_FLC,
        SENTENCE_FLP,
        SENTENCE_FLV,
    }

    public const 
        MAX_AGE_SEC = 8; // timeout in seconds for $FLx data, triggers "no data" on display
    
    private const 
        _sentenceType as Array<String> = ["FL5", "FL6", "FLB", "FLC", "FLP", "FLV"] as Array<String>,
        _MAX_TERM_SIZE = 30,  // max size of a term in a $FLx sentence (assumption, should be verified)
        _MAX_TERM_COUNT = 20; // max number of terms in a $FLx sentence (assumption, should be verified)

    public var
        tick as Number = MAX_AGE_SEC,
        FLdata as Array<Number> = new [FL_tablesize] as Array<Number>,
        cfgDone as Boolean = false;

    private var 
        _parity as Number = 0,
        _isChecksumTerm as Boolean = false,
        _currSentenceType as Number = SENTENCE_OTHER,
        _currTermNumber as Number = 0,
        _currTermOffset as Number = 0,
        _FLversion1 as String = "",
        _FLversion2 as String = "",
        _currTerm as String = "",
        _FLterm as Array<String> = new [_MAX_TERM_COUNT] as Array<String>;

    public function initialize() {
        for (var i = 0; i < FLdata.size(); i++) {
            FLdata[i] = -1;
        }
    }

    //! Interpretes payload of Forumslader char by char
    //! @param any part of a Forumslader $FLx data stream
    public function encode(sentence as ByteArray) as Void {

        var _size = sentence.size();

		for (var i = 0; i < _size; i++) {

            var b = sentence[i] as Number; // safe conversion to number from ByteArray
            var c = b.toChar();

            switch(c)
            {
            // end of term
            case ',': 
                //_parity ^= b;  /* we need a workaround here as long as SDK has XOR compiler error */
                _parity = _parity & ~b | ~_parity & b;
            case '\r':
            case '\n':
            case '*':
                if (_currTermOffset < _MAX_TERM_SIZE)
                {
                    parseTerm(_currTerm);
                }
                _currTermNumber++;
                _currTermOffset = 0;
                _currTerm = "";
                _isChecksumTerm = c == '*';
                break;

            // start of sentence
            case '$':
                _currSentenceType = SENTENCE_OTHER;
                _parity = 0;
                _currTermNumber = 0;
                _currTermOffset = 0;
                _currTerm = "";
                _isChecksumTerm = false;
                break;

             // payload (or noise)
            default:
                if (_currTermOffset < _MAX_TERM_SIZE - 1)
                {
                    _currTermOffset++;
                    _currTerm += c;
                }
                if (!_isChecksumTerm)
                {
                    //_parity ^= b;  /* we need a workaround here as long as SDK has XOR compiler error */
                    _parity = _parity & ~b | ~_parity & b;
                }
            }
        }
    }

    //! Processes a term of a $FLx sentence
    //! @param a term of a $FLx string
    private function parseTerm(term as String) as Void {

        // If it's the checksum term, and the checksum checks out, we commit all term values in the current sentence
        if (_isChecksumTerm)
        {
            if (term.toNumberWithBase(16) == _parity)
            {
                // we've got fresh and valid data, thus reset data age counter
                tick = 0;

                // parse and commit values according to sentence type
                switch(_currSentenceType)
                {
                    case SENTENCE_FL5:
                    case SENTENCE_FL6:
                        FLdata[FL_gear]             = commitValue(_FLterm[2], 0, 10);
                        FLdata[FL_frequency]        = commitValue(_FLterm[3], 0, 500);
                        FLdata[FL_battVoltage1]     = commitValue(_FLterm[4], 0, 5000);
                        FLdata[FL_battVoltage2]     = commitValue(_FLterm[5], 0, 5000);
                        FLdata[FL_battVoltage3]     = commitValue(_FLterm[6], 0, 5000);
                        FLdata[FL_battCurrent]      = commitValue(_FLterm[7], 0, 0);
                        FLdata[FL_loadCurrent]      = commitValue(_FLterm[8], 0, 0);
                        FLdata[FL_intTemp]          = commitValue(_FLterm[9], -50, 100);
                        break;

                    case SENTENCE_FLP:
                        FLdata[FL_wheelsize]        = commitValue(_FLterm[1], 1000, 2500);
                        FLdata[FL_poles]            = commitValue(_FLterm[2], 10, 20);
                        FLdata[FL_acc2mah]          = commitValue(_FLterm[8], 1, 10000);
                        cfgDone = true;
                        debug("Config Done (" + FLdata[FL_poles] + " poles @ " + FLdata[FL_wheelsize] + "mm wheel)");
                        break;

                    case SENTENCE_FLV:
                        _FLversion1                 = _FLterm[1];
                        _FLversion2                 = _FLterm[2];
                        debug("Forumslader v" + _FLversion1 + " BT" + _FLversion2);
                        break;

                    case SENTENCE_FLB:
                        FLdata[FL_temperature]      = commitValue(_FLterm[1], -300, 800);
                        FLdata[FL_pressure]         = commitValue(_FLterm[2], 0, 1200000);
                        FLdata[FL_sealevel]         = commitValue(_FLterm[3], -100, 10000);
                        FLdata[FL_incline]          = commitValue(_FLterm[4], 0, 0);
                        break;

                    case SENTENCE_FLC:
                        var _FLCsetnr = commitValue(_FLterm[1], 0, 5);
                        for (var i = 0; i < 5; i++) {
                            FLdata[FL_tourElevation + _FLCsetnr * 5 + i] = commitValue(_FLterm[i + 2], 0, 0);
                        }
                        break;
                } 
                return;
            }

            // invalid term
            else {
                debug ("Checksum error in $" + (_currSentenceType == SENTENCE_OTHER ? "FL?" : _sentenceType[_currSentenceType]));
            }

            return;
        }

        // the first term determines the sentence type
        if (_currTermNumber == 0) {
            _currSentenceType = _sentenceType.indexOf(term);
            return;
        }

        // split up sentence in single terms
        if (_currSentenceType != SENTENCE_OTHER && term != "") {
            _FLterm[_currTermNumber] = term;
            return;
        }
        
    } 

    // helper function to safely convert a string with unknown content to a number value
    public function commitValue(str as String, min as Number, max as Number) as Number {
        var v = str.toNumber();
        if (null == v) {
            return -1;
        }
        if (min != 0 && max != 0) {
            return (v >= min && v <= max) ? v : -1;
        }
        else {
            return v;
        }
    }

    (:test)
    public function parserTest(logger as Logger) as Boolean {    

        var _testDataSet = [
        "$FLB,240,102269,737,0*73",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,226,1217,3282,8873*5D",
        "$FLC,4,0,200,0,16,0*78",
        "$FLZ,4,0,200,0,16,0*61",
        "$FL5,00C000,0,0,3789,3788,3688,-7,0,296,1,225,1217,3282,8873*51",
        "$FLB,240,102280,728,0*7A",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,224,1217,3282,8873*5F",
        "$FLC,5,826,55,1386,31,33156710*4A",
        "$FL5,00C000,0,0,3789,3788,3688,-11,0,296,1,231,1217,3282,8873*63",
        "$FLB,240,102272,735,0*7B",
        "AT+SLEEP",
        "$FL5,00C000,0,0,3789,3789,3688,-12,0,296,1,230,1217,3282,8873*60",
        "$FLV,2003.500221217,5.51*5C",
        "$FLC,2,176240,-207,0,0,210*56",
        "$FL5,00C000,0,0,3788,3789,3689,-12,0,296,1,229,1217,3282,8873*68",
        "$FL5,00C000,0,0,3789,3788,3688,-11,0,296,1,231,1217,3282,8873*63",
        "AT+SLEEP",
        "$FLB,240,102272,735,0*7B",
        "$FL5,00C000,0,0,3789,3789,3688,-12,0,296,1,230,1217,3282,8873*60",
        "$FLV,2003.500221217,5.51*5C",
        "hdkshdadkölsfd",
        "$FLC,2,176240,-207,0,0,210*56",
        "$FL5,00C000,0,0,3788,3789,3689,-12,0,296,1,229,1217,3282,8873*68",
        "$FLB,240,102275,733,0*7A",
        "$FLP,2133,13,-800,13553,21749,13111,21063,407,60,0,104*5F",
        "$FL5,00C000,0,0,3788sdfdsgdgsfg,3789,3688,-8,0,296,1,228,1217,3282,8873*53",
        "$FLC,3,3545,3545,0,484,0*42",
        "$FL5,00C000,0,0,3789,3789,3688,-9,0,296,1,227,1217,3282,8873*5C",
        "$FLB,240,102269,737,0*73",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,226,1217,3282,8873*5D",
        "$FLC,4,0,200,0,16,0*78",
        "$FL5,00C000,0,0,3789,3788,3688,-7,0,296,1,225,1217,3282,8873*51",
        "$FLB,240,102280,728,0*7A",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,224,1217,3282,8873*5F",
        "$FLC,5,826,55,1386,31,33156710*4A",
        "$FL5,00C000,0,0,3789,3788,3688,-11,0,296,1,231,1217,3282,8873*63",
        "$FLB,240,102272,735,0*7B",
        "$FL5,00C000,0,0,3789,3789,3688,-12,0,296,1,230,1217,3282,8873*60",
        "$FL5,00C000,0,0,3789,3788,3688,-11,0,296,1,231,1217,3282,8873*63",
        "$FLB,240,102272,735,0*7B",
        "$FL5,00C000,0,0,3789,3789,3688,-12,0,296,1,230,1217,3282,8873*60",
        "$FLV,2003.500221217,5.51*5C",
        "$FLC,2,176240,-207,0,0,210*56",
        "$FL5,00C000,0,0,3788,3789,3689,-12,0,296,1,229,1217,3282,8873*68",
        "$FLB,240,102275,733,0*7A",
        "$FLP,2133,13,-800,13553,21749,13111,21063,407,60,0,104*5F",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,228,1217,3282,8873*53",
        "$FLC,3,3545,3545,0,484,0*42",
        "$FL5,00C000,0,0,3789,3789,3688,-9,0,296,1,227,1217,3282,8873*5C",
        "$FLB,240,102269,737,0*73",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,226,1217,3282,8873*5D",
        "$FLC,4,0,200,0,16,0*78",
        "$FL5,00C000,0,0,3789,3788,3688,-7,0,296,1,225,1217,3282,8873*51",
        "$FLB,240,102280,728,0*7A",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,224,1217,3282,8873*5F",
        "$FLC,5,826,55,1386,31,33156710*4A",
        "$FL5,00C000,0,0,3789,3788,3688,-11,0,296,1,231,1217,3282,8873*63",
        "$FLB,240,102272,735,0*7B",
        "$FL5,00C000,0,0,3789,3789,3688,-12,0,296,1,230,1217,3282,8873*60",
        "$FLC,2,176240,-207,0,0,210*56",
        "$FL5,00C000,0,0,3788,3789,3689,-12,0,296,1,229,1217,3282,8873*68",
        "$FLB,240,102275,733,0*7A",
        "$FLP,2133,13,-800,13553,21749,13111,21063,407,60,0,104*5F",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,228,1217,3282,8873*53",
        "$FLC,3,3545,3545,0,484,0*42",
        "$FL5,00C000,0,0,3789,3789,3688,-9,0,296,1,227,1217,3282,8873*5C",
        "$FL5,00C000,0,0,3789,3788,3688,-11,0,296,1,231,1217,3282,8873*63",
        "$FLB,240,102272,735,0*7B",
        "$FL5,00C000,0,0,3789,3789,3688,-12,0,296,1,230,1217,3282,8873*60",
        "$FLV,2003.500221217,5.51*5C",
        "$FLC,2,176240,-207,0,0,210*56",
        "$FL5,00C000,0,0,3788,3789,3689,-12,0,296,1,229,1217,3282,8873*68",
        "$FLB,240,102275,733,0*7A",
        "$FLP,2133,13,-800,13553,21749,13111,21063,407,60,0,104*5F",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,228,1217,3282,8873*53",
        "$FLC,3,3545,3545,0,484,0*42",
        "$FL5,00C000,0,0,3789,3789,3688,-9,0,296,1,227,1217,3282,8873*5C",
        "$FLB,240,102269,737,0*73",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,226,1217,3282,8873*5D",
        "$FLC,4,0,200,0,16,0*78",
        "$FL5,00C000,0,0,3789,3788,3688,-7,0,296,1,225,1217,3282,8873*51",
        "$FLB,240,102280,728,0*7A",
        "$FL5,00C000,0,0,3788,3789,3688,-8,0,296,1,224,1217,3282,8873*5F",
        "$FLC,5,826,55,1386,31,33156710*4A"] as Array<String>;

        isConnected = true;

        var _data = new $.DataManager();
        var _view = new $.ForumsladerView(_data as DataManager);

        try {
            Application.Properties.setValue("Item1", 10);
            Application.Properties.setValue("Item2", 3);
            Application.Properties.setValue("Item3", 6);
            Application.Properties.setValue("Item4", 9);
            Application.Properties.setValue("BatteryCalcMethod", true);
            Application.Properties.setValue("Item5", 10);
            Application.Properties.setValue("Item6", 3);
            Application.Properties.setValue("Item7", 6);
            Application.Properties.setValue("Item8", 9);
            Application.Properties.setValue("DataLogging", true);
            getUserSettings();
        }
        catch(exception) {
            return false;
        }

        for (var i = 0; i < _testDataSet.size(); i++) {
            debug(_testDataSet[i]);
            try {
        	    _data.encode((_testDataSet[i] + "\r\n").toUtf8Array() as ByteArray);
                _view.compute(Activity.Info as Info);
                debug(_view._displayString);
            }
            catch (exception) {
                return false;
            }
    	}
        return true;
    }

}