import Toybox.Test;
import Toybox.Lang;

// ==========================================================================
// Unit tests for DataManager.encode() (NMEA-style $FLx stream parser).
//
// Sentences contain precomputed XOR checksums so no runtime string-to-bytes
// conversion is needed for checksum building.
//
// _feed() accepts ByteArray directly - no String-to-bytes conversion required.
//
// Helper functions carry NO (:test) annotation - the SDK test runner would
// otherwise attempt to invoke them as test cases (wrong argument count).
//
// Run via VS Code command palette: "Monkey C: Run Tests"
// ==========================================================================

// --------------------------------------------------------------------------
// Helper - unannotated so the runner never treats it as a test case
// --------------------------------------------------------------------------

//! Feeds every ASCII byte of s into dm.encode().
function _feed(dm as DataManager, bytes as ByteArray) as Void {
    var len = bytes.size();
    for (var i = 0; i < len; i++) {
        dm.encode(bytes[i] as Number);
    }
}

// --------------------------------------------------------------------------
// FLB - temperature sentence   commitValue(-300, 800)
// Checksums (XOR of content between $ and *):
//   FLB,250  -> 53    FLB,999  -> 5D    FLB,-400 -> 7D
//   FLB,-150 -> 7D    FLB,200  -> 56    FLB,     -> 64
// --------------------------------------------------------------------------

//! Valid temperature 250 (= 25.0 degC) is stored.
(:test)
function testFLB_parsesTemperature(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x32, 0x35, 0x30, 0x2A, 0x35, 0x33, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 250;
}

//! Temperature above max (999 > 800) is rejected by commitValue to 0.
(:test)
function testFLB_rejectsTemperatureAboveMax(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x39, 0x39, 0x39, 0x2A, 0x35, 0x44, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 0;
}

//! Temperature below min (-400 < -300) is rejected by commitValue to 0.
(:test)
function testFLB_rejectsTemperatureBelowMin(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x2D, 0x34, 0x30, 0x30, 0x2A, 0x37, 0x44, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 0;
}

//! Negative temperature within range (-150) is accepted.
(:test)
function testFLB_acceptsNegativeTemperature(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x2D, 0x31, 0x35, 0x30, 0x2A, 0x37, 0x44, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == -150;
}

//! A valid sentence resets the data-age counter to 0.
(:test)
function testFLB_resetsAge(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    logger.debug("age before=" + dm.age);
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x32, 0x30, 0x30, 0x2A, 0x35, 0x36, 0x0D]b);
    logger.debug("age after=" + dm.age);
    return dm.age == 0;
}

//! An empty temperature term is handled gracefully to 0.
(:test)
function testFLB_emptyTerm_returnsZero(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x2A, 0x36, 0x34, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 0;
}

// --------------------------------------------------------------------------
// FL5 - main sensor sentence (firmware v5, isV6=false)
// Layout: $FL5,<status_hex>,<gear>,<freq>,<bv1>,<bv2>,<bv3>,
//              <battCurr>,<loadCurr>,_,_,_,_,<impulse>*XX\r
// Checksums:
//   FL5,0,3,1500,3700,3701,3702,200,100,0,0,0,0,12345 -> 21
//   FL5,0,0,0,0,0,0,-500,800,0,0,0,0,0               -> 03
//   FL5,0,0,0,0,0,0,0,0,0,0,0,0,99999                -> 2A
//   FL5,8000,0,0,0,0,0,0,0,0,0,0,0,0                 -> 1B
//   FL5,0,11,0,0,0,0,0,0,0,0,0,0,0                   -> 13
//   FL5,0,0,0,5001,0,0,0,0,0,0,0,0,0                 -> 17
//   FL5,0,0,0,0,0,0,0,-1,0,0,0,0,0                   -> 0F
// --------------------------------------------------------------------------

