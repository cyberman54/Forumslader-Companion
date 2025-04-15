import Toybox.BluetoothLowEnergy;
import Toybox.Lang;
import Toybox.Application.Storage;

// app states
enum {
    FL_SEARCH,      // 0 = entry state (waiting for pairing & connect)
    FL_COLDSTART,   // 1 = request $FLP data and start $FLx data stream
    FL_CONFIG1,     // 2 = configuration step 1
    FL_CONFIG2,     // 3 = configuration step 2
    FL_CONFIG3,     // 4 = configuration step 3
    FL_DISCONNECT,  // 5 = forumslader has disconnected
    FL_WARMSTART,   // 6 = start data stream, skip configuration
    FL_READY = 9    // 9 = running state (all setup is done)
}

class DeviceManager {

    private const
        // threshold rssi for detecting forumslader devices
        _RSSI_threshold = -85,
	    // command to request pole and wheelsize: $FLT,5*47<lf>
	    FLP = [0x24, 0x46, 0x4C, 0x54, 0x2C, 0x35, 0x2A, 0x34, 0x37, 0x0a]b;
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
        _FL_SERVICE as Uuid = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-000000000000"),
        _FL_CONFIG as Uuid = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-000000000000"),
        _FL_COMMAND as Uuid = BluetoothLowEnergy.stringToUuid("00000000-0000-0000-0000-000000000000");

    //! Constructor
    //! @param bleDelegate The BLE delegate which provides the functions for asynchronous BLE callbacks
    //! @param dataManager The DataManager class which processes the received data stream of the BLE device
    public function initialize(bleDelegate as ForumsladerDelegate, dataManager as DataManager) {
        _device = null;
        _data = dataManager;
        _bleDelegate = bleDelegate;
        _myDevice = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult;
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

    //! Handle the completion of a profile registration
    //! @param uuid Profile UUID that this callback is related to
    //! @param status The BluetoothLowEnergy status indicating the result of the operation
    public function procProfileRegister(uuid as Uuid, status as Status) as Void {
        //debug("Profile register: " + uuid.toString() + " -> " + status);
    }

    //! Send command to forumslader device
    //! @param cmd as command ByteArray
    private function sendCommandFL(cmd as ByteArray) as Void {
        if ((null == _device) || _writeInProgress) {
            return;
        }
        debug("Send FL Command: " + cmd.toString());
        var command = _command;
        if (null != command) {
            _writeInProgress = true;
            command.requestWrite(cmd, {:writeType => BluetoothLowEnergy.WRITE_TYPE_WITH_RESPONSE});
        }
    }

    //! identify forumslader and get characteristic of it's GATT service
    private function setupProfile() as Boolean {
        if (null != _device) {
            if (isForumslader(_device)) {
                _service = (_device as Device).getService(_FL_SERVICE);
                var service = _service;
                if (null != service) {
                    _command = service.getCharacteristic(_FL_COMMAND);
                    _config = service.getCharacteristic(_FL_CONFIG);
                    if ($.UserSettings[$.DeviceLock] == true) {
                        var storedDevice = Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult;
                        if (storedDevice == null || !storedDevice.equals(_myDevice)) {
                            Storage.setValue("MyDevice", _myDevice);
                            debug("DeviceLock: device stored");
                        }
                    }
                    return true;
                }
            }
            debug("error: detected device is not a forumslader V5/V6");
            if (Storage.getValue("MyDevice") as BluetoothLowEnergy.ScanResult != null) {
                Storage.deleteValue("MyDevice");
                debug("DeviceLock: device cleared");
            }
        }   
        startScan();
        return false;
    }

    //! Identify the forumslader type and setup it's UUIDs
    //! @param Device to be validated as forumslader
    //! @return Boolean to indicate if the device was identified as a forumslader
    private function isForumslader(device as Device) as Boolean {
        var rc = false;
        if (device != null) {
            // select FL type
			var iter = device.getServices();
			for (var r = iter.next(); r != null; r = iter.next())
			{
				r = r as Service;
				if (r != null)
				{
					if (r.getUuid().equals($.FL5_SERVICE))
					{
						_FL_SERVICE = $.FL5_SERVICE;
						_FL_CONFIG = $.FL5_RXTX_CHARACTERISTIC;
						_FL_COMMAND = $.FL5_RXTX_CHARACTERISTIC;
                        rc = true;
                        $.isV6 = false;
                        debug("FLV5 detected");
					}
					else {
						if (r.getUuid().equals($.FL6_SERVICE))
						{
							_FL_SERVICE = $.FL6_SERVICE;
							_FL_CONFIG = $.FL6_RX_CHARACTERISTIC;
							_FL_COMMAND = $.FL6_TX_CHARACTERISTIC;
                            rc = true;
                            $.isV6 = true;
                            debug("FLV6 detected");
						}
					}
				}
			}
        }
        return rc;
    }

    //! Write notification to descriptor to start data stream on forumslader device
    private function startDatastreamFL() as Void {
        if (!$.isV6) { 
            return; // FLv5 does not need notification activation
        }
        //debug("start datastream");
        var char = _config;
        if (null != char) {
            var cccd = char.getDescriptor(BluetoothLowEnergy.cccdUuid());
            if (null != cccd) {
                _writeInProgress = true;
                cccd.requestWrite([0x01,0x00]b); // set notification bit
            }
        }
    }

    //! finite state machine
    public function updateState() as Number {
        switch($.FLstate)
            {
            // waiting for delegate event, nothing to do meanwhile
            case FL_READY:
            case FL_SEARCH:
            case FL_DISCONNECT:
                break;
            // cold start (used after pairing)
            case FL_COLDSTART:
                if (setupProfile()) {
                    $.FLstate ++;
                    startDatastreamFL();
                } else {
                    $.FLstate --;
                }
                break;
            // warm start (used after reconnecting)
            case FL_WARMSTART:
                $.FLstate = FL_READY;
                startDatastreamFL();
                break;
            // 3-steps configuration sequence during startup
            // step1: request parameters
            case FL_CONFIG1:
                if (_data.tick == 0) {  // wait until data stream was turned on
                    sendCommandFL(FLP); // request wheelsize and poles data
                    $.FLstate ++;
                }
                break;
            // step2: check parameters, first try
            case FL_CONFIG2:
                if (_data.FLdata[FL_poles] > 0) {
                    _configDone = true;
                    $.FLstate = FL_READY;
                } else {
                    $.FLstate ++;
                }
                break;
            // step3: check parameters, second try (for FLV5)
            case FL_CONFIG3:
                if (_data.FLdata[FL_poles] > 0) {
                    _configDone = true;
                    $.FLstate = FL_READY;
                } else {
                    $.FLstate = FL_CONFIG1;
                }
                break;
            }
       return $.FLstate;
    }

}