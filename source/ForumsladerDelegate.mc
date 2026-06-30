import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

class ForumsladerDelegate extends BleDelegate {

    private var
        _onScanResult as WeakReference?,
        _onConnection as WeakReference?,
        _onCharWrite as WeakReference?,
        _onDescWrite as WeakReference?,
        _onProfileRegister as WeakReference?,
        _registeredProfiles as Array<Uuid> = [] as Array<Uuid>;

    //! Constructor
    public function initialize() {
        BleDelegate.initialize();
        // Pre-register profiles at startup to avoid delays during pairing
        try {
            BluetoothLowEnergy.registerProfile($.FL6_profile);
            rememberProfile($.FL6_SERVICE);
            debug("registered FL6 profile");
        }
        catch(ex instanceof BluetoothLowEnergy.ProfileRegistrationException) {
            // ignore duplicate or already-registered profile errors
        }
        try {
            BluetoothLowEnergy.registerProfile($.FL5_profile);
            rememberProfile($.FL5_SERVICE);
            debug("registered FL5 profile");
        }
        catch(ex instanceof BluetoothLowEnergy.ProfileRegistrationException) {
            // ignore duplicate or already-registered profile errors
        }
    }

    //! Handle new Scan Results being received
    //! @param scanResults An iterator of new scan result objects
    public function onScanResults(scanResults as Iterator) as Void {
        for (var result = scanResults.next(); result != null; result = scanResults.next()) {
            if (result instanceof ScanResult) {
                if (ProcessScanRecord(result as ScanResult)) {
                    return;
                }
            }
        }
    }

    //! Process a scan record
    //! @param scanRecord scan result object
    //! @return true if forumslader was found with scan record, false otherwise
    public function ProcessScanRecord(result as ScanResult) as Boolean {
        // identify FLv6 by advertised name
        var _deviceName = result.getDeviceName() as String;
        if (_deviceName != null) {
            if (_deviceName.equals("FLV6") || _deviceName.equals("flv6") || _deviceName.equals("FL_BLE") || _deviceName.equals("fl_ble")) {
                broadcastScanResult(result);
                return true;
            }
        }
        // identify FLv5 by manufacturer ID
        var iter = result.getManufacturerSpecificDataIterator();
        for (var dict = iter.next() as Dictionary; dict != null; dict = iter.next()) {
            if (dict.get(:companyId) == 0x4d48) {
                broadcastScanResult(result);
                return true;
            }
        }
        return false;
    }

    //! @param device, state connection state change
    public function onConnectedStateChanged(device as Device, state as ConnectionState) as Void {
        var onConnection = _onConnection;
        if (state == BluetoothLowEnergy.CONNECTION_STATE_CONNECTED) {
            debug("connected");
            if (null != onConnection && onConnection.stillAlive()) {
                (onConnection.get() as DeviceManager).procConnection(device);
            }
        } else {
            // clear flags before setting global state
            if (null != onConnection && onConnection.stillAlive()) {
                var manager = (onConnection.get() as DeviceManager);
                manager.procDisconnect();
                manager.notifyDisconnect();
            }
            debug("disconnected, state=" + state);
        }
    }

    //! Appends $FLx BLE payload to buffer; capped at MAX_PAYLOAD_SIZE.
    public function onCharacteristicChanged(characteristic as Characteristic, data as ByteArray) as Void {
        var payload = $.FLpayload;
        var remaining = $.MAX_PAYLOAD_SIZE - payload.size();
        // note: while user is in settings menu, compute() is not called, so buffer may fill up
        if (remaining > 0) {
            payload.addAll(remaining >= data.size() ? data : data.slice(0, remaining));
        }
        //debug("onCharChanged, payload size=" + payload.size() + ", remaining=" + remaining);
    }

    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function onCharacteristicWrite(characteristic as Characteristic, status as Status) as Void {
        //debug("onCharWrite");
        var onCharWrite = _onCharWrite;
        if (null != onCharWrite) {
            if (onCharWrite.stillAlive()) {
                (onCharWrite.get() as DeviceManager).procCharWrite(characteristic, status);
            } else {
                debug ("procCharWrite disrupted");
            }
        }
    }

    //! Handle the completion of a write operation on a descriptor
    //! @param descriptor The descriptor that was written
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function onDescriptorWrite(descriptor as Descriptor, status as Status) as Void {
        //debug("onDescrWrite");
        var onDescWrite = _onDescWrite;
        if (null != onDescWrite) {
            if (onDescWrite.stillAlive()) {
                (onDescWrite.get() as DeviceManager).procDescWrite(descriptor, status);
            } else {
                debug ("procDescWrite disrupted");
            }
        }
    }

    //! Handle the completion of a profile registration
    //! @param uuid Profile UUID that this callback is related to
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function onProfileRegister(uuid as Uuid, status as Status) as Void {
        if (status == BluetoothLowEnergy.STATUS_SUCCESS && !isProfileRegistered(uuid)) {
            rememberProfile(uuid);
        }
        var onProfileRegister = _onProfileRegister;
        if (null != onProfileRegister) {
            if (onProfileRegister.stillAlive()) {
                (onProfileRegister.get() as DeviceManager).procProfileRegister(uuid, status);
            }
        }
    }

    private function isProfileRegistered(uuid as Uuid) as Boolean {
        var size = _registeredProfiles.size();
        for (var i = 0; i < size; i++) {
            if (_registeredProfiles[i].equals(uuid)) {
                return true;
            }
        }
        return false;
    }

    private function rememberProfile(uuid as Uuid) as Void {
        _registeredProfiles.add(uuid);
    }

    /*
    // unused callbacks
    public function onCharacteristicRead(characteristic as BluetoothLowEnergy.Characteristic, status as BluetoothLowEnergy.Status, value as Lang.ByteArray) as Void {
         debug("onCharacteristicRead");
    }
    public function onDescriptorRead(descriptor as BluetoothLowEnergy.Descriptor, status as BluetoothLowEnergy.Status, value as Lang.ByteArray) as Void {
         debug("onDescriptorRead");
    }
    public function onScanStateChange(scanState as BluetoothLowEnergy.ScanState, status as BluetoothLowEnergy.Status) as Void {
         debug("onScanStateChange");
    }
    public function onEncryptionStatus(device as BluetoothLowEnergy.Device, status as BluetoothLowEnergy.Status) as Void {
         debug("onEncryptionStatus = " + status);
    }
    */

    //! Broadcast a new scan result
    //! @param scanResult The new scan result
    private function broadcastScanResult(scanResult as ScanResult) as Void {
        var onScanResult = _onScanResult;
        if (null != onScanResult) {
            if (onScanResult.stillAlive()) {
                (onScanResult.get() as DeviceManager).procScanResult(scanResult);
            } else {
                debug ("procScanResult disrupted");
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

