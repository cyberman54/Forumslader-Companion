import Toybox.Lang;
import Toybox.Activity;

// Verwendete Forumslader Datensätze
enum {
    // FL5/FL6 sentences
        FL_status, FL_gear, FL_frequency, FL_battVoltage1, FL_battVoltage2, FL_battVoltage3,
        FL_battCurrent, FL_loadCurrent, FL_impulseCounter, //FL_intTemp,
    // FLB sentence
        FL_temperature,
    // FLP sentence
        FL_wheelsize, FL_poles, FL_acc2mah,
    // FLC sentence
        FL_Energy, FL_tourEnergy, FL_tripEnergy, FL_BTsaveCount, FL_empty1,                 // set 3
        FL_startCount, FL_socState, FL_fullChargeCapacity, FL_cycleCount, FL_ccadcValue,    // set 5
    // Resultierende Größe des Daten-Arrays
    FL_tablesize
}

class DataManager {

    // Verwendete Datensatztypen des Forumsladers
    enum {
        SENTENCE_OTHER = -1,
        SENTENCE_FL5,
        SENTENCE_FL6,
        SENTENCE_FLB,
        SENTENCE_FLC,
        SENTENCE_FLP
    }

    public const
        MAX_AGE_SEC = 10; // Maximales Alter der Daten in Sekunden, bevor sie als veraltet gelten

    private const
        _sentenceType as Array<String> = ["FL5", "FL6", "FLB", "FLC", "FLP"] as Array<String>,
        _MAX_TERM_SIZE = 20, // Maximale Länge eines Terms im $FLx Datenstrom, um Pufferüberläufe zu vermeiden
        _MAX_TERM_COUNT = 16; // Maximale Anzahl von Terms in einem $FLx Satz, um ungültige Daten zu erkennen

    public var
        age as Number = MAX_AGE_SEC,
        FLdata as Array<Number> = new [FL_tablesize] as Array<Number>,
        freq2speed as Float = 0.0f,
        imp2odo as Double = 0.0d;

    private var
        _parity as Number = 0,
        _isChecksumTerm as Boolean = false,
        _currSentenceType as Number = SENTENCE_OTHER,
        _currTermNumber as Number = 0,
        _currTermOffset as Number = 0,
        _charBuffer as Array<Char> = new [_MAX_TERM_SIZE] as Array<Char>,
        _FLterm as Array<String> = new [_MAX_TERM_COUNT] as Array<String>;

    //! Konstruktor initialisiert das Datenfeld komplett genullt
    public function initialize() {
        var size = FLdata.size();
        for (var i = 0; i < size; i++) {
            FLdata[i] = 0;
        }
    }

    //! Interpretiert den $FLx Datenstrom des Forumsladers Byte für Byte
    public function encode(b as Number) as Void {
        var c = b.toChar();
        //debug(c);

        switch(c) {
            case ',':
                _parity ^= b;
                // Absichtlicher Fallthrough zur Term-Verarbeitung
            case '\r':
            case '*':
                if (_currTermOffset < _MAX_TERM_SIZE && _currTermNumber < _MAX_TERM_COUNT) {
                    var term = StringUtil.charArrayToString(_charBuffer.slice(0, _currTermOffset));
                    _FLterm[_currTermNumber] = term;
                    parseTerm(term);
                }
                _currTermNumber++;
                _currTermOffset = 0;
                _isChecksumTerm = (c == '*');
                break;

            case '$':
                _currSentenceType = SENTENCE_OTHER;
                _parity = 0;
                _currTermNumber = 0;
                _currTermOffset = 0;
                _isChecksumTerm = false;
                break;

            default:
                if (_currTermOffset < _MAX_TERM_SIZE - 1) {
                    _charBuffer[_currTermOffset] = c;
                    _currTermOffset++;
                }
                if (!_isChecksumTerm) {
                    _parity ^= b;
                }
                break;
        }
    }

