import Toybox.Lang;
using Toybox.FitContributor as Fit;
import Toybox.FitContributor;
import Toybox.WatchUi;

const MAX_NUMBER_OF_FIELDS = 32;

const PROPERTY_NUMBER_OF_SESSION_FIELDS = "s";
const PROPERTY_NUMBER_OF_SESSION_FIELDS_DEFAULT = 0;
const PROPERTY_NUMBER_OF_LAP_FIELDS = "l";
const PROPERTY_NUMBER_OF_LAP_FIELDS_DEFAULT = 0;
const PROPERTY_NUMBER_OF_RECORD_FIELDS = "r";
const PROPERTY_NUMBER_OF_RECORD_FIELDS_DEFAULT = 0;
const PROPERTY_FIELD_SIZE = "w";
const PROPERTY_FIELD_SIZE_DEFAULT = 1;

class ForumsladerFitContributor {

    private var mNumberOfRecordFields as Number = 0;
    private var mRecordFields as Array<Field?>;

    private var mFieldSize as Number = PROPERTY_FIELD_SIZE_DEFAULT;
    private var mFieldType as Fit.DataType = Fit.DATA_TYPE_UINT8;

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

}
