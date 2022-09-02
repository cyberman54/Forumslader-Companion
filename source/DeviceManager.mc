import Toybox.BluetoothLowEnergy;
import Toybox.Lang;

class DeviceManager {

     // threshold rssi for detecting forumslader devices
    private const _RSSI_threshold = -70;
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

        bleDelegate.notifyScanResult(self);
        bleDelegate.notifyConnection(self);
        bleDelegate.notifyCharWrite(self);
        bleDelegate.notifyCharChanged(self);
        bleDelegate.notifyDescWrite(self);

        _profileManager = profileManager;
        _data = dataManager;
    }

    //! Start BLE scanning
    public function startScan() as Void {
        BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_SCANNING);
    }

    //! Process scan result
    //! @param scanResult The scan result
    public function procScanResult(scanResult as ScanResult) as Void {
        // Pair the first Forumslader we see with good RSSI
        if (scanResult.getRssi() > _RSSI_threshold) {
            BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_OFF);
            BluetoothLowEnergy.pairDevice(scanResult);
        }
    }

    //! Process a new device connection
    //! @param device The device that was connected
    public function procConnection(device as Device) as Void {
        if (device.isConnected() && _profileManager.isForumslader(device)) {
            _device = device;
            if (!_data.cfgDone) {
                setupForumslader();
            }
        } else {
            _device = null;
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
        // Request data for wheelsize and poles, only once during init
        sendCommand(_CMD_REQ_FLP);
    }

    //! Send $FLT command to forumslader device
    //! @param $FLT command string
    public function sendCommand(cmd as ByteArray) as Boolean {
        if ((null == _device) || _writeInProgress) {
            return false;
        }
        debug("Send Command: " + cmd.toString());
        var command = _command;
        if (null != command) {
            _writeInProgress = true;
            command.requestWrite(cmd, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
        }
        return true;
    }

    //! Start the data stream on the forumslader device
    private function setupForumslader() as Void {
        var device = _device;

        // get characteristics of GATT service
        if (null != device) {
            _service = device.getService(_profileManager.FL_SERVICE);
            var service = _service;
            if (null != service) {
                _command = service.getCharacteristic(_profileManager.FL_COMMAND);
                _config = service.getCharacteristic(_profileManager.FL_CONFIG);

                // Write notification to descriptor to start data stream
                var char = _config;
                if (null != char) {
                    var cccd = char.getDescriptor(BluetoothLowEnergy.cccdUuid());
                    if (null != cccd) {
                        _writeInProgress = true;
                        cccd.requestWrite([0x01, 0x00]b);
                    }
                }
            }
        }
    }
}