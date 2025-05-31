import Toybox.Activity;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Attention;

(:showalert)
//! The data field alert
class ForumsladerAlertView extends WatchUi.DataFieldAlert {

private var _alerttext as String;

    //! Constructor
    public function initialize(message as String) {
        DataFieldAlert.initialize();
        _alerttext = message;
        debug("alert: " + _alerttext);
    }

    //! Update the view
    //! @param dc Device context
    public function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_RED);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2 - 30, Graphics.FONT_LARGE, 
        WatchUi.loadResource($.Rez.Strings.AppName) + "\n" + _alerttext, Graphics.TEXT_JUSTIFY_CENTER);
        if (Attention has :ToneProfile) {
            Attention.playTone(Attention.TONE_ALARM);
        }
    }
}
