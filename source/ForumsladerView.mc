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
        _stateDisplayString as Array<String>,// Array mit Status-Strings für die verschiedenen FL-States (z.B. "Suchen...", "Verbinden...", etc.)
        _displayString as String,           //  Aktuell angezeigter String (entweder Status oder Datenwert basierend auf FLstate und Datenalter)
        _labelString as String;             //  Überschrift des Datenfelds (AppName aus Ressourcen)

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
        _labelString = WatchUi.loadResource($.Rez.Strings.AppName) as String;
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
    }

    public function onUpdate(dc as Dc) as Void {
        // System-Farben für Day/Night-Mode: getBackgroundColor() liefert die vom System
        // vorgegebene Hintergrundfarbe (COLOR_WHITE im Tag-, COLOR_BLACK im Nachtmodus).
        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fgColor, bgColor);
        dc.clear();

        // Überschrift oben zentriert im kleinsten Systemfont
        var labelFont = Graphics.FONT_SYSTEM_SMALL;
        dc.drawText(dc.getWidth() / 2, 0, labelFont, _labelString, Graphics.TEXT_JUSTIFY_CENTER);
        var labelHeight = dc.getFontHeight(labelFont);

        // Größte passende Schriftgröße wählen (nur Breite prüfen, Höhe wird vom DC geclippt)
        var fonts = [Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM, Graphics.FONT_NUMBER_MILD, Graphics.FONT_SYSTEM_LARGE, Graphics.FONT_SYSTEM_MEDIUM, Graphics.FONT_SYSTEM_SMALL, Graphics.FONT_SYSTEM_TINY] as Array<Graphics.FontDefinition>;
        var maxWidth = dc.getWidth() - 4;
        var font = fonts[fonts.size() - 1] as Graphics.FontDefinition;
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(_displayString, fonts[i]) <= maxWidth) {
                font = fonts[i] as Graphics.FontDefinition;
                break;
            }
        }

        // Wert vertikal zentriert im verbleibenden Bereich unterhalb der Überschrift
        var valueY = labelHeight + (dc.getHeight() - labelHeight) / 2;
        dc.drawText(
            dc.getWidth() / 2,
            valueY,
            font,
            _displayString,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
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

        // check if nothing is selected for display, if so return "--"
        if (settings[0] == 0 && settings[1] == 0 && settings[2] == 0 && settings[3] == 0) {
            return "--";
        }

        // Feldrotation aus: alle aktiven Felder zusammengesetzt anzeigen
        if (!rotateFields) {
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

        return computeFieldValue(settings[_index] as Number);
    }

    //! generate a single field value
    //! @param Number of selected field value
    //! @return String value for the selected field
    private function computeFieldValue(fieldvalue as Number) as String {
        var flData = _data.FLdata;
        switch (fieldvalue) {
            case 11:    // charger state
                var status = flData[FL_status];
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
        if (size > 300) { size = 300; } // cap to prevent processing of excessively large buffers
        for (var i = 0; i < size; i++) {
            _data.encode(payloadRef[i]);
        }

        // toggle device state machine and store current device state
        var deviceState = _device.updateState();

        // if we have recent data, and are fully initialized, display data, else display device state
        if (_data.age <= _data.MAX_AGE_SEC && $.FLstate > FL_CONFIG3) {
            _data.age++; // increase data age seconds counter
            _displayString = computeDisplayString(); // display data
        } else {
            _displayString = _stateDisplayString[deviceState]; // display state
        }

        WatchUi.requestUpdate();
    }
}