//! Gear and all three battery voltages are parsed correctly.
(:test)
function testFL5_parsesGearAndVoltages(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x33, 0x2C, 0x31, 0x35, 0x30, 0x30, 0x2C, 0x33, 0x37, 0x30, 0x30, 0x2C, 0x33, 0x37, 0x30, 0x31, 0x2C, 0x33, 0x37, 0x30, 0x32, 0x2C, 0x32, 0x30, 0x30, 0x2C, 0x31, 0x30, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x31, 0x32, 0x33, 0x34, 0x35, 0x2A, 0x32, 0x31, 0x0D]b);
    logger.debug("gear=" + dm.FLdata[FL_gear]
        + " bv1=" + dm.FLdata[FL_battVoltage1]
        + " bv2=" + dm.FLdata[FL_battVoltage2]
        + " bv3=" + dm.FLdata[FL_battVoltage3]);
    return dm.FLdata[FL_gear] == 3
        && dm.FLdata[FL_battVoltage1] == 3700
        && dm.FLdata[FL_battVoltage2] == 3701
        && dm.FLdata[FL_battVoltage3] == 3702;
}

//! Battery current (signed, -10000..10000) and load current (0..10000) are stored.
(:test)
function testFL5_parsesBatteryCurrentAndLoad(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x2D, 0x35, 0x30, 0x30, 0x2C, 0x38, 0x30, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x30, 0x33, 0x0D]b);
    logger.debug("battCurrent=" + dm.FLdata[FL_battCurrent]
        + " loadCurrent=" + dm.FLdata[FL_loadCurrent]);
    return dm.FLdata[FL_battCurrent] == -500
        && dm.FLdata[FL_loadCurrent] == 800;
}

//! Impulse counter is read from term index 13 when isV6=false.
(:test)
function testFL5_parsesImpulseAtTerm13(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x39, 0x39, 0x39, 0x39, 0x39, 0x2A, 0x32, 0x41, 0x0D]b);
    logger.debug("impulseCounter=" + dm.FLdata[FL_impulseCounter]);
    return dm.FLdata[FL_impulseCounter] == 99999;
}

//! Status word is parsed as hexadecimal (0x8000 = 32768 = discharging flag).
(:test)
function testFL5_parsesStatusHex(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x38, 0x30, 0x30, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x31, 0x42, 0x0D]b);
    logger.debug("status=" + dm.FLdata[FL_status]);
    return dm.FLdata[FL_status] == 0x8000;
}

//! Gear value above range maximum (11 > 10) is rejected by commitValue to 0.
(:test)
function testFL5_rejectsGearAboveMax(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x31, 0x31, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x31, 0x33, 0x0D]b);
    logger.debug("gear=" + dm.FLdata[FL_gear]);
    return dm.FLdata[FL_gear] == 0;
}

//! Battery voltage above range maximum (5001 > 5000) is rejected to 0.
(:test)
function testFL5_rejectsVoltageAboveMax(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x31, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x31, 0x37, 0x0D]b);
    logger.debug("bv1=" + dm.FLdata[FL_battVoltage1]);
    return dm.FLdata[FL_battVoltage1] == 0;
}

//! Load current below range minimum (-1 < 0) is rejected to 0.
(:test)
function testFL5_rejectsNegativeLoadCurrent(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x2D, 0x31, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x30, 0x46, 0x0D]b);
    logger.debug("loadCurrent=" + dm.FLdata[FL_loadCurrent]);
    return dm.FLdata[FL_loadCurrent] == 0;
}

// --------------------------------------------------------------------------
// FL6 - main sensor sentence (firmware v6, isV6=true)
// Layout: $FL6,<status_hex>,<gear>,<freq>,<bv1>,<bv2>,<bv3>,
//              <battCurr>,<loadCurr>,_,_,_,<impulse>*XX\r
// Checksums:
//   FL6,0,0,0,0,0,0,0,0,0,0,0,55555 -> 39
//   FL6,0,7,0,0,0,0,0,0,0,0,0,0     -> 3B
// --------------------------------------------------------------------------

