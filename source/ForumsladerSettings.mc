import Toybox.Application;
import Toybox.Lang;

var showValues as Array = [10, 3, 6, 7, false, false];

//! read user settings from GCM properties in showValues array
function getUserSettings() as Void {
    $.showValues[0] = Application.Properties.getValue("ShowValue1") as Number;
    $.showValues[1] = Application.Properties.getValue("ShowValue2") as Number;
    $.showValues[2] = Application.Properties.getValue("ShowValue3") as Number;
    $.showValues[3] = Application.Properties.getValue("ShowValue4") as Number;
    $.showValues[4] = Application.Properties.getValue("BatteryCalcMethod") as Boolean;
    $.showValues[5] = Application.Properties.getValue("Logging") as Boolean;
    //debug("User Settings: " + $.showValues.toString());
}