import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

class ProfileManager {

    //! Service UUIDs of Forumslader v5/v6
    public const 
        FL5_SERVICE as BluetoothLowEnergy.Uuid = BluetoothLowEnergy.stringToUuid("0000ffe0-0000-1000-8000-00805f9b34fb"),
        FL6_SERVICE as BluetoothLowEnergy.Uuid = BluetoothLowEnergy.stringToUuid("6e40ffe2-b5a3-f393-e0a9-e50e24dcca9e");

    //! Characteristic UUIDs of Forumslader v5/v6
    private const 
        _FL5_RX_CHARACTERISTIC as BluetoothLowEnergy.Uuid = BluetoothLowEnergy.stringToUuid("0000ef38-0000-1000-8000-00805f9b34fb"),
        _FL6_RX_CHARACTERISTIC as BluetoothLowEnergy.Uuid = BluetoothLowEnergy.stringToUuid("6e40ef38-b5a3-f393-e0a9-e50e24dcca9e"),
        _FL6_TX_CHARACTERISTIC as BluetoothLowEnergy.Uuid = BluetoothLowEnergy.stringToUuid("6e40ef39-b5a3-f393-e0a9-e50e24dcca9e");
    
    //! UUIDs of the identified device, will be reassigned dynamically
    public var 
        FL_SERVICE as BluetoothLowEnergy.Uuid   = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-00805f9b34fb"),
        FL_CONFIG as BluetoothLowEnergy.Uuid    = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-00805f9b34fb"),
        FL_COMMAND as BluetoothLowEnergy.Uuid   = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-00805f9b34fb");

    //! Register all BLE profiles
    public function registerProfiles() as Void {
        //! BLE profile for Forumslader v5
        var _profileV5 = {
        :uuid => FL5_SERVICE,
        :characteristics => [{
                :uuid => _FL5_RX_CHARACTERISTIC,
                :descriptors => [BluetoothLowEnergy.cccdUuid()]
            }
        ]
        };
        BluetoothLowEnergy.registerProfile(_profileV5);

        //! Register BLE profile for Forumslader v6
        var _profileV6 = {
        :uuid => FL6_SERVICE,
        :characteristics => [{
                :uuid => _FL6_RX_CHARACTERISTIC,
                :descriptors => [BluetoothLowEnergy.cccdUuid()]
            }, {
                :uuid => _FL6_TX_CHARACTERISTIC,
                :descriptors => [BluetoothLowEnergy.cccdUuid()]
            },
        ]
        };
        BluetoothLowEnergy.registerProfile(_profileV6);
    }

    //! Identify the forumslader type and setup it's UUIDs
    //! @param Device to be validated as forumslader
    //! @return Boolean to indicate if the device was identified as a forumslader
    public function isForumslader(device as Device) as Boolean {
        var rc = false;

        if (device != null) {
            // select FL type
			var iter = device.getServices();
			for (var r = iter.next(); r != null; r = iter.next())
			{
				r = r as Service;
				if (r != null)
				{
					if (r.getUuid().equals(FL5_SERVICE))
					{
						FL_SERVICE = FL5_SERVICE;
						FL_CONFIG = _FL5_RX_CHARACTERISTIC;
						FL_COMMAND = _FL5_RX_CHARACTERISTIC;
                        rc = true;
                        $.isV6 = false;
                        //debug("FLv5 detected");
					}
					else {
						if (r.getUuid().equals(FL6_SERVICE))
						{
							FL_SERVICE = FL6_SERVICE;
							FL_CONFIG = _FL6_RX_CHARACTERISTIC;
							FL_COMMAND = _FL6_TX_CHARACTERISTIC;
                            rc = true;
                            $.isV6 = true;
                            //debug("FLv6 detected");
						}
					}
				}
			}
        }
        return rc;
    }

}