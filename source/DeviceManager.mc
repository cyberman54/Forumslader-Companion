import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

// forumslader device states
    enum {
        FL_SETUP,
        FL_FLP,
        FL_FLV,
        FL_START,
        FL_READY
    }

var isV6 as Boolean = false;
var FLstate as Number = FL_SETUP;

class DeviceManager {

     // threshold rssi for detecting forumslader devices
    private const _RSSI_threshold = -80;
	// command to request pole and wheelsize
	private const _CMD_REQ_FLP = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x35, 0x2A, 0x34, 0x37, 0x0a]b; // $FLT,5*47<lf>
    // command to request firmware version
    private const _CMD_REQ_FLV = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x34, 0x2A, 0x34, 0x36, 0x0a]b; // $FLT,4*46<lf>

    private var _profileManager as ProfileManager;
    private var _data as DataManager;
    private var _device as Device?;
    private var _service as Service?;
    private var _command as Characteristic?;
    private var _config as Characteristic?;
    private var _writeInProgress as Boolean = false;

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
    public function start() as Void {
        if (_device != null) { 
            BluetoothLowEnergy.unpairDevice(_device);
        }
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }

    //! Process scan result
    //! @param scanResult The scan result
    public function procScanResult(scanResult as ScanResult) as Void {
        // Pair the first Forumslader we see with good RSSI
        if (scanResult.getRssi() > _RSSI_threshold) {
            debug("trying to connect, rssi " + scanResult.getRssi());
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
            try {
                BluetoothLowEnergy.pairDevice(scanResult);
            }
            catch(ex instanceof BluetoothLowEnergy.DevicePairException) {
                debug("Pairing Error, Device: " + scanResult.getDeviceName());
                debug("Error: " + ex.getErrorMessage());
                BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
            }
        } else {
            debug("signal too weak, rssi " + scanResult.getRssi());
        }
    }

    //! Process a new device connection
    //! @param device The device that was connected
    public function procConnection(device as Device) as Void {
        if (device.isConnected() && _profileManager.isForumslader(device)) {
            _device = device;
            if ($.FLstate == FL_READY) {
                $.FLstate = FL_START;
            } else {
                $.FLstate = FL_SETUP;
            }
        } else {
            _device = null;
            debug ("procConnection failed");
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
        debug("Write Char: (" + char.getUuid() + ") - " + status);
        _writeInProgress = false;
    }

    //! Handle the completion of a write operation on a descriptor
    //! @param char The descriptor that was written
    //! @param status The result of the operation
    public function procDescWrite(desc as Descriptor, status as Status) as Void {
        debug("Write Desc: (" + desc.getUuid() + ") - " + status);
        _writeInProgress = false;
    }

    //! Send command to forumslader device
    //! @param cmd as command ByteArray
    public function sendCommand(cmd as ByteArray) as Void {
        if ((null == _device) || _writeInProgress) {
            return;
        }
        debug("Send Command: " + cmd.toString());
        var command = _command;
        if (null != command) {
            _writeInProgress = true;
            command.requestWrite(cmd, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
        }
    }

    //! Start the data stream on the forumslader device
    private function setupFL() as Void {
        var device = _device;

        // set forumslader v5 / v6 type
        if (_profileManager.FL_SERVICE == _profileManager.FL6_SERVICE ) {
            $.isV6 = true;
            debug("setup V6");
        } else {
            $.isV6 = false;
            debug("setup V5");
        }

        // get characteristics of GATT service
        if (null != device) {
            _service = device.getService(_profileManager.FL_SERVICE);
            var service = _service;
            if (null != service) {
                _command = service.getCharacteristic(_profileManager.FL_COMMAND);
                _config = service.getCharacteristic(_profileManager.FL_CONFIG);
            }
        }
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

    //! device control state machine
    public function updateState(state as Number) as Void {
        switch(state)
            {
            // device is up and running
            case FL_READY:
                break;
            // cold start
            case FL_SETUP: 
                setupFL();
                startDatastreamFL();
                $.FLstate = FL_FLP;
                break;
            // warm start
            case FL_START:
                startDatastreamFL();
                $.FLstate = FL_READY;
                break;
            // request wheelsize and poles
            case FL_FLP:
                sendCommand(_CMD_REQ_FLP);
                break;
            // request firmware version
            case FL_FLV:
                sendCommand(_CMD_REQ_FLV);
                break;
            default:
            }
    }

}