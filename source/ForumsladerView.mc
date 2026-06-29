import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

class ForumsladerView extends DataField {

    private const
        _alertLockTime as Number = 100,     // Sperrzeit in Sekunden nach Alarm-Auslösung
        _capacityAlarmMin as Number = 20,   // Warnung unter 20% Kapazität
        _capacityAlarmMax as Number = 28;   // Entwarnung/Reset erst ab 28% (Hystereseschutz)

    private var
        _data as DataManager,               // Reference to the DataManager for accessing Forumslader data
        _device as DeviceManager,           // Reference to the DeviceManager for accessing Forumslader device state
        _battVoltage as Float,              //  Current battery voltage, calculated from raw sensor values
        _capacity as Number,                //  Current battery capacity in %, calculated from either coulomb counting or voltage method based on user settings
        _index as Number,                   //  Index for rotating display fields
        _alertMute as Number,               //  Counter to mute alarms for a certain time after they are triggered
        _capacityAlertLock as Boolean,      //  Lock to prevent repeated triggering of battery low alarm until capacity recovers
        _fitFieldsInitialized as Boolean,   //  Tracks if FIT fields have been created for current settings
        _fitRecording1 as Field?,           //  References to FIT recording fields for up to 4 user-selectable values (null if not enabled)
        _fitRecording2 as Field?,           //  These fields are created dynamically based on user settings when FitLogging is enabled
        _fitRecording3 as Field?,
        _fitRecording4 as Field?,
        _fitSetting1 as Number,             //  Currently active FIT setting for up to 4 user-selectable values (0 if disabled)
        _fitSetting2 as Number,             
        _fitSetting3 as Number,             
        _fitSetting4 as Number,             
        _alertBatteryLowStr as String,      //  String für Batterie-Alarm
        _alertShortCircuitStr as String,    //  String für Kurzschluss-Alarm
        _alertSystemInterruptStr as String, //  String für Systemunterbrechungs-Alarm
        _stateDisplayString as Array<String>,// Array mit Status-Strings für die verschiedenen FL-States
        _displayString as String,           //  Aktuell angezeigter String
        _lastValidString as String,         //  Letzter gültiger Datenwert-String (für Anzeige bei kurzer Unterbrechung)
        _labelString as String,             //  Überschrift (Feldname im Browse-Modus, sonst AppName)
        _fieldLabelStrings as Array<String>,//  Feldnamen-Strings: Index 0 = AppName, 1-11 = Feldnamen
        _chargeStateStrs as Array<String>,  //  Lesbare Ladezustands-Strings für Browse-Modus
        _noFieldStr as String,              //  Hinweis-String wenn kein Anzeigefeld konfiguriert ist
        _numFonts as Array<Graphics.FontDefinition>,  // Zahlen-Fonts für numerische Segmente (größte zuerst)
        _sysFonts as Array<Graphics.FontDefinition>,  // System-Fonts für Text-Segmente (passend zu _numFonts)
        _segTexts as Array<String>,         // Gecachte Segmente des zuletzt angezeigten Strings
        _segIsNum as Array<Boolean>,        // Zu _segTexts: true = numerisches Segment
        _cachedDisplayStr as String,        // Zuletzt gecachter _displayString für Segment-Cache
        _dataStale as Boolean;              // true = Datenstrom unterbrochen, letzter Wert wird grau angezeigt

