import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

//! BLE profiles for Forumslader v5/v6
const
    //! Service UUIDs
    FL5_SERVICE as Uuid = BluetoothLowEnergy.stringToUuid("0000ffe0-0000-1000-8000-00805f9b34fb"),
    FL6_SERVICE as Uuid = BluetoothLowEnergy.stringToUuid("6e40ffe2-b5a3-f393-e0a9-e50e24dcca9e"),

    //! Characteristic UUIDs
    FL5_RXTX_CHARACTERISTIC as Uuid = BluetoothLowEnergy.stringToUuid("0000ef38-0000-1000-8000-00805f9b34fb"),
    FL6_RX_CHARACTERISTIC as Uuid = BluetoothLowEnergy.stringToUuid("6e40ef38-b5a3-f393-e0a9-e50e24dcca9e"),
    FL6_TX_CHARACTERISTIC as Uuid = BluetoothLowEnergy.stringToUuid("6e40ef39-b5a3-f393-e0a9-e50e24dcca9e"),

    //! Common descriptor array, reused for all characteristics
    FL_CCCD_DESCRIPTORS as Array<Uuid> = [BluetoothLowEnergy.cccdUuid()] as Array<Uuid>,

    //! profile v5
    FL5_profile = {
        :uuid => FL5_SERVICE,
        :characteristics => [{
                :uuid => FL5_RXTX_CHARACTERISTIC,
                :descriptors => FL_CCCD_DESCRIPTORS
            }]
    },

    //! profile v6
    FL6_profile = {
        :uuid => FL6_SERVICE,
        :characteristics => [{
                :uuid => FL6_RX_CHARACTERISTIC,
                :descriptors => FL_CCCD_DESCRIPTORS
            }, {
                :uuid => FL6_TX_CHARACTERISTIC,
                :descriptors => FL_CCCD_DESCRIPTORS
            }]
    };

