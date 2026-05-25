import Toybox.Lang;
import Toybox.Activity;

// forumslader data fields
enum {
    // FL5/6 sentence
    FL_status, FL_gear, FL_frequency, FL_battVoltage1, FL_battVoltage2, FL_battVoltage3,
    FL_battCurrent, FL_loadCurrent, FL_impulseCounter, //FL_intTemp,

    // FLB sentence
    FL_temperature, //FL_pressure, FL_sealevel, FL_incline,

    // FLP sentence
    FL_wheelsize, FL_poles, FL_acc2mah,

    // FLC sentence
    //FL_tourElevation, FL_tourInclineMax, FL_tourTempMax, FL_tourAltitudeMax, FL_tourPulseMax,   // set 0
    //FL_tripElevation, FL_tripInclineMax, FL_tripTempMax, FL_tripAltitudeMax, FL_tripPulseMax,   // set 1
    //FL_Elevation, FL_tourInclineMin, FL_tourTempMin, FL_tripInclineMin, FL_tripTempMin,         // set 2
    FL_Energy, FL_tourEnergy, FL_tripEnergy, FL_BTsaveCount, FL_empty1,                           // set 3
    //FL_tripSpeedAvg, FL_tourSpeedAvg, FL_tripClimbAvg, FL_tourClimbAvg, FL_empty2,              // set 4
    FL_startCount, FL_socState, FL_fullChargeCapacity, FL_cycleCount, FL_ccadcValue,              // set 5
    
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
        MAX_AGE_SEC = 10; // Maximales Alter der Daten in Sekunden, bevor sie als veraltet gelten

    private const 
        _sentenceType as Array<String> = ["FL5", "FL6", "FLB", "FLC", "FLP"] as Array<String>, // Erkennung der Satztypen anhand des ersten Terms
        _MAX_TERM_SIZE = 30,  // Maximale Länge eines Terms, um Pufferüberläufe zu verhindern
        _MAX_TERM_COUNT = 20; // Maximale Anzahl von Terms pro Satz, um Array-Überläufe zu verhindern

    public var
        age as Number = MAX_AGE_SEC,                    // Alter der Daten in Sekunden, wird bei erfolgreichem Empfang eines vollständigen Satzes auf 0 zurückgesetzt
        FLdata as Array<Number> = new [FL_tablesize] as Array<Number>,          // Array zur Speicherung der aktuellen Werte der Forumslader-Datenfelder
        freq2speed as Float = 0.0,                      // Umrechnung von Trittfrequenz zu Geschwindigkeit (abhängig von Radgröße und Polzahl)
        imp2odo as Double = 0.0d;                       // Umrechnung von Impulsen zu zurückgelegter Strecke (abhängig von Radgröße und Polzahl)

    private var 
        _parity as Number = 0,                          // Parity-Check für die Überprüfung der Datenintegrität, wird byteweise mit XOR berechnet
        _isChecksumTerm as Boolean = false,             // Flag, um zu erkennen, ob der aktuelle Term der Checksum-Term ist (beginnt mit '*')
        _currSentenceType as Number = SENTENCE_OTHER,   // Aktueller Satztyp, wird anhand des ersten Terms eines Satzes bestimmt
        _currTermNumber as Number = 0,                  // Nummer des aktuellen Terms im Satz, beginnt bei 0 für den ersten Term
        _currTermOffset as Number = 0,                  // Aktuelle Position im Term-Puffer, um die Länge des Terms zu verfolgen und Pufferüberläufe zu verhindern
        _currTermBuffer as Array<Char> = new [_MAX_TERM_SIZE] as Array<Char>,   // Puffer zur Speicherung der Zeichen eines Terms, wird byteweise gefüllt und erst am Ende des Terms in einen String umgewandelt
        _FLterm as Array<String> = new [_MAX_TERM_COUNT] as Array<String>;      // Array zur Speicherung der Terms eines Satzes, wird bei jedem Term-Ende aktualisiert und für die Datenextraktion verwendet

    //! Constructor
    public function initialize() {
        var k = FLdata.size();
        for (var i = 0; i < k; i++) {
            FLdata[i] = 0;
        }
    }

