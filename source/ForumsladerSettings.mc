import Toybox.Application;
import Toybox.Lang;
import Toybox.Application.Storage;

var UserSettings as Array = [10, 3, 6, 7, false, false, false];

// user settings
    enum {
        DisplayField1,
        DisplayField2,
        DisplayField3,
        DisplayField4,
        BattCalcMethod, 
        FitLogging,
        DeviceLock
    }

//! read user settings from GCM properties in UserSettings array
function getUserSettings() as Void {
    $.UserSettings[$.DisplayField1] = Application.Properties.getValue("UserSetting1") as Number;
    $.UserSettings[$.DisplayField2] = Application.Properties.getValue("UserSetting2") as Number;
    $.UserSettings[$.DisplayField3] = Application.Properties.getValue("UserSetting3") as Number;
    $.UserSettings[$.DisplayField4] = Application.Properties.getValue("UserSetting4") as Number;
    $.UserSettings[$.BattCalcMethod] = Application.Properties.getValue("BatteryCalcMethod") as Boolean;
    $.UserSettings[$.FitLogging] = Application.Properties.getValue("FitLogging") as Boolean;
    $.UserSettings[$.DeviceLock] = Application.Properties.getValue("DeviceLock") as Boolean;
    if ($.UserSettings[$.DeviceLock] == false) { 
        Storage.deleteValue("MyDevice");
    }
    //debug("User Settings: " + $.UserSettings.toString());
}