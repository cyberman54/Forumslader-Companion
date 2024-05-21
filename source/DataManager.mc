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
        SENTENCE_FLP
    }

    public const 
        MAX_AGE_SEC = 3; // timeout in seconds for $FLx data
    
    private const 
        _sentenceType as Array<String> = ["FL5", "FL6", "FLB", "FLC", "FLP"] as Array<String>,
        _MAX_TERM_SIZE = 30,  // max size of a term in a $FLx sentence (assumption, should be verified)
        _MAX_TERM_COUNT = 20; // max number of terms in a $FLx sentence (assumption, should be verified)

    public var
        tick as Number = MAX_AGE_SEC,
        FLdata as Array<Number> = new [FL_tablesize] as Array<Number>,
        FLpayload as ByteArray = []b;

    private var 
        _parity as Number = 0,
        _isChecksumTerm as Boolean = false,
        _currSentenceType as Number = SENTENCE_OTHER,
        _currTermNumber as Number = 0,
        _currTermOffset as Number = 0,
        _currTerm as String = "",
        _FLterm as Array<String> = new [_MAX_TERM_COUNT] as Array<String>;

    //! Constructor
    public function initialize() {
        for (var i = 0; i < FLdata.size(); i++) {
            FLdata[i] = -1;
        }
    }

    //! Interpretes $FLx data stream of Forumslader char by char
    //! @param none
    public function encode() as Void {

        //debug(FLpayload.toString());
        var _size = FLpayload.size();

		for (var i = 0; i < _size; i++) {

            var b = FLpayload[i] as Number; // safe conversion to number from ByteArray
            var c = b.toChar();

            switch(c)
            {
            // end of term
            case ',': 
                _parity ^= b;
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
                    _parity ^= b;
                }
            }
        }
        FLpayload = []b; // clear buffer
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

                    case SENTENCE_FLP:
                        FLdata[FL_wheelsize]        = commitValue(_FLterm[1], 1000, 2500);
                        FLdata[FL_poles]            = commitValue(_FLterm[2], 10, 20);
                        FLdata[FL_acc2mah]          = commitValue(_FLterm[8], 1, 10000);
                        //debug(FLdata[FL_poles] + " poles, " + FLdata[FL_wheelsize] + "mm wheelsize");
                        break;
                } 
                return;
            }

            // invalid term
            else {
                //debug ("Checksum error" + (_currSentenceType == SENTENCE_OTHER ? "" : "in $" + _sentenceType[_currSentenceType]));
            }

            return;
        }

        // split up sentence in terms and store them in string array
        if (_currSentenceType != SENTENCE_OTHER) {
            _FLterm[_currTermNumber] = term;
            return;
        }

        // the first term determines the sentence type
        if (_currTermNumber == 0) {
            _currSentenceType = _sentenceType.indexOf(term);
            return;
        }
    } 

    //! helper function to safely convert a string with unknown content to a number value
    //! @param string to be converted to a number valus, min as lower corner, max as higher corner
    //! @return a Number if string was converted successfully, otherwise -1
    public function commitValue(str as String, min as Number, max as Number) as Number {
        var v = str.toNumber();
        if (null == v) {
            return -1;
        }
        if (min == 0 && max == 0) {
            return v;
        } else {
            return (v >= min && v <= max) ? v : -1;
        }
    }
}