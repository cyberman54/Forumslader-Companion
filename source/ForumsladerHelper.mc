import Toybox.Lang;
import Toybox.System;

// debug output
(:debug) function debug(val as String or Char or Number) as Void {
    switch(val) {
        case instanceof Lang.Number:
            System.println(val as Number);
            break;
        case instanceof Lang.Char:
            System.print(val as Char);
            break;
        case instanceof Lang.String:
            System.println(val as String);
            break;
        }
}   

(:release) function debug(val as String or Char or Number) as Void {}