import Toybox.Lang;
import Toybox.System;

(:debug)
function debug(val as Object) as Void {
    switch (val) {
        case instanceof Lang.Number:
            System.println(val as Number);
            break;
        case instanceof Lang.Float:
            System.println(val as Float);
            break;
        case instanceof Lang.Double:
            System.println(val as Double);
            break;
        case instanceof Lang.Char:
            System.print(val as Char);
            break;
        case instanceof Lang.String:
            System.println(val as String);
            break;
    }
}

(:release)
function debug(val as Object) as Void {}