//! Impulse counter is read from term index 12 when isV6=true.
(:test)
function testFL6_parsesImpulseAtTerm12(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = true;
    _feed(dm, [0x24, 0x46, 0x4C, 0x36, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x35, 0x35, 0x35, 0x35, 0x2A, 0x33, 0x39, 0x0D]b);
    logger.debug("impulseCounter=" + dm.FLdata[FL_impulseCounter]);
    $.isV6 = false;
    return dm.FLdata[FL_impulseCounter] == 55555;
}

//! FL6 and FL5 use the same field slots - gear is stored identically.
(:test)
function testFL6_parsesGear(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = true;
    _feed(dm, [0x24, 0x46, 0x4C, 0x36, 0x2C, 0x30, 0x2C, 0x37, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x33, 0x42, 0x0D]b);
    logger.debug("gear=" + dm.FLdata[FL_gear]);
    $.isV6 = false;
    return dm.FLdata[FL_gear] == 7;
}

// --------------------------------------------------------------------------
// FLC - configuration / energy sentence
// set 3: Energy, tourEnergy, tripEnergy, BTsaveCount, empty1
// set 5: startCount, socState, fullChargeCapacity, cycleCount, ccadcValue
// Checksums:
//   FLC,3,100,200,350,10,0        -> 7E
//   FLC,5,1,75,2000,50,16000      -> 7F
//   FLC,1,100,200,300,400,500     -> 49
// --------------------------------------------------------------------------

//! FLC set 3 writes all five energy values into FLdata.
(:test)
function testFLC_set3_parsesEnergyFields(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x43, 0x2C, 0x33, 0x2C, 0x31, 0x30, 0x30, 0x2C, 0x32, 0x30, 0x30, 0x2C, 0x33, 0x35, 0x30, 0x2C, 0x31, 0x30, 0x2C, 0x30, 0x2A, 0x37, 0x45, 0x0D]b);
    logger.debug("Energy=" + dm.FLdata[FL_Energy]
        + " tripEnergy=" + dm.FLdata[FL_tripEnergy]);
    return dm.FLdata[FL_Energy]      == 100
        && dm.FLdata[FL_tourEnergy]  == 200
        && dm.FLdata[FL_tripEnergy]  == 350
        && dm.FLdata[FL_BTsaveCount] == 10
        && dm.FLdata[FL_empty1]      == 0;
}

//! FLC set 5 writes socState, fullChargeCapacity and ccadcValue into FLdata.
(:test)
function testFLC_set5_parsesSocFields(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x43, 0x2C, 0x35, 0x2C, 0x31, 0x2C, 0x37, 0x35, 0x2C, 0x32, 0x30, 0x30, 0x30, 0x2C, 0x35, 0x30, 0x2C, 0x31, 0x36, 0x30, 0x30, 0x30, 0x2A, 0x37, 0x46, 0x0D]b);
    logger.debug("socState=" + dm.FLdata[FL_socState]
        + " fullCharge=" + dm.FLdata[FL_fullChargeCapacity]
        + " ccadc=" + dm.FLdata[FL_ccadcValue]);
    return dm.FLdata[FL_startCount]          == 1
        && dm.FLdata[FL_socState]            == 75
        && dm.FLdata[FL_fullChargeCapacity]  == 2000
        && dm.FLdata[FL_cycleCount]          == 50
        && dm.FLdata[FL_ccadcValue]          == 16000;
}

//! FLC with unknown set number (not 3 or 5) must not modify energy fields;
//! age IS reset because the checksum itself is valid.
(:test)
function testFLC_unknownSet_doesNotUpdateData(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x43, 0x2C, 0x31, 0x2C, 0x31, 0x30, 0x30, 0x2C, 0x32, 0x30, 0x30, 0x2C, 0x33, 0x30, 0x30, 0x2C, 0x34, 0x30, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x2A, 0x34, 0x39, 0x0D]b);
    logger.debug("FL_Energy=" + dm.FLdata[FL_Energy] + " age=" + dm.age);
    return dm.FLdata[FL_Energy] == 0
        && dm.FLdata[FL_tripEnergy] == 0
        && dm.age == 0;
}

