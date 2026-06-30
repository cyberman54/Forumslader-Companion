import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.Application.Storage;

// app states
enum {
    FL_SCANNING = 0, // scanning for Forumslader
    FL_COLDSTART,    // cold start after pairing
    FL_CONFIG1,      // config step 1: await data stream
    FL_CONFIG2,      // config step 2: await valid params
    FL_CONFIG3,      // config step 3: retry param request
    FL_DISCONNECT,   // disconnected; waiting to reconnect
    FL_WARMSTART,    // warm start: skip setup, restart stream
    FL_RUNNING       // connected and running
}

class DeviceManager {

    private const
        NULL_UUID = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-000000000000"),
        // min RSSI for pairing; prevents unstable connections, important for DeviceLock
        _RSSI_threshold = -85,
        // CCCD notification enable: start FLv6 data stream
        FL6_START = [0x01, 0x00]b,
        // $FLT,5: request FLP params (wheel size, pole count)
        FL_REQ_FLP = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x35, 0x2A, 0x34, 0x37, 0x0a]b,
        // $FLT,7: reset trip counter
        FL_TRIP_RESET = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x37, 0x2A, 0x34, 0x35, 0x0A]b,
        // $FLT,6: reset tour counter
        FL_TOUR_RESET = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x36, 0x2A, 0x34, 0x34, 0x0A]b;

    private var
        _delegate as ForumsladerDelegate,
        _data as DataManager,
        _connectedDevice as Device?,
        _service as Service?,
        _command as Characteristic?,
        _config as Characteristic?,
        _pairTarget as ScanResult?,
        _lockTarget as ScanResult?,
        _writeInProgress as Boolean = false,
        _configDone as Boolean = false,
        _FL_SERVICE as Uuid = NULL_UUID,
        _FL_CONFIG as Uuid = NULL_UUID,
        _FL_COMMAND as Uuid = NULL_UUID;

    //! @param bleDelegate BLE event callbacks
    //! @param dataManager incoming data processor
    public function initialize(bleDelegate as ForumsladerDelegate, dataManager as DataManager) {
        _delegate = bleDelegate;
        _data = dataManager;
        _connectedDevice = null;
        _pairTarget = null;
        _lockTarget = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult?;
        bleDelegate.notifyScanResult(self);
        bleDelegate.notifyConnection(self);
        bleDelegate.notifyCharWrite(self);
        bleDelegate.notifyDescWrite(self);
        bleDelegate.notifyProfileRegister(self);
    }

    private function _setState(state as Number) as Void {
        if ($.FLstate != state) {
            debug("FLstate " + $.FLstate + " -> " + state);
            $.FLstate = state;
        }
    }

    public function notifyDisconnect() as Void {
        self._setState(FL_DISCONNECT);
    }

    //! Starts BLE scanning, or directly pairs the locked device if DeviceLock is set.
    public function startScan() as Void {
        _writeInProgress = false; // reset write flag

        // DeviceLock: try direct pair
        if ($.UserSettings[$.DeviceLock] == true) {
            if (_lockTarget != null) {
                try {
                    if ($.FLstate == FL_SCANNING || $.FLstate == FL_DISCONNECT) {
                        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF); // stop scan before pairing
                        var targetDevice = _lockTarget as ScanResult;
                        _pairTarget = targetDevice;
                        _delegate.ProcessScanRecord(targetDevice);
                        BluetoothLowEnergy.pairDevice(targetDevice);
                        debug("DeviceLock: stored device paired");
                        return;
                    }
                }
                catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
                    debug("DeviceLock: stored device pairing failed: " + ex.getErrorMessage());
                    return;
                }
            }
        }

        debug("scanning");
        if (_connectedDevice != null) {
            BluetoothLowEnergy.unpairDevice(_connectedDevice);
        }
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        self._setState(FL_SCANNING);
        _configDone = false;
        _pairTarget = null;
    }

    //! Filters scan results and pairs the first suitable Forumslader.
    public function procScanResult(scanResult as ScanResult) as Void {
        // only while scanning
        if ($.FLstate != FL_SCANNING) {
            return;
        }

        var lockedDevice = _lockTarget; // local copy, avoids race
        if ($.UserSettings[$.DeviceLock] == true && lockedDevice != null && !lockedDevice.equals(scanResult)) {
            return;
        }

        // DeviceLock bypasses RSSI check
        var isDeviceLocked = $.UserSettings[$.DeviceLock] == true && lockedDevice != null && lockedDevice.equals(scanResult);
        var rssiThresholdPassed = scanResult.getRssi() > _RSSI_threshold;
        
        if (!isDeviceLocked && !rssiThresholdPassed) {
            debug("signal too weak, rssi " + scanResult.getRssi());
            return;
        }

        // stop scan; restart in catch if pairing fails    
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);

        // already targeting this device
        if (_pairTarget != null && _pairTarget.equals(scanResult)) {
            return;
        }
        try {
            BluetoothLowEnergy.pairDevice(scanResult);
            debug("paired");
            _pairTarget = scanResult;
            saveDevice();
        }
        catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
            debug("cannot pair device " + scanResult.getDeviceName());
            debug("error: " + ex.getErrorMessage());
            if ($.FLstate == FL_SCANNING) {
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            }
            _pairTarget = null;
        }
    }

    //! Handles new connection; transitions to cold or warm start.
    public function procConnection(device as Device) as Void {
        if (device != null && device.isConnected()) {
            _connectedDevice = device;
            _writeInProgress = false; // reset write flag
            // only transition from SCANNING/DISCONNECT
            if ($.FLstate == FL_SCANNING || $.FLstate == FL_DISCONNECT) {
                self._setState(_configDone ? FL_WARMSTART : FL_COLDSTART);
            }
        } else {
            debug("connection failed, restarting scan");
            _writeInProgress = false;
            _connectedDevice = null;
            startScan();
        }
    }

    //! Clears connection state on disconnect.
    public function procDisconnect() as Void {
        _writeInProgress = false;
        _connectedDevice = null;
    }

    //! Handle the completion of a write operation on a characteristic
    //! @param char The characteristic that was written
    //! @param status The result of the operation
    public function procCharWrite(char as Characteristic, status as Status) as Void {
        _writeInProgress = false;
    }

    //! Handle the completion of a write operation on a descriptor
    //! @param char The descriptor that was written
    //! @param status The result of the operation
    public function procDescWrite(desc as Descriptor, status as Status) as Void {
        _writeInProgress = false;
    }

    //! Handle the completion of a profile registration
    //! @param uuid Profile UUID that this callback is related to
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function procProfileRegister(uuid as Uuid, status as Status) as Void {
    }

    //! Send trip reset command to the Forumslader device
    public function resetTrip() as Void {
        sendCommandFL(FL_TRIP_RESET);
        debug("Trip reset command sent");
    }

    //! Send tour reset command to the Forumslader device
    public function resetTour() as Void {
        sendCommandFL(FL_TOUR_RESET);
        debug("Tour reset command sent");
    }

    //! @param cmd raw command bytes
    private function sendCommandFL(cmd as ByteArray) as Void {
        if ((null == _connectedDevice) || _writeInProgress || null == _command) {
            return;
        }
        _writeInProgress = true;
        try {
            _command.requestWrite(cmd, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
        } catch(ex instanceof Exception) {
            debug("Exception in sendCommandFL: " + ex.getErrorMessage());
            _writeInProgress = false;
        }
    }

    //! Gets the Forumslader GATT service and caches its characteristics.
    //! @return true on success
    private function setupProfile() as Boolean {
        if (_connectedDevice == null || !_connectedDevice.isConnected()) {
            return false;
        }

        try {
            if (!isForumslader(_connectedDevice)) {
                debug("error: connected device is not a forumslader V5/V6");
                if (_connectedDevice != null && _connectedDevice.isConnected()) {
                    startScan();
                }
                return false;
            }
        } catch(ex instanceof Exception) {
            debug("Exception in isForumslader: " + ex.getErrorMessage());
            return false;
        }

        // recheck connection before getService
        if (_connectedDevice == null || !_connectedDevice.isConnected()) {
            return false;
        }
        _service = (_connectedDevice as Device).getService(_FL_SERVICE);
        if (null == _service) {
            if (_connectedDevice != null && _connectedDevice.isConnected()) {
                startScan();
            }
            return false;
        }

        _command = _service.getCharacteristic(_FL_COMMAND);
        _config = _service.getCharacteristic(_FL_CONFIG);
        return true;
    }

    //! Persists or clears the locked device in storage based on DeviceLock setting.
    public function saveDevice () as Void {
        var storedDevice = _lockTarget;
        if ($.UserSettings[$.DeviceLock] == false && storedDevice != null) {
            Storage.deleteValue("MyDevice");
            _lockTarget = null;
            debug("DeviceLock: device cleared");
            return;
        }
        if ($.UserSettings[$.DeviceLock] == true && storedDevice != null && storedDevice.equals(_pairTarget)) {
            debug("DeviceLock: Device equal to stored device, no action needed");
            return; // No change, avoid unnecessary write
        }
        if ($.UserSettings[$.DeviceLock] == true && _pairTarget != null) {
            Storage.setValue("MyDevice", _pairTarget);
            _lockTarget = _pairTarget;
            debug("DeviceLock: device saved");
            return;
        }
        debug("DeviceLock: no device to save or clear, no action taken");
    }

    //! Identifies the Forumslader version and sets service/characteristic UUIDs.
    //! @return true if a v5 or v6 service was found
    private function isForumslader(device as Device or Null) as Boolean {
        _FL_SERVICE = NULL_UUID;
        _FL_CONFIG = NULL_UUID;
        _FL_COMMAND = NULL_UUID;

        if (device == null || !device.isConnected()) {
            debug("Device is null or disconnected in isForumslader");
            return false;
        }

        // guard against disconnect during iteration
        try {
            var iter = device.getServices();
            for (var service = iter.next(); service != null; service = iter.next()) {
                // recheck during iteration
                if (!device.isConnected()) {
                    debug("Device disconnected during service iteration");
                    return false;
                }
            
                service = service as Service;
                var uuid = service.getUuid();
                debug("checking service " + uuid.toString());

                if (uuid.equals($.FL5_SERVICE)) {
                    _FL_SERVICE = $.FL5_SERVICE;
                    _FL_CONFIG = $.FL5_RXTX_CHARACTERISTIC;
                    _FL_COMMAND = $.FL5_RXTX_CHARACTERISTIC;
                    $.isV6 = false;
                    debug("FLv5");
                    return true;
                }

                if (uuid.equals($.FL6_SERVICE)) {
                    _FL_SERVICE = $.FL6_SERVICE;
                    _FL_CONFIG = $.FL6_RX_CHARACTERISTIC;
                    _FL_COMMAND = $.FL6_TX_CHARACTERISTIC;
                    $.isV6 = true;
                    debug("FLv6");
                    return true;
                }
            }
        } catch(ex instanceof Exception) {
            debug("Exception during service iteration: " + ex.getErrorMessage());
            return false;
        }
        debug("no matching service found");
        return false;
    }

    //! Enables BLE notifications on FLv6 RX characteristic to start the data stream.
    private function startDatastreamFL() as Void {
        if (!$.isV6) {
            return;
        }
        if (_connectedDevice == null || !_connectedDevice.isConnected() || _config == null) {
            return;
        }

        try {
            var cccd = _config.getDescriptor(BluetoothLowEnergy.cccdUuid());
            if (null != cccd) {
                // recheck connection
                if (_connectedDevice.isConnected()) {
                    _writeInProgress = true;
                    cccd.requestWrite(FL6_START); // set notification bit
                }
            }
        } catch(ex instanceof Exception) {
            debug("Exception in startDatastreamFL: " + ex.getErrorMessage());
            _writeInProgress = false;
        }
    }

    //! Advances the setup FSM; call after every BLE event.
    public function updateState() as Number {
        var currentState = $.FLstate;

        switch(currentState) {
            // idle: no action
            case FL_RUNNING:
            case FL_SCANNING:
            case FL_DISCONNECT:
                break;

            // Cold start after pairing
            case FL_COLDSTART:
                if (setupProfile()) {
                    currentState = FL_CONFIG1;
                    startDatastreamFL();
                } else {
                    currentState = FL_SCANNING;
                }
                break;

            // Warm start after a connection drop
            case FL_WARMSTART:
                currentState = FL_RUNNING;
                startDatastreamFL();
                break;

            // Request parameters as soon as the data stream is active
            case FL_CONFIG1:
                if (_data.age == 0) {
                    sendCommandFL(FL_REQ_FLP); // Request wheel size and pole count
                    currentState = FL_CONFIG2;
                }
                break;

            // If pole count > 0, parameters are valid and the app can transition to READY state
            case FL_CONFIG2:
            case FL_CONFIG3:
                var fl = _data.FLdata;
                if (fl[FL_poles] > 0) {
                    _configDone = true;
                    currentState = FL_RUNNING;
                } else {
                    // If failed on the first attempt (CONFIG2), go to CONFIG3, otherwise back to CONFIG1
                    currentState = (currentState == FL_CONFIG2) ? FL_CONFIG3 : FL_CONFIG1;
                }
                break;

            // Fallback-Schutz
            default:
                currentState = FL_SCANNING;
                debug("state engine error");
                break;
        }

        // Write the calculated state back and return it
        self._setState(currentState);
        return currentState;
    }

}