    //! Interpretes $FLx data stream of Forumslader byte by byte
    //! Highly optimized for streaming input to prevent Garbage Collection spikes
    public function encode(b as Number) as Void {
        var c = b.toChar();

        switch(c) {
            // Term-Separator oder Satzende
            case ',': 
                _parity ^= b;
            case '\r':
            case '*':
                if (_currTermOffset < _MAX_TERM_SIZE) {
                    // Wandelt das Char-Array erst beim Term-Ende in einen String um
                    var term = StringUtil.charArrayToString(_currTermBuffer.slice(0, _currTermOffset));
                    if (_currTermNumber < _MAX_TERM_COUNT) {
                        _FLterm[_currTermNumber] = term;
                    }
                    parseTerm(term);
                }
                _currTermNumber++;
                _currTermOffset = 0;
                _isChecksumTerm = (c == '*');
                break;

            // Satzbeginn
            case '$':
                _currSentenceType = SENTENCE_OTHER;
                _parity = 0;
                _currTermNumber = 0;
                _currTermOffset = 0;
                _isChecksumTerm = false;
                break;

            // Alle anderen Zeichen werden in den Term-Puffer geschrieben, solange die maximale Termgröße nicht überschritten wird
            default:
                if (_currTermOffset < _MAX_TERM_SIZE - 1) {
                    _currTermBuffer[_currTermOffset] = c;
                    _currTermOffset++;
                }
                if (!_isChecksumTerm) {
                    _parity ^= b;
                }
                break;
        }
    }

    //! Processes a term of a $FLx sentence
    private function parseTerm(term as String) as Void {
        // Erstes Term bestimmt den Satz-Typ
        if (_currTermNumber == 0) {
            _currSentenceType = SENTENCE_OTHER;
            for (var i = 0; i < _sentenceType.size(); i++) {
                if (term.equals(_sentenceType[i])) {
                    _currSentenceType = i;
                    break;
                }
            }
            return;
        }
        // Wenn der aktuelle Term der Checksum-Term ist, wird die Parity-Check durchgeführt und bei Erfolg die Daten extrahiert
        if (_isChecksumTerm) {
            if (term.toNumberWithBase(16) == _parity) {
                age = 0; // Frische Daten, Timeout zurücksetzen
                var fl = FLdata; // Lokaler Cache für schnelleren Array-Zugriff
                var terms = _FLterm;

                switch(_currSentenceType) {
                    case SENTENCE_FL5:
                    case SENTENCE_FL6:
                        var state = terms[1].toNumberWithBase(16);
                        fl[FL_status] = (state != null) ? state : 0;
                        fl[FL_gear]             = commitValue(terms[2], 0, 10);       
                        fl[FL_frequency]        = commitValue(terms[3], 0, 5000);     
                        fl[FL_battVoltage1]     = commitValue(terms[4], 0, 5000);     
                        fl[FL_battVoltage2]     = commitValue(terms[5], 0, 5000);     
                        fl[FL_battVoltage3]     = commitValue(terms[6], 0, 5000);     
                        fl[FL_battCurrent]      = commitValue(terms[7], -10000, 10000);  
                        fl[FL_loadCurrent]      = commitValue(terms[8], 0, 10000);    
                        fl[FL_impulseCounter]   = commitValue(terms[$.isV6 ? 12 : 13], 0, 0);  
                        break;

                    case SENTENCE_FLB:
                        fl[FL_temperature]      = commitValue(terms[1], -300, 800);   
                        break;

                    case SENTENCE_FLC: {
                        var _FLCsetnr = commitValue(terms[1], 0, 5);  
                        var _offset = 0;
                        if (_FLCsetnr == 3) { 
                            _offset = FL_Energy; 
                        } else if (_FLCsetnr == 5) { 
                            _offset = FL_startCount; 
                        } else { 
                            break; 
                        }

                        for (var i = 0; i < 5; i++) {
                            fl[_offset + i] = commitValue(terms[i + 2], 0, 0);
                        }
                        break;
                    }

                    case SENTENCE_FLP:
                        fl[FL_wheelsize] = commitValue(terms[1], 1000, 2500);
                        fl[FL_poles]     = commitValue(terms[2], 10, 20);
                        fl[FL_acc2mah]   = commitValue(terms[8], 1, 10000);
                        
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
                        break;
                }
            }
        }
    }

    // Verwendet bei der Datenextraktion, um ungültige Werte (nicht-numerisch oder außerhalb von sinnvollen Bereichen) auf 0 zu setzen, um die Stabilität der Anwendung zu gewährleisten
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
