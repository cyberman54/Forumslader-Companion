import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Application.Properties;
import Toybox.FitContributor;

class ForumsladerView extends DataField {

    private const
        _alertLockTime as Number = 100,     // Lock duration in seconds after alarm is triggered
        _capacityAlarmMin as Number = 20,   // Warning threshold below 20% capacity
        _capacityAlarmMax as Number = 28;   // Alert reset threshold at 28% (hysteresis protection)

    private var
        _data as DataManager,
        _device as DeviceManager,
        _battVoltage as Float,
        _capacity as Number,                // % (coulomb counting or voltage method)
        _index as Number,
        _alertMute as Number,               // mute countdown in seconds
        _capacityAlertLock as Boolean,      // prevents repeated low-battery alerts
        _fitFieldsInitialized as Boolean,
        _fitRecording1 as Field?,
        _fitRecording2 as Field?,
        _fitRecording3 as Field?,
        _fitRecording4 as Field?,
        _fitSetting1 as Number,
        _fitSetting2 as Number,
        _fitSetting3 as Number,
        _fitSetting4 as Number,
        _alertBatteryLowStr as String,
        _alertShortCircuitStr as String,
        _alertSystemInterruptStr as String,
        _stateDisplayString as Array<String>,
        _displayString as String,
        _lastValidString as String,         // retained for stale-data display
        _labelString as String,
        _fieldLabelStrings as Array<String>,// [0]=AppName, [1..13]=field names
        _chargeStateStrs as Array<String>,
        _noFieldStr as String,
        _numFonts as Array<Graphics.FontDefinition>,  // largest first
        _sysFonts as Array<Graphics.FontDefinition>,
        _dataStale as Boolean,              // true while data stream is interrupted
        _numFontHeights as Array<Number>,
        _sysFontHeights as Array<Number>,
        _centerX as Number,
        _centerY as Number,
        _availHeight as Number,
        _maxWidth as Number;

    public function initialize(dataManager as DataManager, deviceManager as DeviceManager) {
        DataField.initialize();

        var initStr = WatchUi.loadResource($.Rez.Strings.initializing) as String;
        var connStr = WatchUi.loadResource($.Rez.Strings.connecting) as String;

        _stateDisplayString = [
            WatchUi.loadResource($.Rez.Strings.searching) as String, connStr, initStr, initStr, initStr, connStr, connStr, connStr ] as Array<String>;
        _fieldLabelStrings = [
            WatchUi.loadResource($.Rez.Strings.AppName) as String, WatchUi.loadResource($.Rez.Strings.TripEnergy) as String, WatchUi.loadResource($.Rez.Strings.Temperature) as String,
            WatchUi.loadResource($.Rez.Strings.DynamoPower) as String, WatchUi.loadResource($.Rez.Strings.DynamoGear) as String, WatchUi.loadResource($.Rez.Strings.Distance) as String,
            WatchUi.loadResource($.Rez.Strings.BatteryVoltage) as String, WatchUi.loadResource($.Rez.Strings.BatteryCurrent) as String, WatchUi.loadResource($.Rez.Strings.Load) as String,
            WatchUi.loadResource($.Rez.Strings.Speed) as String, WatchUi.loadResource($.Rez.Strings.BatteryCapacity) as String, WatchUi.loadResource($.Rez.Strings.ChargingState) as String,
            WatchUi.loadResource($.Rez.Strings.DayDistance) as String, WatchUi.loadResource($.Rez.Strings.TourDistance) as String ] as Array<String>;
        _chargeStateStrs = [
            WatchUi.loadResource($.Rez.Strings.ChargeStandby) as String, WatchUi.loadResource($.Rez.Strings.ChargeFull) as String,
            WatchUi.loadResource($.Rez.Strings.ChargeDischarging) as String, WatchUi.loadResource($.Rez.Strings.ChargeCharging) as String ] as Array<String>;
        _alertBatteryLowStr = WatchUi.loadResource($.Rez.Strings.BatteryLow) as String;
        _alertShortCircuitStr = WatchUi.loadResource($.Rez.Strings.ShortCircuit) as String;
        _alertSystemInterruptStr = WatchUi.loadResource($.Rez.Strings.SystemInterrupt) as String;
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
        _dataStale = false;
        _numFontHeights = [0, 0, 0, 0, 0] as Array<Number>;
        _sysFontHeights = [0, 0, 0, 0, 0] as Array<Number>;
        _centerX = 0; _centerY = 0; _availHeight = 0; _maxWidth = 0;
    }

    //! Caches display geometry and font heights.
    public function onLayout(dc as Dc) as Void {
        var dcW = dc.getWidth();
        var dcH = dc.getHeight();
        _centerX = dcW / 2;
        _maxWidth = dcW - 4;
        var labelHeight = dc.getFontHeight(Graphics.FONT_SYSTEM_SMALL);
        _availHeight = dcH - labelHeight;
        _centerY = labelHeight + _availHeight / 2;
        var n = _numFonts.size();
        for (var i = 0; i < n; i++) {
            _numFontHeights[i] = dc.getFontHeight(_numFonts[i] as Graphics.FontDefinition);
            _sysFontHeights[i] = dc.getFontHeight(_sysFonts[i] as Graphics.FontDefinition);
        }
    }

