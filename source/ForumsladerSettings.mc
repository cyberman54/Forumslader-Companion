import Toybox.Application;
import Toybox.Lang;

var userSettings as Array = [10, 3, 6, 7, false, 0, 0, 0, 0, false];

function getUserSettings() as Void {
    userSettings[0] = Application.Properties.getValue("Item1") as Number;
    userSettings[1] = Application.Properties.getValue("Item2") as Number;
    userSettings[2] = Application.Properties.getValue("Item3") as Number;
    userSettings[3] = Application.Properties.getValue("Item4") as Number;
    userSettings[4] = Application.Properties.getValue("BatteryCalcMethod") as Boolean;
    userSettings[5] = Application.Properties.getValue("Item5") as Number;
    userSettings[6] = Application.Properties.getValue("Item6") as Number;
    userSettings[7] = Application.Properties.getValue("Item7") as Number;
    userSettings[8] = Application.Properties.getValue("Item8") as Number;
    userSettings[9] = Application.Properties.getValue("DataLogging") as Boolean;
    debug("GCM settings: " + userSettings.toString());
}