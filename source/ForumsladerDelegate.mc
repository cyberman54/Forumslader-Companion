import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

var isConnected as Boolean = false;

class ForumsladerDelegate extends BluetoothLowEnergy.BleDelegate {

    private var 
        _onScanResult as WeakReference?,
        _onConnection as WeakReference?,
        _onCharWrite as WeakReference?,
        _onDescWrite as WeakReference?,
        _onProfileRegister as WeakReference?;
    
	//! Constructor
    public function initialize() {
        BleDelegate.initialize();
    }

	//! Handle new Scan Results being received
    //! @param scanResults An iterator of new scan result objects
    public function onScanResults(scanResults as Iterator) as Void {
        for (var result = scanResults.next(); result != null; result = scanResults.next()) {
            if (result instanceof ScanResult) {
                // identify a forumslader device by it's advertised local name
                var _deviceName = result.getDeviceName() as String;
                if (_deviceName != null) { 
                    if (_deviceName.equals("FLV6") || _deviceName.equals("FL_BLE")) {
                        //debug("found FL by Devicename: " + _deviceName);
                        broadcastScanResult(result);
                        return;
                    }
                } 
                // identify a FLV5 forumslader device by it's advertised manufacturer ID
                var iter = result.getManufacturerSpecificDataIterator();
                for (var dict = iter.next() as Dictionary; dict != null; dict = iter.next()) {
                    if (dict.get(:companyId) == 0x4d48) {
                        //debug("found FL by Company ID");
                        broadcastScanResult(result);
                        return;
                    }
                }
            }
        }
    }

    //! Broadcast a new scan result
    //! @param scanResult The new scan result
    private function broadcastScanResult(scanResult as ScanResult) as Void {
        var onScanResult = _onScanResult;
        if (onScanResult != null) {
            if (onScanResult.stillAlive()) {
                (onScanResult.get() as DeviceManager).procScanResult(scanResult);
            } else {
                //debug ("procScanResult disrupted");
            }
        }
    }

    //! Get whether the iterator contains a specific uuid
    //! @param iter Iterator of uuid objects
    //! @param obj Uuid to search for
    //! @return true if object found, false otherwise
    private function contains(iter as Iterator, obj as Uuid) as Boolean {
        for (var uuid = iter.next(); uuid != null; uuid = iter.next()) {
            if (uuid.equals(obj)) {
				//debug("found="+uuid.toString());
                return true;
            }
        }
        return false;
    }

    //! Handle pairing and connecting to a device
    //! @param device The device state that was changed
    //! @param state The state of the connection
    public function onConnectedStateChanged(device as Device, state as ConnectionState) as Void {
        var onConnection = _onConnection;
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            //debug ("connected");
            if (onConnection != null) {
                if (onConnection.stillAlive()) {
                    (onConnection.get() as DeviceManager).procConnection(device);
                } else {
                    //debug ("procConnection disrupted");
                }
            }
        } else {
            //debug ("disconnected");
            $.FLstate = FL_DISCONNECT;
        }
    }

	//! Handle the completion of notification on a characteristic change, store $FLx payload in buffer
    //! @param characteristic The characteristic that notified
    //! @param data The data which is delivered by the characteristic
	public function onCharacteristicChanged(characteristic as Characteristic, data as ByteArray) as Void {
		//debug("onCharChanged");
        if (null != data) {
            $.FLpayload.addAll(data);
		}
	}

    //! Handle the completion of a write operation on a characteristic
    //! @param characteristic The characteristic that was written
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function onCharacteristicWrite(characteristic as Characteristic, status as Status) as Void {
        //debug("onCharWrite");
        var onCharWrite = _onCharWrite;
        if (onCharWrite != null) {
            if (onCharWrite.stillAlive()) {
                (onCharWrite.get() as DeviceManager).procCharWrite(characteristic, status);
            } else {
                //debug ("procCharWrite disrupted");
            }
        }
    }

    //! Handle the completion of a write operation on a descriptor
    //! @param descriptor The descriptor that was written
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function onDescriptorWrite(descriptor as Descriptor, status as Status) as Void {
        //debug("onDescrWrite");
        var onDescWrite = _onDescWrite;
        if (onDescWrite != null) {
            if (onDescWrite.stillAlive()) {
                (onDescWrite.get() as DeviceManager).procDescWrite(descriptor, status);
            } else {
                //debug ("procDescWrite disrupted");
            }
        }
    }

    //! Handle the completion of a profile registration
    //! @param uuid Profile UUID that this callback is related to
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function onProfileRegister(uuid as Uuid, status as Status) as Void {
        //debug("onProfileRegister");
        var onProfileRegister = _onProfileRegister;
        if (onProfileRegister != null) {
            if (onProfileRegister.stillAlive()) {
                (onProfileRegister.get() as DeviceManager).procProfileRegister(uuid, status);
            } else {
                //debug ("procProfileRegister disrupted");
            }
        }
    }

    //! Store a new manager to manage scan results
    //! @param manager The manager of the scan results
    public function notifyScanResult(manager as DeviceManager) as Void {
        _onScanResult = manager.weak();
    }

    //! Store a new manager to manage device connections
    //! @param manager The manager for devices
    public function notifyConnection(manager as DeviceManager) as Void {
        _onConnection = manager.weak();
    }

    //! Store a new manager to handle characteristic writes
    //! @param manager The manager for characteristics
    public function notifyCharWrite(manager as DeviceManager) as Void {
        _onCharWrite = manager.weak();
    }

    //! Store a new manager to handle descriptor writes
    //! @param manager The manager for characteristics
    public function notifyDescWrite(manager as DeviceManager) as Void {
        _onDescWrite = manager.weak();
    }

    //! Store a new manager to handle profile registration
    //! @param manager The manager for characteristics
    public function notifyProfileRegister(manager as DeviceManager) as Void {
        _onProfileRegister = manager.weak();
    }
}