    //! Renders label and value; called by DataField framework on each update.
    public function onUpdate(dc as Dc) as Void {

        var centerX = _centerX;
        var centerY = _centerY;
        var availHeight = _availHeight;
        var maxWidth = _maxWidth;
        var numFonts = _numFonts;
        var sysFonts = _sysFonts;
        var numFontHeights = _numFontHeights;
        var sysFontHeights = _sysFontHeights;

        // day/night colors, clear
        var bgColor = getBackgroundColor();
        var fgColor = (bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fgColor, bgColor);
        dc.clear();
        dc.drawText(centerX, 0, Graphics.FONT_SYSTEM_SMALL, _labelString, Graphics.TEXT_JUSTIFY_CENTER);

        // find end of numeric prefix (0 = pure text/status)
        var sLen = _displayString.length();
        var numEnd = 0;
        var chars = _displayString.toCharArray();
        while (numEnd < sLen) {
            var c = (chars[numEnd] as Char).toNumber();
            if (!((c >= 48 && c <= 57) || c == 43 || c == 45 || c == 46 || c == 58)) { break; }
            numEnd++;
        }

        // single-field mode: large number font + small unit font
        if ($.UserSettings[$.BrowseFields] == true && numEnd > 0) {
            var numStr = _displayString.substring(0, numEnd) as String;
            var unitStr = _displayString.substring(numEnd, sLen) as String;

            // Try to find the largest font that fits the available height and width
            for (var level = 0; level < numFonts.size(); level++) {
                var nf = numFonts[level] as Graphics.FontDefinition;
                var sf = sysFonts[level] as Graphics.FontDefinition;
                var nfH = numFontHeights[level];
                var sfH = sysFontHeights[level];
                if ((nfH > sfH ? nfH : sfH) > availHeight) { continue; }

                var numW = dc.getTextWidthInPixels(numStr, nf);
                var unitW = (numEnd < sLen) ? dc.getTextWidthInPixels(unitStr, sf) : 0;
                if (numW + unitW > maxWidth) { continue; }

                // gray if stale
                if (_dataStale) {
                    dc.setColor((bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                }
                var x = centerX - (numW + unitW) / 2;
                dc.drawText(x, centerY, nf, numStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                if (numEnd < sLen) {
                    dc.drawText(x + numW, centerY, sf, unitStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                }
                return;
            }
        } else {
            // multi-field / text: centered system font
            for (var level = 0; level < sysFonts.size(); level++) {
                var sf = sysFonts[level] as Graphics.FontDefinition;
                if (sysFontHeights[level] > availHeight) { continue; }
                if (dc.getTextWidthInPixels(_displayString, sf) > maxWidth) { continue; }
                if (_dataStale) {
                    dc.setColor((bgColor == Graphics.COLOR_BLACK) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                }
                dc.drawText(centerX, centerY, sf, _displayString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                return;
            }
        }

        // fallback: FONT_SYSTEM_TINY always fits
        dc.drawText(centerX, centerY, Graphics.FONT_SYSTEM_TINY, _displayString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Creates FIT recording fields from current settings. Lazy-init, called from compute().
    private function initFitRecordingFields() as Void {
        _fitSetting1 = $.UserSettings[$.FitField1] as Number;
        _fitSetting2 = $.UserSettings[$.FitField2] as Number;
        _fitSetting3 = $.UserSettings[$.FitField3] as Number;
        _fitSetting4 = $.UserSettings[$.FitField4] as Number;
        // reset, then create only enabled fields
        _fitRecording1 = null;
        _fitRecording2 = null;
        _fitRecording3 = null;
        _fitRecording4 = null;
        if (_fitSetting1 > 0) { _fitRecording1 = _createFitRecordingField(1, _fitSetting1); }
        if (_fitSetting2 > 0) { _fitRecording2 = _createFitRecordingField(2, _fitSetting2); }
        if (_fitSetting3 > 0) { _fitRecording3 = _createFitRecordingField(3, _fitSetting3); }
        if (_fitSetting4 > 0) { _fitRecording4 = _createFitRecordingField(4, _fitSetting4); }
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
                return (((_battVoltage * (flData[FL_loadCurrent] + flData[FL_battCurrent]).abs()) / 1000 * 10).toNumber() / 10.0) as Float;
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

    //! Writes current sensor values to active FIT recording fields.
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

    //! Computes the display string and logs to FIT if enabled. Called every second.
    private function computeDisplayString() as String {
        var settings = $.UserSettings;
        // snapshot FLdata to avoid race with encode()
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

        // voltage and capacity from snapshot
        _battVoltage = (battVoltage1 + battVoltage2 + battVoltage3) / 1000.0 as Float;
        if (battCalcMethod) { // coulomb counting
            var x1 = ccadcValue.toLong() * flData[FL_acc2mah].toLong() / 167772.16 as Float;
            var x2 = fullChargeCapacity;
            if (x2 > 0) {
                _capacity = (x1 / x2).toNumber();
            }
        } else { // use voltage calculation method
            _capacity = socState;
        }

        // FIT logging
        if (fitLogging) {
            if (!_fitFieldsInitialized || _fitSettingsChanged()) {
                initFitRecordingFields();
            }
            _writeFitRecordingValues(flData);
        }

        if (ForumsladerView has :showAlert && alertsEnabled) {
            checkAlarms();
        }

        // no field configured
        if (settings[0] == 0 && settings[1] == 0 && settings[2] == 0 && settings[3] == 0) {
            _labelString = _fieldLabelStrings[0];
            return _noFieldStr;
        }

        // all active fields concatenated
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
                    displayString += computeFieldValue(setting as Number, flData);
                    firstField = false;
                }
            }
            return displayString;
        }

        // single-field rotation; ensure _index points to an active field
        if ((settings[_index] as Number) == 0) {
            for (var i = 0; i < 4; i++) {
                if ((settings[i] as Number) > 0) {
                    _index = i;
                    break;
                }
            }
        }

        var currentSetting = settings[_index] as Number;
        _labelString = (currentSetting < _fieldLabelStrings.size())
            ? _fieldLabelStrings[currentSetting]
            : _fieldLabelStrings[0];

        return computeFieldValue(currentSetting, flData);
    }

    //! Returns the formatted display string for a single field.
    private function computeFieldValue(fieldvalue as Number, flData as Array<Number>) as String {
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
            case 3:     // dynamo power, always positive
                return (_battVoltage * (flData[FL_loadCurrent] + flData[FL_battCurrent]).abs() / 1000).format("%.0f") + "W";
            case 2:     // temperature
                return (flData[FL_temperature] / 10.0).format("%.1f") + "°C";
            case 1:     // trip energy
                return (flData[FL_tripEnergy] / 10.0).format("%.1f") + "Wh";
            default:
                return "";
        }
    }

    //! @return true if any FIT field setting changed since last init.
    private function _fitSettingsChanged() as Boolean {
        return _fitSetting1 != ($.UserSettings[$.FitField1] as Number)
            || _fitSetting2 != ($.UserSettings[$.FitField2] as Number)
            || _fitSetting3 != ($.UserSettings[$.FitField3] as Number)
            || _fitSetting4 != ($.UserSettings[$.FitField4] as Number);
    }

    //! Checks battery and status alarms at 1 Hz.
    private function checkAlarms() as Void {
        // muted: count down only
        if (_alertMute > 0) {
            _alertMute--;
            return;
        }

        // battery low
        if (!_capacityAlertLock) {
            if (_capacity > 0 && _capacity < _capacityAlarmMin) {
                _capacityAlertLock = true;
                _alertMute = _alertLockTime;
                showAlert(new $.ForumsladerAlertView(_alertBatteryLowStr));
            }
        } else {
        // unlock once capacity recovers
            if (_capacity > _capacityAlarmMax) {
                _capacityAlertLock = false;
            }
        }

        // short circuit / system interrupt
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

    //! Cycles _index to the next active display field.
    public function onFieldAction() as Void {
        for (var count = 0; count < 4; count++) {
            _index = (_index + 1) % 4;
            if (($.UserSettings[_index] as Number) > 0) {
                break;
            }
        }
        WatchUi.requestUpdate();
    }

    //! Processes incoming BLE payload, advances FSM, updates display string.
    public function compute(info as Info) as Void {
        var payloadRef = $.FLpayload;   // atomic buffer swap
        $.FLpayload = []b;

        var size = payloadRef.size();
        if (size > $.MAX_PAYLOAD_SIZE) { size = $.MAX_PAYLOAD_SIZE; } // cap at MAX_PAYLOAD_SIZE
        for (var i = 0; i < size; i++) {
            _data.encode(payloadRef[i]);
        }

        // advance FSM
        var deviceState = _device.updateState();

        if (_data.age <= _data.MAX_AGE_SEC && $.FLstate > FL_CONFIG3) {
            _data.age++;
            _lastValidString = computeDisplayString();
            _displayString = _lastValidString;
            _dataStale = false;
        } else if ($.FLstate == FL_RUNNING) {
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

//! Confirmation delegate for the trip counter reset dialog
class TripResetDelegate extends WatchUi.Menu2InputDelegate {

    private var _device as DeviceManager;
    private var _data as DataManager;

    public function initialize(deviceManager as DeviceManager, dataManager as DataManager) {
        Menu2InputDelegate.initialize();
        _device = deviceManager;
        _data = dataManager;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        if ($.FLstate == FL_RUNNING) {
            var id = item.getId();
            var currentPulse = _data.FLdata[FL_impulseCounter];
            if (id == :tripconfirm) {
                _device.resetTrip();
                _data.FLdata[FL_dayPulseOffset] = currentPulse;
            } else if (id == :tourconfirm) {
                _device.resetTour();
                _data.FLdata[FL_tourPulseOffset] = currentPulse;
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