// --------------------------------------------------------------------------
// FLP - profile sentence (wheel size / dynamo poles / offsets)
// Layout: $FLP,<wheelsize_mm>,<poles>,_,<dayOffset>,_,<tourOffset>,_,<acc2mah>*XX\r
// Checksums:
//   FLP,2150,15,0,100,0,200,0,5000 -> 6E
//   FLP,2150,15,0,0,0,0,0,5000     -> 6D
//   FLP,999,15,0,0,0,0,0,5000      -> 52
//   FLP,2150,9,0,0,0,0,0,5000      -> 50
// --------------------------------------------------------------------------

//! All profile fields are stored correctly.
(:test)
function testFLP_parsesProfileFields(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    $.speedunitFactor = 1.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x32, 0x31, 0x35, 0x30, 0x2C, 0x31, 0x35, 0x2C, 0x30, 0x2C, 0x31, 0x30, 0x30, 0x2C, 0x30, 0x2C, 0x32, 0x30, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x36, 0x45, 0x0D]b);
    logger.debug("wheelsize=" + dm.FLdata[FL_wheelsize]
        + " poles=" + dm.FLdata[FL_poles]
        + " dayOffset=" + dm.FLdata[FL_dayPulseOffset]
        + " tourOffset=" + dm.FLdata[FL_tourPulseOffset]
        + " acc2mah=" + dm.FLdata[FL_acc2mah]);
    return dm.FLdata[FL_wheelsize]       == 2150
        && dm.FLdata[FL_poles]           == 15
        && dm.FLdata[FL_dayPulseOffset]  == 100
        && dm.FLdata[FL_tourPulseOffset] == 200
        && dm.FLdata[FL_acc2mah]         == 5000;
}

//! freq2speed = wheelsize/poles * 0.0036 / speedDivisor * speedUnitFactor
//! isV6=false, speedDivisor=1, wheelsize=2150, poles=15 => approx 0.516 km/h per Hz.
(:test)
function testFLP_computesFreq2speed(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    $.speedunitFactor = 1.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x32, 0x31, 0x35, 0x30, 0x2C, 0x31, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x36, 0x44, 0x0D]b);
    var expected = 2150.0f / 15.0f * 0.0036f;
    var diff = dm.freq2speed - expected;
    if (diff < 0.0f) { diff = -diff; }
    logger.debug("freq2speed=" + dm.freq2speed + " expected=" + expected);
    return diff < 0.0001f;
}

//! imp2odo (isV6=false, impulseScale=4096) = wheelsize/poles/1e6 * 4096 * speedUnitFactor.
(:test)
function testFLP_computesImp2odo(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    $.speedunitFactor = 1.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x32, 0x31, 0x35, 0x30, 0x2C, 0x31, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x36, 0x44, 0x0D]b);
    var expected = 2150.0d / 15.0d / 1000000.0d * 4096.0d;
    var diff = dm.imp2odo - expected;
    if (diff < 0.0d) { diff = -diff; }
    logger.debug("imp2odo=" + dm.imp2odo + " expected=" + expected);
    return diff < 0.000001d;
}

//! Wheel size below minimum (999 < 1000) is rejected; freq2speed stays 0.
(:test)
function testFLP_rejectsWheelsizeBelowMin(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    $.speedunitFactor = 1.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x39, 0x39, 0x39, 0x2C, 0x31, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x35, 0x32, 0x0D]b);
    logger.debug("wheelsize=" + dm.FLdata[FL_wheelsize]
        + " freq2speed=" + dm.freq2speed);
    return dm.FLdata[FL_wheelsize] == 0 && dm.freq2speed == 0.0f;
}

//! Pole count below minimum (9 < 10) is rejected; freq2speed stays 0.
(:test)
function testFLP_rejectsPolesBelowMin(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    $.speedunitFactor = 1.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x32, 0x31, 0x35, 0x30, 0x2C, 0x39, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x35, 0x30, 0x0D]b);
    logger.debug("poles=" + dm.FLdata[FL_poles] + " freq2speed=" + dm.freq2speed);
    return dm.FLdata[FL_poles] == 0 && dm.freq2speed == 0.0f;
}

