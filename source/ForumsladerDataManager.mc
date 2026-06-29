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
        FL_wheelsize, FL_poles, FL_acc2mah, FL_dayPulseOffset, FL_tourPulseOffset,
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
        _MAX_TERM_SIZE = 20, // Maximale Länge eines Terms im $FLx Datenstrom, um Pufferüberläufe zu vermeiden
        _MAX_TERM_LAST = _MAX_TERM_SIZE - 1,
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
    // Parst die Terms, validiert die Prüfsumme und aktualisiert die Datenfelder nur bei korrekten Werten, um Datenintegrität zu gewährleisten
    // Code ist performance optimiert mit minimalen String-Operationen und defensiven Checks, um Stabilität bei ungültigen Daten zu gewährleisten
    public function encode(b as Number) as Void {
        var c = b.toChar();
        //debug(c);

        switch(c) {
            case ',': // Term-Trenner, Parity mit Trenner-Byte aktualisieren
                _parity ^= b;
                // Absichtlicher Fallthrough zur Term-Verarbeitung
            case '\r':
            case '*': // Ende eines Terms, Term-Nummer und Offset für nächsten Term aktualisieren
                var termNumber = _currTermNumber;
                var isChecksum = _isChecksumTerm;
                var termOffset = _currTermOffset;

                if (termNumber < _MAX_TERM_COUNT) {
                    if (termNumber == 0) {
                        parseSentenceType();
                    } else if (isChecksum) {
                        var term = (termOffset == 0)
                            ? ""
                            : StringUtil.charArrayToString(_charBuffer.slice(0, termOffset));
                        parseChecksumTerm(term);
                    } else {
                        _FLterm[termNumber] = (termOffset == 0)
                            ? ""
                            : StringUtil.charArrayToString(_charBuffer.slice(0, termOffset));
                    }
                }
                _currTermNumber = termNumber + 1;
                _currTermOffset = 0;
                _isChecksumTerm = (c == '*');
                break;

            case '$': // Start eines neuen Satzes, alle Zustände zurücksetzen
                _currSentenceType = SENTENCE_OTHER;
                _parity = 0;
                _currTermNumber = 0;
                _currTermOffset = 0;
                _isChecksumTerm = false;
                break;

            default: // Payload, in den aktuellen Term-Puffer schreiben, Parity aktualisieren
                if (_currTermOffset < _MAX_TERM_LAST) {
                    _charBuffer[_currTermOffset] = c;
                    _currTermOffset++;
                }
                if (!_isChecksumTerm) {
                    _parity ^= b;
                }
                break;
        }
    }

    //! Der erste Term indiziert den Telegramm-Typ ($FL5, $FLP etc.)
    private function parseSentenceType() as Void {
        if (_currTermOffset != 3 || _charBuffer[0] != 'F' || _charBuffer[1] != 'L') {
            _currSentenceType = SENTENCE_OTHER;
            return;
        }

        switch (_charBuffer[2]) {
            case '5':
                _currSentenceType = SENTENCE_FL5;
                break;
            case '6':
                _currSentenceType = SENTENCE_FL6;
                break;
            case 'B':
                _currSentenceType = SENTENCE_FLB;
                break;
            case 'C':
                _currSentenceType = SENTENCE_FLC;
                break;
            case 'P':
                _currSentenceType = SENTENCE_FLP;
                break;
            default:
                _currSentenceType = SENTENCE_OTHER;
                break;
        }
    }

    //! Validiert die Prüfsumme und aktualisiert die Datenfelder nur bei korrekten Werten, um Datenintegrität zu gewährleisten
    private function parseChecksumTerm(term as String) as Void {
        if (_currSentenceType == SENTENCE_OTHER) {
            return; // Unbekannter/fremder Satztyp, still verwerfen
        }
        var checksum = term.toNumberWithBase(16);
        if (checksum == null || checksum != _parity) {
            // Prüfsummenfehler bei einem bekannten $FL-Satz
            debug("\nChecksum error");
            return;
        }

        age = 0; // Daten sind frisch, Alter zurücksetzen

        var fl = FLdata; // Lokaler Cache-Zeiger für Daten verkürzt die VM-Adressierung
        var t = _FLterm; // Lokaler Cache-Zeiger für Terms verkürzt die VM-Adressierung
        var isV6 = $.isV6;  // Unterschiedliche Dateninterpretation und Skalierung zwischen FL5 und FL6, abhängig von der Firmware-Version des Forumsladers
        var speedDivisor = isV6 ? 10.0f : 1.0f;
        var impulseScale = isV6 ? 1.0d : 4096.0d;
        var speedUnitFactor = $.speedunitFactor;

        switch(_currSentenceType) {
            case SENTENCE_FL5:
            case SENTENCE_FL6:
                var t1 = t[1], t2 = t[2], t3 = t[3], t4 = t[4], t5 = t[5], t6 = t[6], t7 = t[7], t8 = t[8];
                var tImpulse = t[isV6 ? 12 : 13];
                var state = t1.toNumberWithBase(16);
                fl[FL_status] = (state != null) ? state : 0;
                fl[FL_gear]             = commitValue(t2, 0, 10);
                fl[FL_frequency]        = commitValue(t3, 0, 5000);
                fl[FL_battVoltage1]     = commitValue(t4, 0, 5000);
                fl[FL_battVoltage2]     = commitValue(t5, 0, 5000);
                fl[FL_battVoltage3]     = commitValue(t6, 0, 5000);
                fl[FL_battCurrent]      = commitValue(t7, -10000, 10000);
                fl[FL_loadCurrent]      = commitValue(t8, 0, 10000);
                fl[FL_impulseCounter]   = parseValue(tImpulse);
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

                fl[_offset] = parseValue(t[2]);
                fl[_offset + 1] = parseValue(t[3]);
                fl[_offset + 2] = parseValue(t[4]);
                fl[_offset + 3] = parseValue(t[5]);
                fl[_offset + 4] = parseValue(t[6]);
                break;
            }

            case SENTENCE_FLP: {
                fl[FL_wheelsize]        = commitValue(t[1], 1000, 2500); // Radumfang in mm
                fl[FL_poles]            = commitValue(t[2], 10, 20); // Anzahl der Magnete im Dynamo
                fl[FL_dayPulseOffset]   = parseValue(t[4]);   // Impulszähler-Startwert Tages-km
                fl[FL_tourPulseOffset]  = parseValue(t[6]);   // Impulszähler-Startwert Tour-km
                fl[FL_acc2mah]          = commitValue(t[8], 1, 10000);

                var wSize = fl[FL_wheelsize];
                var poles = fl[FL_poles];

                if (wSize > 0 && poles > 0) {
                    var wSizeFloat = wSize.toFloat();
                    var polesFloat = poles.toFloat();
                    var speedUnitFactorF = speedUnitFactor.toFloat();
                    var speedUnitFactorD = speedUnitFactor.toDouble();
                    freq2speed = wSizeFloat / polesFloat * 0.0036f / speedDivisor * speedUnitFactorF;
                    imp2odo = wSize.toDouble() / poles.toDouble() / 1000000.0d * impulseScale * speedUnitFactorD;
                } else {
                    freq2speed = 0.0f;
                    imp2odo = 0.0d;
                }
                debug(poles + " poles, " + wSize + "mm wheelsize");
                break;
            }
        }
    }

    //! Schneller Parse-Pfad ohne Range-Checks (für Felder ohne min/max Begrenzung)
    private function parseValue(term as String) as Number {
        if (term == null || term.length() == 0) {
            return 0;
        }
        var val = term.toNumber();
        if (val == null) {
            return 0;
        }
        return val;
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
        if (val < min || val > max) {
            return 0;
        }
        return val;
    }
}

