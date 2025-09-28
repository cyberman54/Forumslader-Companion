import Toybox.Lang;
import Toybox.FitContributor;
using Toybox.FitContributor as Fit;
import Toybox.WatchUi;

/*
const MAX_NUMBER_OF_FIELDS = 32;
const PROPERTY_NUMBER_OF_SESSION_FIELDS = "s";
const PROPERTY_NUMBER_OF_SESSION_FIELDS_DEFAULT = 0;
const PROPERTY_NUMBER_OF_LAP_FIELDS = "l";
const PROPERTY_NUMBER_OF_LAP_FIELDS_DEFAULT = 0;
const PROPERTY_NUMBER_OF_RECORD_FIELDS = "r";
const PROPERTY_NUMBER_OF_RECORD_FIELDS_DEFAULT = 0;
const PROPERTY_FIELD_SIZE = "w";
const PROPERTY_FIELD_SIZE_DEFAULT = 1;
*/

class ForumsladerFitContributor {

    /* 
    private var mNumberOfRecordFields as Number = 0;
    private var mRecordFields as Array<Field?>;
    private var mFieldSize as Number = PROPERTY_FIELD_SIZE_DEFAULT;
    private var mFieldType as Fit.DataType = Fit.DATA_TYPE_UINT8;
    */

    private var
        _fitRecording1 as Field,
        _fitRecording2 as Field,
        _fitRecording3 as Field,
        _fitRecording4 as Field;

    public function initialize() {
        // Create custom FIT data fields for recording of 4 forumslader values
        // Battery Voltage
        _fitRecording1 = createField(WatchUi.loadResource($.Rez.Strings.BatteryVoltage) as String, 
            1, Fit.DATA_TYPE_FLOAT,
            {:mesgType=>Fit.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryVoltageLabel) as String}) 
            as Fit.Field;
        // Battery Capacity
        _fitRecording2 = createField(WatchUi.loadResource($.Rez.Strings.BatteryCapacity) as String, 
            2, Fit.DATA_TYPE_UINT8,
            {:mesgType=>Fit.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.BatteryCapacityLabel) as String}) 
            as Fit.Field;
        // Dynamo Power
        _fitRecording3 = createField(WatchUi.loadResource($.Rez.Strings.DynamoPower) as String, 
            3, Fit.DATA_TYPE_FLOAT,
            {:mesgType=>Fit.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.DynamoPowerLabel) as String}) 
            as Fit.Field;
        // Electrical Load
        _fitRecording4 = createField(WatchUi.loadResource($.Rez.Strings.Load) as String, 
            4, Fit.DATA_TYPE_FLOAT,
            {:mesgType=>Fit.MESG_TYPE_RECORD, 
            :units=>WatchUi.loadResource($.Rez.Strings.LoadLabel) as String}) 
            as Fit.Field;
    }

    // write values to fit file
    public function setData(field1 as Float, field2 as Number, field3 as Float, field4 as Float) as Void {
        _fitRecording1.setData(field1);
        _fitRecording2.setData(field2);
        _fitRecording3.setData(field3);
        _fitRecording4.setData(field4);
    }

    public function onSettingsChanged() as Void { }

/*
    public function initialize(dataField as DataField) {
            mRecordFields = new Field[MAX_NUMBER_OF_FIELDS];
            onSettingsChanged(dataField);
    }
    
    public function onSettingsChanged(dataField as DataField) as Void {
        mFieldSize = getConfigNumber(PROPERTY_FIELD_SIZE, PROPERTY_FIELD_SIZE_DEFAULT);
        switch (mFieldSize) {
            case 2: mFieldType = Fit.DATA_TYPE_UINT16; break;
            case 4: mFieldType = Fit.DATA_TYPE_UINT32; break;
            case 1:
            default:
                mFieldType = Fit.DATA_TYPE_UINT8; break;
        }

        var numberOfRecordFields = getConfigNumber(PROPERTY_NUMBER_OF_RECORD_FIELDS, PROPERTY_NUMBER_OF_RECORD_FIELDS_DEFAULT);
        if (numberOfRecordFields != mNumberOfRecordFields) {
            for (var f = mNumberOfRecordFields; f < numberOfRecordFields; ++f) {
                var field = dataField.createField("record_field_" + f, f + 2 * MAX_NUMBER_OF_FIELDS, mFieldType, { :mesgType=>Fit.MESG_TYPE_RECORD });
                field.setData(f);
                mRecordFields[f] = field;
            }
            mNumberOfRecordFields = numberOfRecordFields;
        }
        WatchUi.requestUpdate();
    }

    public function setData() as Void {
        for (var f = 0; f < mNumberOfRecordFields; ++f) {
            var field = mRecordFields[f];
            if (field != null) {
                field.setData(f);
            }
        }
    }
*/
}