// --------------------------------------------------------------------------
// Checksum and error handling
// --------------------------------------------------------------------------

//! A sentence with a wrong checksum must not update FLdata or reset age.
(:test)
function testInvalidChecksum_doesNotUpdateData(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x32, 0x35, 0x30, 0x2A, 0x46, 0x46, 0x0D]b);   // correct checksum is 53, not FF
    logger.debug("temperature=" + dm.FLdata[FL_temperature] + " age=" + dm.age);
    return dm.FLdata[FL_temperature] == 0
        && dm.age == dm.MAX_AGE_SEC;
}

//! An unknown sentence type ($XYZ...) is silently ignored; age is not reset.
(:test)
function testUnknownSentenceType_isIgnored(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x58, 0x59, 0x5A, 0x2C, 0x31, 0x30, 0x30, 0x2C, 0x32, 0x30, 0x30, 0x2A, 0x35, 0x38, 0x0D]b);
    logger.debug("age=" + dm.age);
    return dm.age == dm.MAX_AGE_SEC;
}

//! A second valid FLB sentence overwrites the first temperature value.
(:test)
function testMultipleSentences_secondValueWins(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x31, 0x30, 0x30, 0x2A, 0x35, 0x35, 0x0D]b);
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x33, 0x35, 0x30, 0x2A, 0x35, 0x32, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 350;
}

//! After a valid sentence followed by one with a wrong checksum, the valid
//! value is retained.
(:test)
function testValidThenInvalid_retainsLastValidValue(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x33, 0x30, 0x30, 0x2A, 0x35, 0x37, 0x0D]b);
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x32, 0x35, 0x30, 0x2A, 0x46, 0x46, 0x0D]b);   // wrong checksum
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 300;
}

//! A sentence type with identifier shorter than 3 chars is treated as SENTENCE_OTHER.
(:test)
function testShortSentenceType_isIgnored(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x2C, 0x31, 0x30, 0x30, 0x2A, 0x31, 0x37, 0x0D]b);
    return dm.age == dm.MAX_AGE_SEC;
}

// --------------------------------------------------------------------------
// Exact boundary values - commitValue uses strict < / >, so min and max
// themselves must be accepted.
// --------------------------------------------------------------------------

//! Temperature at exact minimum (-300) is accepted by commitValue.
(:test)
function testFLB_acceptsExactMinTemperature(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x2D, 0x33, 0x30, 0x30, 0x2A, 0x37, 0x41, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == -300;
}

//! Temperature at exact maximum (800) is accepted by commitValue.
(:test)
function testFLB_acceptsExactMaxTemperature(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    _feed(dm, [0x24, 0x46, 0x4C, 0x42, 0x2C, 0x38, 0x30, 0x30, 0x2A, 0x35, 0x43, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 800;
}

// --------------------------------------------------------------------------
// FL5: FL_frequency field (term[3]) - not covered by any existing test.
// $FL5,0,0,1500,0,0,0,0,0,0,0,0,0,0*17
// --------------------------------------------------------------------------

//! Frequency at term[3] is stored correctly in FL_frequency.
(:test)
function testFL5_parsesFrequency(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    _feed(dm, [0x24, 0x46, 0x4C, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x31, 0x35, 0x30, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2A, 0x31, 0x37, 0x0D]b);
    logger.debug("FL_frequency=" + dm.FLdata[FL_frequency]);
    return dm.FLdata[FL_frequency] == 1500;
}

// --------------------------------------------------------------------------
// FLP: isV6=true activates speedDivisor=10 for freq2speed.
// FLP: speedunitFactor is multiplied into both freq2speed and imp2odo.
// Both tests reuse $FLP,2150,15,0,0,0,0,0,5000*6D\r.
// --------------------------------------------------------------------------

//! With isV6=true speedDivisor=10 halves freq2speed by ten vs isV6=false.
(:test)
function testFLP_computesFreq2speed_isV6(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = true;
    $.speedunitFactor = 1.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x32, 0x31, 0x35, 0x30, 0x2C, 0x31, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x36, 0x44, 0x0D]b);
    $.isV6 = false;
    var expected = 2150.0f / 15.0f * 0.0036f / 10.0f;
    var diff = dm.freq2speed - expected;
    if (diff < 0.0f) { diff = -diff; }
    logger.debug("freq2speed=" + dm.freq2speed + " expected=" + expected);
    return diff < 0.00001f;
}

