import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.Application.Storage;

// app states
enum {
    FL_SCANNING = 0, // 0 = scanning for forumslader devices
    FL_COLDSTART,    // 1 = cold start after pairing (full setup process)
    FL_CONFIG1,      // 2 = configuration step 1 (request parameters, wait for data stream to be active)
    FL_CONFIG2,      // 3 = configuration step 2 (wait for valid parameters in data stream)
    FL_CONFIG3,      // 4 = configuration step 3 (fallback, if parameters were not valid in CONFIG2, request parameters again)
    FL_DISCONNECT,   // 5 = device disconnected, waiting for reconnect (can be triggered by disconnect event or by failed setup)
    FL_WARMSTART,    // 6 = warm start after disconnect (skip setup process, just restart data stream)
    FL_RUNNING       // 7 = device is connected and configured, data stream is active
}

class DeviceManager {

    private const
        // RSSI threshold for pairing, to avoid pairing with devices that are too far away and thus have an unstable connection.
        // This is especially important for the auto-locking feature, as a stable connection is required to reliably detect when the user leaves the bike.
        _RSSI_threshold = -85,
        // command to start data stream on FLv6: 0x01,0x00 (notification bit in cccd)
        FL6_START = [0x01, 0x00]b,
        // command to request wheel size and pole count from the forumslader device: $FLT,5*46<lf>
        FLP = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x35, 0x2A, 0x34, 0x37, 0x0a]b,
        NULL_UUID = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-000000000000");

    private var
        _delegate as ForumsladerDelegate,
        _data as DataManager,
        _device as Device?,
        _service as Service?,
        _command as Characteristic?,
        _config as Characteristic?,
        _writeInProgress as Boolean = false,
        _configDone as Boolean = false,
        _FL_SERVICE as Uuid = NULL_UUID,
        _FL_CONFIG as Uuid = NULL_UUID,
        _FL_COMMAND as Uuid = NULL_UUID;

    private static var 
        _myDevice as ScanResult?;

    //! Constructor
    //! @param bleDelegate The BLE delegate which provides the functions for asynchronous BLE callbacks
    //! @param dataManager The DataManager class which processes the received data stream of the BLE device
    public function initialize(bleDelegate as ForumsladerDelegate, dataManager as DataManager) {
        _device = null;
        _delegate = bleDelegate;
        _data = dataManager;
        _myDevice = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult?;
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

    //! Start BLE scanning
    public function startScan() as Void {
        // Ensure _writeInProgress is reset for clean state
        _writeInProgress = false;

        // Try direct pairing with stored device if DeviceLock enabled
        if ($.UserSettings[$.DeviceLock] == true) {
            var storedDevice = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult;
            if (storedDevice != null) {
                try {
                    // Only attempt pairing if not already in a state transition
                    if ($.FLstate == FL_SCANNING || $.FLstate == FL_DISCONNECT) {
                        BluetoothLowEnergy.pairDevice(storedDevice);
                        _myDevice = storedDevice;
                        debug("DeviceLock: found stored device, trying to pair directly");
                        _delegate.ProcessScanRecord(storedDevice); // Process the stored device as if it was just scanned to trigger connection flow
                        return;
                    }
                }
                catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
                    debug("DeviceLock: stored device pairing failed: " + ex.getErrorMessage());
                    _myDevice = null;
                    // Fall through to normal scanning
                }
            }
        }

        // Start normal scanning
        debug("scanning");
        if (_device != null) {
            BluetoothLowEnergy.unpairDevice(_device);
        }
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        self._setState(FL_SCANNING);
        _configDone = false;
        _myDevice = null;  // Clear old reference
    }

    //! Process scan result of incoming BLE advertises
    //! @param scanResult The scan result
    public function procScanResult(scanResult as ScanResult) as Void {
        // Race Condition State Guard: Only process scan results when actively searching
        if ($.FLstate != FL_SCANNING) {
            return;
        }
        // Pair the first Forumslader we see with good RSSI
        // This is a critical point for the auto-locking feature, as a stable connection is required to reliably detect when the user leaves the bike, so we only attempt pairing with devices that have a strong signal (i.e. are nearby)
        // We also check if the device is already paired to avoid unnecessary pairing attempts, which can save time and reduce the chance of pairing failures due to interference or other issues.
        if (scanResult.getRssi() > _RSSI_threshold) {

            // Stop scanning to save resources, as we found a device with good signal. If it's not the right device or pairing fails, we'll restart scanning in the catch block.    
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);

            // if the device is already paired, we can skip the pairing process to save time
            if (_myDevice != null && _myDevice == scanResult) {
                return;
            }
            // Pairing can sometimes fail due to interference or other issues, so we wrap it in a try-catch block
            try {
                BluetoothLowEnergy.pairDevice(scanResult);
                debug("paired");
                _myDevice = scanResult;
                saveDevice(); // Save the newly paired device if device lock is enabled
                }
            // if the pairing process is disrupted, restart scanning, but only if we're still in the scanning state, to avoid interfering with other states
            catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
                debug("cannot pair device " + scanResult.getDeviceName());
                debug("error: " + ex.getErrorMessage());
                if ($.FLstate == FL_SCANNING) {
                    BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
                }
                _myDevice = null;
                }
            } else {
            debug("signal too weak, rssi " + scanResult.getRssi());
        }
    }

    //! Process a new device connection
    //! @param device The device that was connected
    public function procConnection(device as Device) as Void {
        if (device != null && device.isConnected()) {
            _device = device;
            _writeInProgress = false;  // Reset write flag on successful connection
            // Set state ONLY if we're actually starting fresh
            // Don't override if already in a valid state (e.g. CONFIG1-3) to avoid disrupting the setup process
            if ($.FLstate == FL_SCANNING || $.FLstate == FL_DISCONNECT) {
                self._setState(_configDone ? FL_WARMSTART : FL_COLDSTART);
            }
        } else {
            debug("connection failed, restarting scan");
            _writeInProgress = false;
            _device = null;
            startScan();
        }
    }

    //! Handle device disconnect and restart scanning immediately
    public function procDisconnect() as Void {
        _writeInProgress = false;
        _device = null;  // Clear device reference immediately
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

    //! Send command to forumslader device
    //! @param cmd as command ByteArray
    private function sendCommandFL(cmd as ByteArray) as Void {
        if ((null == _device) || _writeInProgress || null == _command) {
            return;
        }
        _writeInProgress = true;
        _command.requestWrite(cmd, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
    }

    //! identify forumslader and get characteristic of it's GATT service
    //! @return Boolean to indicate if the setup was successful (i.e. a forumslader was identified and the characteristics were found)
    private function setupProfile() as Boolean {
        if (_device == null || !_device.isConnected()) {
            return false;
        }

        // Wrap iterator in try-catch for disconnect during iteration
        try {
            if (!isForumslader(_device)) {
                debug("error: connected device is not a forumslader V5/V6");
                if (_device != null && _device.isConnected()) {
                    startScan();
                }
                return false;
            }
        } catch(ex instanceof Exception) {
            debug("Exception in isForumslader: " + ex.getErrorMessage());
            return false;
        }

        // Race protection: Check device still connected before getService
        if (_device == null || !_device.isConnected()) {
            return false;
        }
        _service = (_device as Device).getService(_FL_SERVICE);
        if (null == _service) {
            if (_device != null && _device.isConnected()) {
                startScan();
            }
            return false;
        }

        _command = _service.getCharacteristic(_FL_COMMAND);
        _config = _service.getCharacteristic(_FL_CONFIG);
        return true;
    }

    //! This function is called from the settings menu when the user changes the DeviceLock setting, to either save the currently paired device or to clear the stored device, depending on the new value of the DeviceLock setting.
    //! It is also called from the onSettingsChanged callback of the app, to persist the device immediately when the user changes the setting in the GCM while the app is running.
    /// The function checks the current value of the DeviceLock setting and either saves the currently paired device to storage (if DeviceLock is enabled) or clears the stored device from storage (if DeviceLock is disabled).
    public static function saveDevice () as Void {
        var storedDevice = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult?;
        if ($.UserSettings[$.DeviceLock] == false && storedDevice != null) {
            Storage.deleteValue("MyDevice");
            debug("DeviceLock: device cleared");
            return;
        }
        if ($.UserSettings[$.DeviceLock] == true && storedDevice != null && !storedDevice.equals(_myDevice)) {
            Storage.setValue("MyDevice", _myDevice);
            debug("DeviceLock: device saved");
            return;
            }
    }

    //! Identify the forumslader type and setup its UUIDs
    //! @param Device to be validated as forumslader
    //! @return Boolean to indicate if the device was identified as a forumslader
    private function isForumslader(device as Device or Null) as Boolean {
        _FL_SERVICE = NULL_UUID;
        _FL_CONFIG = NULL_UUID;
        _FL_COMMAND = NULL_UUID;

        // Race protection: Service Iterator Disconnect Check
        if (device == null || !device.isConnected()) {
            debug("Device is null or disconnected in isForumslader");
            return false;
        }

        // Race protection: Iterator might fail if device disconnects - wrap in try-catch
        try {
            
            var iter = device.getServices();
            for (var service = iter.next(); service != null; service = iter.next()) {
                // Check device still connected during iteration
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

    //! Write notification to descriptor to start data stream on forumslader device
    //! For FLv5 this is not needed, as it starts the data stream immediately after connection, but for FLv6 this is required to activate the data stream.
    private function startDatastreamFL() as Void {
        if (!$.isV6) {
            return;
        }
        // Validate device and config are still valid before accessing
        if (_device == null || !_device.isConnected() || _config == null) {
            return;
        }

        try {
            var cccd = _config.getDescriptor(BluetoothLowEnergy.cccdUuid());
            if (null != cccd) {
                // Race protection: Check device still connected before write
                if (_device.isConnected()) {
                    _writeInProgress = true;
                    cccd.requestWrite(FL6_START); // set notification bit
                }
            }
        } catch(ex instanceof Exception) {
            debug("Exception in startDatastreamFL: " + ex.getErrorMessage());
            _writeInProgress = false;
        }
    }

    //! Finite state machine
    //! This function is called after every relevant event (e.g. connection, data received, etc.) to update the state of the app and trigger the next steps in the setup process.
    public function updateState() as Number {
        var currentState = $.FLstate;

        switch(currentState) {
            // Idle-Zustände: Sofortiger Abbruch spart CPU-Zyklen
            case FL_RUNNING:
            case FL_SCANNING:
            case FL_DISCONNECT:
                break;

            // Kaltstart nach dem Pairing
            case FL_COLDSTART:
                if (setupProfile()) {
                    currentState = FL_CONFIG1;
                    startDatastreamFL();
                } else {
                    currentState = FL_SCANNING;
                }
                break;

            // Warmstart nach einem Verbindungsabbruch
            case FL_WARMSTART:
                currentState = FL_RUNNING;
                startDatastreamFL();
                break;

            // Parameter anfordern, sobald der Datenstrom aktiv ist
            case FL_CONFIG1:
                if (_data.age == 0) {
                    sendCommandFL(FLP); // Radgröße und Polanzahl anfordern
                    currentState = FL_CONFIG2;
                }
                break;

            // Wenn die Polanzahl > 0 ist, sind die Parameter gültig und die App kann in den READY-Zustand wechseln
            case FL_CONFIG2:
            case FL_CONFIG3:
                var fl = _data.FLdata;
                if (fl[FL_poles] > 0) {
                    _configDone = true;
                    currentState = FL_RUNNING;
                } else {
                    // Wenn beim ersten Mal (CONFIG2) fehlgeschlagen, gehe zu CONFIG3, sonst zurück zu CONFIG1
                    currentState = (currentState == FL_CONFIG2) ? FL_CONFIG3 : FL_CONFIG1;
                }
                break;

            // Fallback-Schutz
            default:
                currentState = FL_SCANNING;
                debug("state engine error");
                break;
        }

        // Den berechneten Zustand wieder zurückschreiben und zurückgeben
        self._setState(currentState);
        return currentState;
    }

}