    //! Validiert die Prüfsumme und aktualisiert die Datenfelder nur bei korrekten Werten, um Datenintegrität zu gewährleisten
    private function parseTerm(term as String) as Void {
        // Der erste Term indiziert den Telegramm-Typ ($FL5, $FLP etc.)
        if (_currTermNumber == 0) {
            _currSentenceType = SENTENCE_OTHER;
            for (var i = 0; i < 5; i++) {
                if (term.equals(_sentenceType[i])) {
                    _currSentenceType = i;
                    break;
                }
            }
            return;
        }

        // Validierung der Prüfsumme sichert Datenintegrität vor dem Speichern im Array
        if (_isChecksumTerm) {
            if (term.toNumberWithBase(16) == _parity) {
                age = 0; // Daten sind valide, Timeout-Zähler zurücksetzen

                var fl = FLdata; // Lokaler Cache-Zeiger verkürzt die VM-Adressierung
                var t = _FLterm;

                switch(_currSentenceType) {
                    case SENTENCE_FL5:
                    case SENTENCE_FL6:
                        var state = t[1].toNumberWithBase(16);
                        fl[FL_status] = (state != null) ? state : 0;
                        fl[FL_gear]             = commitValue(t[2], 0, 10);
                        fl[FL_frequency]        = commitValue(t[3], 0, 5000);
                        fl[FL_battVoltage1]     = commitValue(t[4], 0, 5000);
                        fl[FL_battVoltage2]     = commitValue(t[5], 0, 5000);
                        fl[FL_battVoltage3]     = commitValue(t[6], 0, 5000);
                        fl[FL_battCurrent]      = commitValue(t[7], -10000, 10000);
                        fl[FL_loadCurrent]      = commitValue(t[8], 0, 10000);
                        fl[FL_impulseCounter]   = commitValue(t[$.isV6 ? 12 : 13], 0, 0);
                        break;

                    case SENTENCE_FLB:
                        fl[FL_temperature]      = commitValue(t[1], -300, 800);
                        break;

                    case SENTENCE_FLC: {
                        var _FLCsetnr = commitValue(t[1], 0, 5);
                        var _offset = 0;
                        if (_FLCsetnr == 3) {
                            _offset = FL_Energy;
                        } else if (_FLCsetnr == 5) {
                            _offset = FL_startCount;
                        } else {
                            break;
                        }

                        for (var i = 0; i < 5; i++) {
                            fl[_offset + i] = commitValue(t[i + 2], 0, 0);
                        }
                        break;
                    }

                    case SENTENCE_FLP: {
                        fl[FL_wheelsize]        = commitValue(t[1], 1000, 2500);
                        fl[FL_poles]            = commitValue(t[2], 10, 20);
                        fl[FL_acc2mah]          = commitValue(t[8], 1, 10000);

                        var wSize = fl[FL_wheelsize];
                        var poles = fl[FL_poles];

                        if (wSize > 0 && poles > 0) {
                            var wSizeFloat = wSize.toFloat();
                            var polesFloat = poles.toFloat();
                            freq2speed = wSizeFloat / polesFloat * 0.0036f / ($.isV6 ? 10.0f : 1.0f) * $.speedunitFactor.toFloat();
                            imp2odo = wSize.toDouble() / poles.toDouble() / 1000000.0d * ($.isV6 ? 1.0d : 4096.0d) * $.speedunitFactor.toDouble();
                        } else {
                            freq2speed = 0.0f;
                            imp2odo = 0.0d;
                        }
                        debug(poles + " poles, " + wSize + "mm wheelsize");
                        break;
                    }
                }
            } else {
                // invalid term or checksum error, ignore sentence and log error
                debug("\nChecksum error" + (_currSentenceType == SENTENCE_OTHER ? "" : "in $" + _sentenceType[_currSentenceType]));
            }
        }
    }

    //! Parst, validiert und begrenzt numerische Rohwerte defensiv
    private function commitValue(term as String, min as Number, max as Number) as Number {
        if (term == null || term.length() == 0) {
            return 0;
        }
        var val = term.toNumber();
        if (val == null) {
            return 0;
        }
        if (min != 0 || max != 0) {
            if (val < min || val > max) {
                return 0;
            }
        }
        return val;
    }
}