//! speedunitFactor=2 doubles freq2speed compared to factor=1.
(:test)
function testFLP_appliesSpeedUnitFactor(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    $.isV6 = false;
    $.speedunitFactor = 2.0f;
    _feed(dm, [0x24, 0x46, 0x4C, 0x50, 0x2C, 0x32, 0x31, 0x35, 0x30, 0x2C, 0x31, 0x35, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x30, 0x2C, 0x35, 0x30, 0x30, 0x30, 0x2A, 0x36, 0x44, 0x0D]b);
    $.speedunitFactor = 1.0f;
    var expected = 2150.0f / 15.0f * 0.0036f * 2.0f;
    var diff = dm.freq2speed - expected;
    if (diff < 0.0f) { diff = -diff; }
    logger.debug("freq2speed=" + dm.freq2speed + " expected=" + expected);
    return diff < 0.00001f;
}

// --------------------------------------------------------------------------
// Parser robustness: '$' mid-stream resets parser state.
// Garbage bytes 0x41 0x42 0x43 ('ABC') arrive before the '$' of a valid
// FLB sentence - the parser must recover and commit the valid sentence.
// --------------------------------------------------------------------------

//! Garbage bytes before '$' are discarded; the following valid sentence is parsed.
(:test)
function testParser_resetOnDollarSign(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    // 'ABC' (0x41,0x42,0x43) + $FLB,250*53\r
    _feed(dm, [0x41, 0x42, 0x43, 0x24, 0x46, 0x4C, 0x42, 0x2C, 0x32, 0x35, 0x30, 0x2A, 0x35, 0x33, 0x0D]b);
    logger.debug("FL_temperature=" + dm.FLdata[FL_temperature]);
    return dm.FLdata[FL_temperature] == 250;
}

// --------------------------------------------------------------------------
// FLC: set 3 and set 5 write to different array regions and must not
// interfere with each other.
// --------------------------------------------------------------------------

//! After set 3 and set 5 are fed in sequence both regions hold correct values.
(:test)
function testFLC_set3AndSet5_areIndependent(logger as Test.Logger) as Boolean {
    var dm = new DataManager();
    // set 3: $FLC,3,100,200,350,10,0*7E\r
    _feed(dm, [0x24, 0x46, 0x4C, 0x43, 0x2C, 0x33, 0x2C, 0x31, 0x30, 0x30, 0x2C, 0x32, 0x30, 0x30, 0x2C, 0x33, 0x35, 0x30, 0x2C, 0x31, 0x30, 0x2C, 0x30, 0x2A, 0x37, 0x45, 0x0D]b);
    // set 5: $FLC,5,1,75,2000,50,16000*7F\r
    _feed(dm, [0x24, 0x46, 0x4C, 0x43, 0x2C, 0x35, 0x2C, 0x31, 0x2C, 0x37, 0x35, 0x2C, 0x32, 0x30, 0x30, 0x30, 0x2C, 0x35, 0x30, 0x2C, 0x31, 0x36, 0x30, 0x30, 0x30, 0x2A, 0x37, 0x46, 0x0D]b);
    logger.debug("Energy=" + dm.FLdata[FL_Energy] + " socState=" + dm.FLdata[FL_socState]);
    return dm.FLdata[FL_Energy]   == 100   // set 3 unchanged
        && dm.FLdata[FL_socState] == 75;   // set 5 written
}