    //! Set the label of the data field here
    //! @param dataManager The DataManager
    public function initialize(dataManager as DataManager, deviceManager as DeviceManager) {
        DataField.initialize();

        var initStr = WatchUi.loadResource($.Rez.Strings.initializing) as String;
        var connStr = WatchUi.loadResource($.Rez.Strings.connecting) as String;

        _stateDisplayString = [
            WatchUi.loadResource($.Rez.Strings.searching) as String,
            connStr, initStr, initStr, initStr, connStr, connStr, connStr
        ] as Array<String>;
        _alertBatteryLowStr = WatchUi.loadResource($.Rez.Strings.BatteryLow) as String;
        _alertShortCircuitStr = WatchUi.loadResource($.Rez.Strings.ShortCircuit) as String;
        _alertSystemInterruptStr = WatchUi.loadResource($.Rez.Strings.SystemInterrupt) as String;
        _fieldLabelStrings = [
            WatchUi.loadResource($.Rez.Strings.AppName) as String,
            WatchUi.loadResource($.Rez.Strings.TripEnergy) as String,
            WatchUi.loadResource($.Rez.Strings.Temperature) as String,
            WatchUi.loadResource($.Rez.Strings.DynamoPower) as String,
            WatchUi.loadResource($.Rez.Strings.DynamoGear) as String,
            WatchUi.loadResource($.Rez.Strings.Distance) as String,
            WatchUi.loadResource($.Rez.Strings.BatteryVoltage) as String,
            WatchUi.loadResource($.Rez.Strings.BatteryCurrent) as String,
            WatchUi.loadResource($.Rez.Strings.Load) as String,
            WatchUi.loadResource($.Rez.Strings.Speed) as String,
            WatchUi.loadResource($.Rez.Strings.BatteryCapacity) as String,
            WatchUi.loadResource($.Rez.Strings.ChargingState) as String,
            WatchUi.loadResource($.Rez.Strings.DayDistance) as String,
            WatchUi.loadResource($.Rez.Strings.TourDistance) as String
        ] as Array<String>;
        _chargeStateStrs = [
            WatchUi.loadResource($.Rez.Strings.ChargeStandby) as String,
            WatchUi.loadResource($.Rez.Strings.ChargeFull) as String,
            WatchUi.loadResource($.Rez.Strings.ChargeDischarging) as String,
            WatchUi.loadResource($.Rez.Strings.ChargeCharging) as String
        ] as Array<String>;
        _noFieldStr = WatchUi.loadResource($.Rez.Strings.NoFieldConfigured) as String;
        _labelString = _fieldLabelStrings[0];
        _data = dataManager;
        _device = deviceManager;
        _battVoltage = 0.0f;
        _capacity = 0;
        _index = 0;
        _alertMute = 0;
        _capacityAlertLock = false;
        _fitFieldsInitialized = false;
        _fitSetting1 = -1;
        _fitSetting2 = -1;
        _fitSetting3 = -1;
        _fitSetting4 = -1;
        _displayString = "--";
        _lastValidString = "--";
        _numFonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_SYSTEM_SMALL, Graphics.FONT_SYSTEM_TINY] as Array<Graphics.FontDefinition>;
        _sysFonts = [Graphics.FONT_SYSTEM_LARGE, Graphics.FONT_SYSTEM_MEDIUM, Graphics.FONT_SYSTEM_SMALL, Graphics.FONT_SYSTEM_SMALL, Graphics.FONT_SYSTEM_TINY] as Array<Graphics.FontDefinition>;
        _segTexts = [] as Array<String>;
        _segIsNum = [] as Array<Boolean>;
        _cachedDisplayStr = "";
        _dataStale = false;
    }

    public function onUpdate(dc as Dc) as Void {
        // Hintergrund- und Vordergrundfarbe einmalig bestimmen (Day/Night-Mode)
        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fgColor, bgColor);
        dc.clear();

        // dc-Dimensionen einmalig lesen
        var dcW = dc.getWidth();
        var dcH = dc.getHeight();
        var centerX = dcW / 2;

        // Label oben zentriert zeichnen
        var labelFont = Graphics.FONT_SYSTEM_SMALL;
        dc.drawText(centerX, 0, labelFont, _labelString, Graphics.TEXT_JUSTIFY_CENTER);
        var labelHeight = dc.getFontHeight(labelFont);
        var availHeight = dcH - labelHeight;
        var centerY = labelHeight + availHeight / 2;

        // Segmente nur neu berechnen wenn sich _displayString geändert hat (Cache)
        if (!_displayString.equals(_cachedDisplayStr)) {
            _cachedDisplayStr = _displayString;
            var segs = [] as Array<String>;
            var nums = [] as Array<Boolean>;
            var numericChars = "0123456789.+-:";
            var sLen = _displayString.length();
            if (sLen > 0) {
                var segStart = 0;
                var prevIsNum = numericChars.find(_displayString.substring(0, 1) as String) != null;
                for (var ci = 1; ci < sLen; ci++) {
                    var curIsNum = numericChars.find(_displayString.substring(ci, ci + 1) as String) != null;
                    if (curIsNum != prevIsNum) {
                        segs.add(_displayString.substring(segStart, ci) as String);
                        nums.add(prevIsNum);
                        segStart = ci;
                        prevIsNum = curIsNum;
                    }
                }
                segs.add(_displayString.substring(segStart, sLen) as String);
                nums.add(prevIsNum);
            }
            _segTexts = segs;
            _segIsNum = nums;
        }

        // Lokale Aliase für gecachte Daten (verkürzt VM-Adressierung im Loop)
        var segTexts = _segTexts;
        var segIsNum = _segIsNum;
        var segCount = segTexts.size();
        var numFonts = _numFonts;
        var sysFonts = _sysFonts;
        var maxWidth = dcW - 4;

        // Passendes Schriftgrößen-Paar suchen (groß → klein)
        for (var level = 0; level < numFonts.size(); level++) {
            var nf = numFonts[level] as Graphics.FontDefinition;
            var sf = sysFonts[level] as Graphics.FontDefinition;
            var nfH = dc.getFontHeight(nf);
            var sfH = dc.getFontHeight(sf);
            if ((nfH > sfH ? nfH : sfH) > availHeight) { continue; }

            // Segmentbreiten einmalig berechnen (kein doppelter getTextWidthInPixels-Aufruf)
            var segWidths = new [segCount] as Array<Number>;
            var totalW = 0;
            for (var si = 0; si < segCount; si++) {
                var sw = dc.getTextWidthInPixels(segTexts[si] as String, (segIsNum[si] as Boolean) ? nf : sf);
                segWidths[si] = sw;
                totalW += sw;
            }
            if (totalW > maxWidth) { continue; }

            // Bei veralteten Daten Farbe auf Grau wechseln (Label bleibt in Normalfarbe)
            if (_dataStale) {
                dc.setColor((bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            // Segmente als zentrierte Gruppe nebeneinander zeichnen
            var x = centerX - totalW / 2;
            for (var si = 0; si < segCount; si++) {
                dc.drawText(x, centerY, (segIsNum[si] as Boolean) ? nf : sf, segTexts[si] as String, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                x += segWidths[si] as Number;
            }
            return;
        }

        // Fallback: FONT_SYSTEM_TINY für beliebig langen Text
        dc.drawText(centerX, centerY, Graphics.FONT_SYSTEM_TINY, _displayString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Wird in der compute-Methode aufgerufen, um die FIT-Aufzeichnungsfelder erst zu erstellen, wenn sie tatsächlich benötigt werden (z.B. wenn der Benutzer FitLogging aktiviert)
    private function initFitRecordingFields() as Void {
        _fitSetting1 = $.UserSettings[$.FitField1] as Number;
        _fitSetting2 = $.UserSettings[$.FitField2] as Number;
        _fitSetting3 = $.UserSettings[$.FitField3] as Number;
        _fitSetting4 = $.UserSettings[$.FitField4] as Number;

        // Reset all field references first. Then create only fields explicitly enabled in settings.
        _fitRecording1 = null;
        _fitRecording2 = null;
        _fitRecording3 = null;
        _fitRecording4 = null;

        if (_fitSetting1 > 0) {
            _fitRecording1 = _createFitRecordingField(1, _fitSetting1);
        }
        if (_fitSetting2 > 0) {
            _fitRecording2 = _createFitRecordingField(2, _fitSetting2);
        }
        if (_fitSetting3 > 0) {
            _fitRecording3 = _createFitRecordingField(3, _fitSetting3);
        }
        if (_fitSetting4 > 0) {
            _fitRecording4 = _createFitRecordingField(4, _fitSetting4);
        }

        _fitFieldsInitialized = true;
    }

    private function _createFitRecordingField(slot as Number, setting as Number) as Field? {
        if (setting <= 0) {
            return null;
        }
        return createField(
            WatchUi.loadResource(_fitFieldLabelForSetting(setting)) as String,
            slot,
            _fitDataTypeForSetting(setting),
            {
                :mesgType => FitContributor.MESG_TYPE_RECORD,
                :units => WatchUi.loadResource(_fitFieldUnitForSetting(setting)) as String
            }
        ) as Field;
    }

    private function _fitDataTypeForSetting(setting as Number) as FitContributor.DataType {
        switch (setting) {
            case 4: // generator gear
                return FitContributor.DATA_TYPE_UINT8;
            case 10: // battery capacity
                return FitContributor.DATA_TYPE_UINT8;
            default:
                return FitContributor.DATA_TYPE_FLOAT;
        }
    }

    private function _fitFieldLabelForSetting(setting as Number) as ResourceId {
        switch (setting) {
            case 1: return $.Rez.Strings.TripEnergy;
            case 2: return $.Rez.Strings.Temperature;
            case 3: return $.Rez.Strings.DynamoPower;
            case 4: return $.Rez.Strings.DynamoGear;
            case 5: return $.Rez.Strings.Distance;
            case 6: return $.Rez.Strings.BatteryVoltage;
            case 7: return $.Rez.Strings.BatteryCurrent;
            case 8: return $.Rez.Strings.Load;
            case 9: return $.Rez.Strings.Speed;
            case 10: return $.Rez.Strings.BatteryCapacity;
            default: return $.Rez.Strings.Off;
        }
    }

    private function _fitFieldUnitForSetting(setting as Number) as ResourceId {
        switch (setting) {
            case 1: return $.Rez.Strings.TripEnergyLabel;
            case 2: return $.Rez.Strings.TemperatureLabel;
            case 3: return $.Rez.Strings.DynamoPowerLabel;
            case 4: return $.Rez.Strings.DynamoGearLabel;
            case 5: return $.Rez.Strings.DistanceLabel;
            case 6: return $.Rez.Strings.BatteryVoltageLabel;
            case 7: return $.Rez.Strings.BatteryCurrentLabel;
            case 8: return $.Rez.Strings.LoadLabel;
            case 9: return $.Rez.Strings.SpeedLabel;
            case 10: return $.Rez.Strings.BatteryCapacityLabel;
            default: return $.Rez.Strings.Off;
        }
    }

    private function _fitValueForSetting(setting as Number, flData as Array<Number>) as Float or Number {
        switch (setting) {
            case 1: // trip energy
                return ((flData[FL_tripEnergy] / 10.0 * 10).toNumber() / 10.0) as Float;
            case 2: // temperature
                return ((flData[FL_temperature] / 10.0 * 10).toNumber() / 10.0) as Float;
            case 3: // dynamo power
                return ((_battVoltage * (flData[FL_loadCurrent] + flData[FL_battCurrent]) / 1000 * 10).toNumber() / 10.0) as Float;
            case 4: // generator gear
                return flData[FL_gear];
            case 5: // odometer
                return (flData[FL_impulseCounter].toDouble() * _data.imp2odo).toNumber();
            case 6: // battery voltage
                return ((_battVoltage * 10).toNumber() / 10.0) as Float;
            case 7: // battery current
                return ((flData[FL_battCurrent] / 1000.0 * 10).toNumber() / 10.0) as Float;
            case 8: // electrical load
                return ((_battVoltage * flData[FL_loadCurrent] / 1000 * 10).toNumber() / 10.0) as Float;
            case 9: // speed
                return (flData[FL_frequency] * _data.freq2speed).toNumber();
            case 10: // battery capacity
                return _capacity;
            default:
                return 0;
        }
    }

    private function _writeFitRecordingValues(flData as Array<Number>) as Void {
        if (_fitRecording1 != null && _fitSetting1 > 0) {
            (_fitRecording1 as Field).setData(_fitValueForSetting(_fitSetting1, flData));
        }
        if (_fitRecording2 != null && _fitSetting2 > 0) {
            (_fitRecording2 as Field).setData(_fitValueForSetting(_fitSetting2, flData));
        }
        if (_fitRecording3 != null && _fitSetting3 > 0) {
            (_fitRecording3 as Field).setData(_fitValueForSetting(_fitSetting3, flData));
        }
        if (_fitRecording4 != null && _fitSetting4 > 0) {
            (_fitRecording4 as Field).setData(_fitValueForSetting(_fitSetting4, flData));
        }
    }

    //! generate, display and log forumslader values
    //! @return String value to display in the simpledatafield
    private function computeDisplayString() as String {
        var settings = $.UserSettings;
        // Race protection FLdata Parallel-Access
        // Make local snapshots of volatile FLdata array to ensure consistency
        // During encode() calls, individual elements can be updated
        var flData = _data.FLdata;
        var battVoltage1 = flData[FL_battVoltage1];
        var battVoltage2 = flData[FL_battVoltage2];
        var battVoltage3 = flData[FL_battVoltage3];
        var socState = flData[FL_socState];
        var ccadcValue = flData[FL_ccadcValue];
        var fullChargeCapacity = flData[FL_fullChargeCapacity];
        var battCalcMethod = settings[$.BattCalcMethod] == true;
        var fitLogging = settings[$.FitLogging] == true;
        var alertsEnabled = settings[$.Alerts] == true;
        var rotateFields = settings[$.BrowseFields] == true;

        // Pre-calculate battery voltage and capacity using snapshot values
        _battVoltage = (battVoltage1 + battVoltage2 + battVoltage3) / 1000.0 as Float;
        if (battCalcMethod) { // use coloumb calculation method
            var x1 = ccadcValue.toLong() * flData[FL_acc2mah].toLong() / 167772.16 as Float;
            var x2 = fullChargeCapacity;
            if (x2 > 0) {
                _capacity = (x1 / x2).toNumber();
            }
        } else { // use voltage calculation method
            _capacity = socState;
        }

        // write values to fit file, if FitLogging is enabled by user
        if (fitLogging) {
            if (!_fitFieldsInitialized || _fitSettingsChanged()) {
                initFitRecordingFields();
            }
            _writeFitRecordingValues(flData);
        }

        // display forumslader alarms
        if (ForumsladerView has :showAlert && alertsEnabled) {
            checkAlarms();
        }

        // check if nothing is selected for display, if so return hint
        if (settings[0] == 0 && settings[1] == 0 && settings[2] == 0 && settings[3] == 0) {
            _labelString = _fieldLabelStrings[0];
            return _noFieldStr;
        }

        // Feldrotation aus: alle aktiven Felder zusammengesetzt anzeigen
        if (!rotateFields) {
            _labelString = _fieldLabelStrings[0];
            var displayString = "";
            var firstField = true;
            for (var i = 0; i < 4; i++) {
                var setting = settings[i];
                if (setting > 0) {
                    if (!firstField) {
                        displayString += " ";
                    }
                    displayString += computeFieldValue(setting as Number);
                    firstField = false;
                }
            }
            return displayString;
        }

        // Feldrotation ein: nur das Feld an _index anzeigen, Weiterschaltung per Antippen
        // Sicherstellen, dass _index auf ein aktives Feld zeigt (z. B. nach Einstellungsänderung)
        if ((settings[_index] as Number) == 0) {
            for (var i = 0; i < 4; i++) {
                if ((settings[i] as Number) > 0) {
                    _index = i;
                    break;
                }
            }
        }

        // Feldname als Label und Seitenindikator aktualisieren
        var currentSetting = settings[_index] as Number;
        _labelString = (currentSetting < _fieldLabelStrings.size())
            ? _fieldLabelStrings[currentSetting]
            : _fieldLabelStrings[0];

        return computeFieldValue(currentSetting);
    }

    //! generate a single field value
    //! @param Number of selected field value
    //! @return String value for the selected field
    private function computeFieldValue(fieldvalue as Number) as String {
        var flData = _data.FLdata;
        switch (fieldvalue) {
            case 13: {  // tour distance
                var d13 = flData[FL_impulseCounter] - flData[FL_tourPulseOffset];
                return ((d13 > 0 ? d13 : 0).toDouble() * _data.imp2odo).format("%.1f") + $.distanceunit;
            }
            case 12: {  // day distance
                var d12 = flData[FL_impulseCounter] - flData[FL_dayPulseOffset];
                return ((d12 > 0 ? d12 : 0).toDouble() * _data.imp2odo).format("%.1f") + $.distanceunit;
            }
            case 11:    // charger state
                var status = flData[FL_status];
                if (($.UserSettings[$.BrowseFields] as Boolean) == true) {
                    if (status & 0x200) { return _chargeStateStrs[0]; }  // standby
                    if (status & 0x100) { return _chargeStateStrs[1]; }  // full
                    return (status & 0x8000) ? _chargeStateStrs[2] : _chargeStateStrs[3];
                }
                var char = (status & 0x8000) ? "-" : "+";
                return (status & 0x200) ? "o" : ((status & 0x100) ? "*" : char);
            case 10:    // remaining battery capacity
                return _capacity.toString() + "%";
            case 9:     // speed
                return (flData[FL_frequency] * _data.freq2speed).format("%.1f") + $.speedunit;
            case 8:     // electrical load
                return (_battVoltage * flData[FL_loadCurrent] / 1000).format("%.1f") + "W";
            case 7:     // battery current
                return (flData[FL_battCurrent] / 1000.0).format("%+.1f") + "A";
            case 6:     // battery voltage
                return _battVoltage.format("%.1f") + "V";
            case 5:     // odometer
                return (flData[FL_impulseCounter] * _data.imp2odo).format("%.1f") + $.distanceunit;
            case 4:     // generator gear
                return flData[FL_gear].toString();
            case 3:     // dynamo power
                return (_battVoltage * (flData[FL_loadCurrent] + flData[FL_battCurrent]) / 1000).format("%.0f") + "W";
            case 2:     // temperature
                return (flData[FL_temperature] / 10.0).format("%.1f") + "°";
            case 1:     // trip energy
                return (flData[FL_tripEnergy] / 10.0).format("%.1f") + "Wh";
            default:
                return "";
        }
    }

    private function _fitSettingsChanged() as Boolean {
        return _fitSetting1 != ($.UserSettings[$.FitField1] as Number)
            || _fitSetting2 != ($.UserSettings[$.FitField2] as Number)
            || _fitSetting3 != ($.UserSettings[$.FitField3] as Number)
            || _fitSetting4 != ($.UserSettings[$.FitField4] as Number);
    }

    //! Checks background alarm states for battery capacity and forumslader status and shows alert if necessary
    //! Optimized for 1Hz execution loop
    private function checkAlarms() as Void {
        // 1. Early Exit: Wenn der Alarm stummgeschaltet ist, zähle nur den Timer runter
        if (_alertMute > 0) {
            _alertMute--;
            return;
        }

        // 2. Alarm auslösen (State-Trigger statt dauerhaftem Abfragen)
        if (!_capacityAlertLock) {
            if (_capacity > 0 && _capacity < _capacityAlarmMin) {
                _capacityAlertLock = true;
                _alertMute = _alertLockTime;
                showAlert(new $.ForumsladerAlertView(_alertBatteryLowStr));
            }
        } else {
        // 3. Alarm zurücksetzen, wenn die Kapazität sich erholt hat (z. B. durch Ladung)
            if (_capacity > _capacityAlarmMax) {
                _capacityAlertLock = false;
            }
        }

        // 4. Weitere Alarme prüfen (z. B. Kurzschluss, Systemunterbrechung) - ebenfalls mit State-Triggern
        var flStatus = _data.FLdata[FL_status];
        if (flStatus & 0x8) { // short circuit
            _alertMute = _alertLockTime;
            showAlert(new $.ForumsladerAlertView(_alertShortCircuitStr));
            return;
        }
        if (flStatus & 0x800000) { // system interrupt
            _alertMute = _alertLockTime;
            showAlert(new $.ForumsladerAlertView(_alertSystemInterruptStr));
            return;
        }
    }

    //! Wird vom InputDelegate aufgerufen, wenn der Benutzer das Datenfeld antippt oder eine Taste drückt.
    //! Springt zum nächsten aktivierten Anzeigefeld und aktualisiert die Ansicht sofort.
    public function onFieldAction() as Void {
        for (var count = 0; count < 4; count++) {
            _index = (_index + 1) % 4;
            if (($.UserSettings[_index] as Number) > 0) {
                break;
            }
        }
        WatchUi.requestUpdate();
    }

    //! switch device state, process the $FLx data, calculate and show values every one second
    //! @param info The updated Activity.Info object
    public function compute(info as Info) as Void {
        var payloadRef = $.FLpayload;   // take reference to current buffer to prevent race with onCharacteristicChanged()
        $.FLpayload = []b;              // publish empty buffer for new incoming data

        var size = payloadRef.size();
        if (size > $.MAX_PAYLOAD_SIZE) { size = $.MAX_PAYLOAD_SIZE; } // cap to prevent processing of excessively large buffers
        for (var i = 0; i < size; i++) {
            _data.encode(payloadRef[i]);
        }

        // toggle device state machine and store current device state
        var deviceState = _device.updateState();

        // if we have recent data, and are fully initialized, display data, else display device state
        if (_data.age <= _data.MAX_AGE_SEC && $.FLstate > FL_CONFIG3) {
            _data.age++;
            _lastValidString = computeDisplayString();
            _displayString = _lastValidString;
            _dataStale = false;
        } else if ($.FLstate == FL_RUNNING) {
            // Verbunden aber Datenstrom kurz unterbrochen: letzten Wert grau anzeigen
            _displayString = _lastValidString;
            _dataStale = true;
        } else {
            _labelString = _fieldLabelStrings[0];
            _displayString = _stateDisplayString[deviceState];
            _dataStale = false;
        }

        WatchUi.requestUpdate();
    }
}

//! Bestätigungs-Delegate für den Tageszähler-Reset-Dialog
class TripResetDelegate extends WatchUi.Menu2InputDelegate {

    private var _device as DeviceManager;

    public function initialize(deviceManager as DeviceManager) {
        Menu2InputDelegate.initialize();
        _device = deviceManager;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        if ($.FLstate == FL_RUNNING) {
            var id = item.getId();
            if (id == :tripconfirm) {
                _device.resetTrip();
            } else if (id == :tourconfirm) {
                _device.resetTour();
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

