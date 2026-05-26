import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.Application.Storage;

// app states
enum {
    FL_SEARCH = 0,  // 0 = entry state (waiting for pairing & connect)
    FL_COLDSTART,   // 1 = request $FLP data and start $FLx data stream
    FL_CONFIG1,     // 2 = configuration step 1
    FL_CONFIG2,     // 3 = configuration step 2
    FL_CONFIG3,     // 4 = configuration step 3
    FL_DISCONNECT,  // 5 = forumslader has disconnected
    FL_WARMSTART,   // 6 = start data stream, skip configuration
    FL_READY        // 7 = running state (all setup is done)
}

class DeviceManager {

    private const
        // threshold rssi for detecting forumslader devices
        _RSSI_threshold = -85,
        // command to start the data stream on the forumslader V6 device (not needed for V5)
        FL6_START = [0x01, 0x00]b,
	    // command to request pole and wheelsize: $FLT,5*47<lf>
	    FLP = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x35, 0x2A, 0x34, 0x37, 0x0a]b,
        NULL_UUID = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-000000000000");
        // command to request firmware version (currently unused): $FLT,4*46<lf>
        //FLV = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x34, 0x2A, 0x34, 0x36, 0x0a]b;

    private var 
        _data as DataManager,
        _bleDelegate as ForumsladerDelegate,
        _device as Device?,
        _service as Service?,
        _command as Characteristic?,
        _config as Characteristic?,
        _myDevice as ScanResult?,
        _writeInProgress as Boolean = false,
        _configDone as Boolean = false,
        _FL_SERVICE as Uuid = NULL_UUID,
        _FL_CONFIG as Uuid = NULL_UUID,
        _FL_COMMAND as Uuid = NULL_UUID;

    //! Constructor
    //! @param bleDelegate The BLE delegate which provides the functions for asynchronous BLE callbacks
    //! @param dataManager The DataManager class which processes the received data stream of the BLE device
    public function initialize(bleDelegate as ForumsladerDelegate, dataManager as DataManager) {
        _device = null;
        _data = dataManager;
        _bleDelegate = bleDelegate;
        _myDevice = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult?;
        bleDelegate.notifyScanResult(self);
        bleDelegate.notifyConnection(self);
        bleDelegate.notifyCharWrite(self);
        bleDelegate.notifyDescWrite(self);
        bleDelegate.notifyProfileRegister(self);
    }

    //! Start BLE scanning
    public function startScan() as Void {
        if (_myDevice != null) {    // try to connect to a locked device
            _bleDelegate.ProcessScanRecord(_myDevice);
        } else {                    // otherwhise search for a device
            debug("scanning");
            if (_device != null) { 
                BluetoothLowEnergy.unpairDevice(_device);
            }
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            $.FLstate = FL_SEARCH;
            _configDone = false;
        }
    }

    //! Process scan result of incoming BLE advertises
    //! @param scanResult The scan result
    public function procScanResult(scanResult as ScanResult) as Void {
        // Pair the first Forumslader we see with good RSSI
        if (scanResult.getRssi() > _RSSI_threshold) {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
            try {
                BluetoothLowEnergy.pairDevice(scanResult);
                _myDevice = scanResult;
                }
            catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
                debug("cannot pair device " + scanResult.getDeviceName());
                debug("error: " + ex.getErrorMessage());
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
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
            //device.requestBond();
            _device = device;
            $.FLstate = _configDone ? FL_WARMSTART : FL_COLDSTART;
        } else {
            debug ("connection failed, restarting scan");
            startScan();
        }
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
        if (!isForumslader(_device)) {
            debug("error: detected device is not a forumslader V5/V6");
            var storedDevice = Storage.getValue("MyDevice");
            if (storedDevice != null) {
                Storage.deleteValue("MyDevice");
                debug("DeviceLock: device cleared");
            }
            startScan();
            return false;
        }
        _service = (_device as Device).getService(_FL_SERVICE);
        if (null == _service) {
            startScan();
            return false;
        }
        _command = _service.getCharacteristic(_FL_COMMAND);
        _config = _service.getCharacteristic(_FL_CONFIG);
        if ($.UserSettings[$.DeviceLock] && _myDevice != null) {
            var storedDevice = Storage.getValue("MyDevice");
            if (!(storedDevice instanceof ScanResult)) {
                saveDevice(_myDevice as BluetoothLowEnergy.ScanResult);
            }
        }
        return true;
    }

    //! save a scanned ble device
    //! @param The ScanResult record of the  Device device
    private function saveDevice(device as ScanResult) as Void {
        Storage.setValue("MyDevice", device); // store device for auto-locking
        debug("DeviceLock: device stored");
    }

    //! Identify the forumslader type and setup it's UUIDs
    //! @param Device to be validated as forumslader
    //! @return Boolean to indicate if the device was identified as a forumslader
    private function isForumslader(device as Device?) as Boolean {
        if (device == null) {
            return false;
        }

        var iter = device.getServices();
        var service = iter.next() as Service;
        while (service != null) {
            var uuid = service.getUuid();
            if (uuid.equals($.FL5_SERVICE)) {
                _FL_SERVICE = $.FL5_SERVICE;
                _FL_CONFIG = $.FL5_RXTX_CHARACTERISTIC;
                _FL_COMMAND = $.FL5_RXTX_CHARACTERISTIC;
                $.isV6 = false;
                debug("FLV5 detected");
                return true;
            } else if (uuid.equals($.FL6_SERVICE)) {
                _FL_SERVICE = $.FL6_SERVICE;
                _FL_CONFIG = $.FL6_RX_CHARACTERISTIC;
                _FL_COMMAND = $.FL6_TX_CHARACTERISTIC;
                $.isV6 = true;
                debug("FLV6 detected");
                return true;
            }
            service = iter.next() as Service;
        }
        return false;
    }

    //! Write notification to descriptor to start data stream on forumslader device
    //! For FLv5 this is not needed, as it starts the data stream immediately after connection, but for FLv6 this is required to activate the data stream.
    private function startDatastreamFL() as Void {
        if (!$.isV6) { 
            return;
        }
        var char = _config;
        if (null != char) {
            var cccd = char.getDescriptor(BluetoothLowEnergy.cccdUuid());
            if (null != cccd) {
                _writeInProgress = true;
                cccd.requestWrite(FL6_START); // set notification bit
            }
        }
    }

    //! Finite state machine
    //! This function is called after every relevant event (e.g. connection, data received, etc.) to update the state of the app and trigger the next steps in the setup process.
    public function updateState() as Number {
        var currentState = $.FLstate; 

        switch(currentState) {
            // Idle-Zustände: Sofortiger Abbruch spart CPU-Zyklen
            case FL_READY:
            case FL_SEARCH:
            case FL_DISCONNECT:
                break;

            // Kaltstart nach dem Pairing
            case FL_COLDSTART:
                if (setupProfile()) {
                    currentState = FL_CONFIG1;
                    startDatastreamFL();
                } else {
                    currentState = FL_SEARCH;
                }
                break;

            // Warmstart nach einem Verbindungsabbruch
            case FL_WARMSTART:
                currentState = FL_READY;
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
                    currentState = FL_READY;
                } else {
                    // Wenn beim ersten Mal (CONFIG2) fehlgeschlagen, gehe zu CONFIG3, sonst zurück zu CONFIG1
                    currentState = (currentState == FL_CONFIG2) ? FL_CONFIG3 : FL_CONFIG1;
                }
                break;

            // Fallback-Schutz
            default:
                currentState = FL_SEARCH;
                debug("state engine error");
                break;
        }

        // Den berechneten Zustand wieder zurückschreiben und zurückgeben
        $.FLstate = currentState;
        return currentState;
    }

}