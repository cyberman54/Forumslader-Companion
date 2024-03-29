import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

// datafield app states
    enum {
        FL_SEARCH,      // 0 = entry state (waiting for pairing & connect)
        FL_COLDSTART,   // 1 = request FLP & FLV data + start $FLx data stream
        FL_WAIT1,       // 2 = waiting for data stream turning on
        FL_REQFLV,      // 3 = request $FLV data (firmware version)
        FL_WAIT2,       // 4 = waiting for $FLV message
        FL_REQFLP,      // 5 = request $FLP data (dynamo poles & wheelsize)
        FL_WAIT3,       // 6 = waiting for $FLP message
        FL_DISCONNECT,  // 7 = forumslader has disconnected
        FL_WARMSTART,   // 8 = only start $FLx data stream
        FL_READY        // 9 = running state (all setup is done)
    }

var 
    isV6 as Boolean = false,
    FLstate as Number = FL_SEARCH;

class DeviceManager {

    private const
        // threshold rssi for detecting forumslader devices
        _RSSI_threshold = -85,
	    // command to request pole and wheelsize
	    FLP = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x35, 0x2A, 0x34, 0x37, 0x0a]b, // $FLT,5*47<lf>
        // command to request firmware version
        FLV = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x34, 0x2A, 0x34, 0x36, 0x0a]b; // $FLT,4*46<lf>

    private var 
        _profileManager as ProfileManager,
        _data as DataManager,
        _device as Device?,
        _service as Service?,
        _command as Characteristic?,
        _config as Characteristic?,
        _writeInProgress as Boolean = false,
        _configDone as Boolean = false,
        _waitTicks as Number = 0;

    //! Constructor
    //! @param bleDelegate The BLE delegate
    //! @param profileManager The profile manager
    public function initialize(bleDelegate as ForumsladerDelegate, profileManager as ProfileManager, dataManager as DataManager) {
        _device = null;
        _profileManager = profileManager;
        _data = dataManager;

        bleDelegate.notifyScanResult(self);
        bleDelegate.notifyConnection(self);
        bleDelegate.notifyCharWrite(self);
        bleDelegate.notifyCharChanged(self);
        bleDelegate.notifyDescWrite(self);
    }

    //! Start BLE scanning
    public function startScan() as Void {
        if (_device != null) { 
            BluetoothLowEnergy.unpairDevice(_device);
        }
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
        $.FLstate = FL_SEARCH;
        _configDone = false;
    }

    //! Process scan result
    //! @param scanResult The scan result
    public function procScanResult(scanResult as ScanResult) as Void {
        // Pair the first Forumslader we see with good RSSI
        if (scanResult.getRssi() > _RSSI_threshold) {
            debug("trying to pair device, rssi " + scanResult.getRssi());
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
            try {
                BluetoothLowEnergy.pairDevice(scanResult);
            }
            catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
                debug("cannot pair device " + scanResult.getDeviceName());
                debug("error: " + ex.getErrorMessage());
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            }
        } else {
            debug("signal too weak, rssi " + scanResult.getRssi());
        }
    }

    //! Process a new device connection
    //! @param device The device that was connected
    public function procConnection(device as Device) as Void {
        if (device.isConnected()) {
            _device = device;
            $.FLstate = _configDone ? FL_WARMSTART : FL_COLDSTART;
        } else {
            debug ("connection failed, restarting scan");
            startScan();
        }
    }

    //! Process incoming data from the device
    //! @param data The data which is delivered by the device
    public function procData(data as ByteArray or Null) as Void {
        if (null != data) {
            _data.encode(data);
		}
    }

    //! Handle the completion of a write operation on a characteristic
    //! @param char The characteristic that was written
    //! @param status The result of the operation
    public function procCharWrite(char as Characteristic, status as Status) as Void {
        //debug("Write Char: " + char.getUuid() + " -> " + status);
        _writeInProgress = false;
    }

    //! Handle the completion of a write operation on a descriptor
    //! @param char The descriptor that was written
    //! @param status The result of the operation
    public function procDescWrite(desc as Descriptor, status as Status) as Void {
        //debug("Write Desc: " + desc.getUuid() + " -> " + status);
        _writeInProgress = false;
    }

    //! Send command to forumslader device
    //! @param cmd as command ByteArray
    public function sendCommandFL(cmd as ByteArray) as Void {
        if ((null == _device) || _writeInProgress) {
            return;
        }
        //debug("Send Command: " + cmd.toString());
        var command = _command;
        if (null != command) {
            _writeInProgress = true;
            command.requestWrite(cmd, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
        }
    }

    //! identify forumslader and get characteristic of it's GATT service
    private function setupProfile() as Boolean {
        var device = _device;
        if (null != device) {
            if (_profileManager.isForumslader(device)) {
                _service = device.getService(_profileManager.FL_SERVICE);
                var service = _service;
                if (null != service) {
                    _command = service.getCharacteristic(_profileManager.FL_COMMAND);
                    _config = service.getCharacteristic(_profileManager.FL_CONFIG);
                }
                return true;
            }
        }
        debug("error: not a forumslader or unknown type");
        startScan();
        return false;
    }

    //! Write notification to descriptor to start data stream on forumslader device
    private function startDatastreamFL() as Void {
                var char = _config;
                if (null != char) {
                    var cccd = char.getDescriptor(BluetoothLowEnergy.cccdUuid());
                    if (null != cccd) {
                        _writeInProgress = true;
                        cccd.requestWrite([1,0]b);
                    }
                }
    }

    //! finite state machine
    public function updateState() as Number {
        switch($.FLstate)
            {
            // cases before/after setup
            case FL_READY:
            case FL_SEARCH:
            case FL_DISCONNECT:
                break;
            // cold start (used after pairing)
            case FL_COLDSTART:
                _waitTicks = 0;
                if (setupProfile()) {
                    $.FLstate = FL_WAIT1;
                    startDatastreamFL();
                } else {
                    $.FLstate = FL_SEARCH;
                }
                break;
            // warm start (used after reconnecting)
            case FL_WARMSTART:
                $.FLstate = FL_READY;
                startDatastreamFL();
                break;
            // request firmware version data
            case FL_REQFLV:
                $.FLstate = FL_WAIT2;
                sendCommandFL(FLV);
                break;
            // request wheelsize and poles data
            case FL_REQFLP:
                $.FLstate = FL_WAIT3;
                sendCommandFL(FLP);
                break;
            // wait stages during startup
            case FL_WAIT1: // wait until data stream was turned on, check if FLV record was already catched
                _waitTicks ++;
                if (_data.tick == 0) {
                    $.FLstate = _data._FLversion1.equals("") ? FL_REQFLV : FL_REQFLP;
                    break;
                }
                // timeout to prevent endless waiting
                if (_waitTicks > _data.MAX_AGE_SEC) {
                    $.FLstate = FL_COLDSTART;
                }
                break;
            case FL_WAIT2: // wait until FLV message was catched
                _waitTicks ++;
                if (!_data._FLversion1.equals("")) {
                    $.FLstate = FL_REQFLP;
                    break;
                } 
                // timeout to prevent endless waiting
                if (_waitTicks > 2 * _data.MAX_AGE_SEC) {
                    $.FLstate = FL_COLDSTART;
                }
                break;
            case FL_WAIT3: // wait until FLP message was catched
                _waitTicks ++;
                if (_data.FLdata[FL_poles] > 0) {
                    _configDone = true;
                    $.FLstate = FL_READY;
                    break;
                }
                // timeout to prevent endless waiting
                if (_waitTicks > 3 * _data.MAX_AGE_SEC) {
                    $.FLstate = FL_COLDSTART;
                }
                break;
            }
        return $.FLstate;
    }

}