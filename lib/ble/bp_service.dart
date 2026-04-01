import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pointycastle/export.dart'; // for AES-128 ECB

// ── BLE Characteristic UUIDs (Omron custom protocol) ──────────────────────────
// These are NOT the standard 0x2A35 BT-SIG UUIDs.
// The device uses a proprietary 3-channel (unlock / tx / rx) protocol.
const String UNLOCK_UUID = 'b305b680-aee7-11e1-a730-0002a5d5c51b';
const String TX_UUID     = 'db5b55e0-aee7-11e1-965e-0002a5d5c51b';
const String RX_UUID     = '49123040-aee8-11e1-a74d-0002a5d5c51b';

// ── Default WLP AES-128 key ───────────────────────────────────────────────────
final Uint8List DEFAULT_KEY = Uint8List.fromList([
  0x54, 0x26, 0x9c, 0xbb, 0x82, 0x34, 0x49, 0x19,
  0xbd, 0x62, 0x0d, 0xcc, 0x3b, 0xdc, 0x0e, 0x1c,
]);

// ── Flag bitmasks (byte 7 of each 14-byte record) ────────────────────────────
const int FLAG_USER2     = 0x01; // reading belongs to user 2 (not user 1)
const int FLAG_IRREGULAR = 0x02; // irregular heartbeat detected
const int FLAG_MOVEMENT  = 0x04; // body movement during measurement
const int FLAG_MORNING   = 0x08; // morning reading

// ── EEPROM layout ─────────────────────────────────────────────────────────────
// Each record is 14 bytes; device has 14 slots organised as a ring buffer.
const int RECORD_BYTES = 14;
const int TOTAL_SLOTS  = 14;

/// (address, size) pairs for the 5 read commands that cover all 14 slots.
/// The device rejects reads > 28 bytes at 0x0390 so slots 13 & 14 are split.
const List<List<int>> RECORD_READS = [
  [0x02e8, 0x38], // 56 bytes → slots  1-4
  [0x0320, 0x38], // 56 bytes → slots  5-8
  [0x0358, 0x38], // 56 bytes → slots  9-12
  [0x0390, 0x0E], // 14 bytes → slot  13
  [0x039E, 0x0E], // 14 bytes → slot  14
];

/// Metadata reads: index block (ring-buffer state) + device clock summary.
const List<List<int>> META_READS = [
  [0x0260, 0x2c], // 44 bytes — index block
  [0x028c, 0x18], // 24 bytes — summary / device clock
];

/// Session start / end commands sent on the TX characteristic.
final Uint8List CMD_START_TX = Uint8List.fromList(
    [0x08, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x18]);
final Uint8List CMD_END_TX = Uint8List.fromList(
    [0x08, 0x0f, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07]);

// ═════════════════════════════════════════════════════════════════════════════
// Data models
// ═════════════════════════════════════════════════════════════════════════════

/// A single blood-pressure record decoded from the device's EEPROM.
class BPReading {
  final int slot;            // 1-based slot index in the ring buffer
  final int seq;             // monotonic sequence counter (0-255, wraps)
  final int ringRank;        // 0 = newest, 1 = next, … (set after ordering)
  final int systolicMmhg;
  final int diastolicMmhg;
  final int pulseBpm;
  final double mapMmhg;      // mean arterial pressure
  final String bpCategory;   // "NORMAL" / "ELEVATED" / "HIGH - STAGE 1" / …
  final String timestamp;    // ISO-8601 or "unsynced:…" if clock not set
  final String? timestampNote;
  final String? timeOfDay;   // "morning" / "afternoon" / "evening" / "night"
  final int user;            // 1 or 2
  final BPFlags flags;
  final bool checksumOk;
  final String rawHex;

  const BPReading({
    required this.slot,
    required this.seq,
    required this.ringRank,
    required this.systolicMmhg,
    required this.diastolicMmhg,
    required this.pulseBpm,
    required this.mapMmhg,
    required this.bpCategory,
    required this.timestamp,
    this.timestampNote,
    this.timeOfDay,
    required this.user,
    required this.flags,
    required this.checksumOk,
    required this.rawHex,
  });

  @override
  String toString() =>
      'BPReading(slot=$slot, seq=$seq, '
      '$systolicMmhg/$diastolicMmhg mmHg, pulse=$pulseBpm, '
      'user=$user, $bpCategory)';
}

/// Decoded measurement-status flags from byte 7 of a record.
class BPFlags {
  final String raw;
  final bool irregularHeartbeat;
  final bool bodyMovement;
  final bool morningReading;

  const BPFlags({
    required this.raw,
    required this.irregularHeartbeat,
    required this.bodyMovement,
    required this.morningReading,
  });
}

/// Parsed content of the index block (0x0260) that describes ring-buffer state.
class IndexInfo {
  final int? writePtr;   // next write position (0-based slot index)
  final int? countU1;    // records stored for user 1
  final int? countU2;    // records stored for user 2
  final int? totalEver;  // total records ever written (may wrap at 255)
  final String rawHex;

  const IndexInfo({
    this.writePtr,
    this.countU1,
    this.countU2,
    this.totalEver,
    required this.rawHex,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Low-level helpers
// ═════════════════════════════════════════════════════════════════════════════

String _hex(List<int> data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

/// XOR of all bytes — used for the simple checksum in command packets.
int _xorAll(List<int> data) => data.fold(0, (acc, b) => acc ^ b);

/// Build a read command:  [0x08, 0x01, 0x00, addrHi, addrLo, size, 0x00, xor]
Uint8List _readCmd(int address, int size) {
  final body = [
    0x08, 0x01, 0x00,
    (address >> 8) & 0xFF, address & 0xFF,
    size & 0xFF, 0x00,
  ];
  body.add(_xorAll(body));
  return Uint8List.fromList(body);
}

/// Build a set-time command: [0x09, yy, mm, dd, HH, MM, SS, xor]
Uint8List _setTimeCmd() {
  final now = DateTime.now();
  final body = [
    0x09,
    now.year - 2000, now.month, now.day,
    now.hour, now.minute, now.second,
  ];
  body.add(_xorAll(body));
  return Uint8List.fromList(body);
}

/// Parse an RX notification packet.
/// Returns (ptype, addr, payload) where ptype is the 2-byte type field.
({List<int> ptype, List<int> addr, List<int> payload}) _parsePkt(List<int> data) {
  if (data.length < 6) return (ptype: [], addr: [], payload: []);
  final ptype   = data.sublist(1, 3);
  final addr    = data.sublist(3, 5);
  final n       = data[5];
  final payload = (6 + n <= data.length)
      ? data.sublist(6, 6 + n)
      : data.sublist(6);
  return (ptype: ptype, addr: addr, payload: payload);
}

/// Decode timestamp bytes from a record (bytes 3-6).
({String ts, String? warn, String? tod}) _decodeTs(int b3, int b4, int b5, int b6) {
  final year = 2000 + b3;
  if (year >= 2020 && year <= 2035 &&
      b4 >= 1 && b4 <= 12 &&
      b5 >= 1 && b5 <= 31 &&
      b6 >= 0 && b6 <= 23) {
    try {
      final dt  = DateTime(year, b4, b5, b6);
      final tod = b6 >= 6  && b6 < 12 ? 'morning'
                : b6 >= 12 && b6 < 18 ? 'afternoon'
                : b6 >= 18 && b6 < 22 ? 'evening'
                :                        'night';
      return (ts: dt.toIso8601String(), warn: null, tod: tod);
    } catch (_) {}
  }
  return (
    ts: 'unsynced:${b3.toRadixString(16).padLeft(2,'0')}'
        '${b4.toRadixString(16).padLeft(2,'0')}'
        '${b5.toRadixString(16).padLeft(2,'0')}'
        '${b6.toRadixString(16).padLeft(2,'0')}',
    warn: 'Clock not synced',
    tod: null,
  );
}

/// Decode the device-clock summary from the 0x028c metadata block.
String? _decodeSummaryTs(List<int> data) {
  if (data.length < 14) return null;
  try {
    return DateTime(
      2000 + data[8], data[9], data[10],
      data[11],
      data.length > 12 ? data[12] : 0,
      data.length > 13 ? data[13] : 0,
    ).toIso8601String();
  } catch (_) {
    return null;
  }
}

/// AHA blood-pressure classification.
String _bpCategory(int s, int d) {
  if (s < 120 && d < 80)  return 'NORMAL';
  if (s < 130 && d < 80)  return 'ELEVATED';
  if (s < 140 && d < 90)  return 'HIGH - STAGE 1';
  return 'HIGH - STAGE 2';
}

// ═════════════════════════════════════════════════════════════════════════════
// WLP key authentication  (AES-128 ECB via pointycastle)
// ═════════════════════════════════════════════════════════════════════════════

/// Compute the 16-byte WLP response:
///   AES-ECB( key, clientNonce[0:4] ++ deviceNonce[0:4] ++ 0x00*8 )
Uint8List _computeWlpResponse(
    Uint8List key, Uint8List clientNonce, Uint8List deviceNonce) {
  final plaintext = Uint8List(16)
    ..setRange(0, 4, clientNonce)
    ..setRange(4, 8, deviceNonce);
  // bytes 8..15 are already 0

  final cipher = ECBBlockCipher(AESEngine())
    ..init(true, KeyParameter(key));

  final out = Uint8List(16);
  cipher.processBlock(plaintext, 0, out, 0);
  return out;
}

// ═════════════════════════════════════════════════════════════════════════════
// Index block parser
// ═════════════════════════════════════════════════════════════════════════════

IndexInfo parseIndexBlock(List<int> data, {int totalSlots = TOTAL_SLOTS}) {
  final rawHex = _hex(data.length >= 24 ? data.sublist(0, 24) : data);

  if (data.length < 21) {
    return IndexInfo(rawHex: rawHex);
  }

  final wp = data[17];
  final c1 = data[18];
  final c2 = data[19];
  final te = data[20];

  if (wp < totalSlots) {
    return IndexInfo(
        writePtr: wp, countU1: c1, countU2: c2, totalEver: te, rawHex: rawHex);
  }

  // Fallback: try the next byte offset
  final wp2 = data.length > 20 ? data[20] : 0xFF;
  if (wp2 < totalSlots) {
    return IndexInfo(
        writePtr: wp2,
        countU1: data[17],
        countU2: data[18],
        totalEver: data[19],
        rawHex: rawHex);
  }

  return IndexInfo(rawHex: rawHex);
}

// ═════════════════════════════════════════════════════════════════════════════
// Ring-buffer ordering
// ═════════════════════════════════════════════════════════════════════════════

/// Compute newest→oldest 0-based slot indices from write pointer alone.
List<int> _ringBufferOrder(int writePtr, int totalSlots) {
  final newest = (writePtr - 1) % totalSlots;
  return List.generate(totalSlots, (i) => (newest - i) % totalSlots);
}

bool _isDescendingMod256(List<int> seqs) {
  for (var i = 0; i < seqs.length - 1; i++) {
    final diff = (seqs[i] - seqs[i + 1]) % 256;
    if (diff == 0 || diff > 128) return false;
  }
  return true;
}

/// Return slot indices (0-based) in newest→oldest order, verified by seq nums.
/// Falls back to pure seq-number ordering if write_ptr is ambiguous.
List<int> seqVerifiedOrder(
    Map<int, Uint8List> slotRaw, int? writePtr, int totalSlots) {
  // Extract seq (byte 10) from each slot
  final seqMap = <int, int>{};
  slotRaw.forEach((slot0, raw) {
    if (raw.length >= 11) seqMap[slot0] = raw[10];
  });

  if (seqMap.isEmpty) return List.generate(totalSlots, (i) => i);

  if (writePtr != null) {
    final candidate = _ringBufferOrder(writePtr, totalSlots);
    final orderedSeqs = candidate
        .where((s) => seqMap.containsKey(s))
        .map((s) => seqMap[s]!)
        .toList();

    if (_isDescendingMod256(orderedSeqs)) {
      return candidate; // write_ptr is consistent with seq numbers
    }
    // write_ptr is ambiguous — fall through to seq-only ordering
  }

  // Sort slots by seq ascending, then detect wrap-around gap > 128
  final filled = seqMap.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  final seqsAsc = filled.map((e) => e.value).toList();

  int maxGap = 0;
  int gapIdx = filled.length - 1;
  for (var i = 0; i < seqsAsc.length - 1; i++) {
    final gap = seqsAsc[i + 1] - seqsAsc[i];
    if (gap > maxGap) {
      maxGap = gap;
      gapIdx = i;
    }
  }

  List<MapEntry<int, int>> ordered;
  if (maxGap > 128) {
    // Wrap detected: low-raw-seq entries are newer (post-wrap)
    final oldPart = filled.sublist(0, gapIdx + 1)
      ..sort((a, b) => b.value.compareTo(a.value));
    final newPart = filled.sublist(gapIdx + 1)
      ..sort((a, b) => b.value.compareTo(a.value));
    ordered = [...newPart, ...oldPart];
  } else {
    ordered = filled.reversed.toList();
  }

  final result = ordered.map((e) => e.key).toList();
  // Append slots with no data at the end
  for (var s = 0; s < totalSlots; s++) {
    if (!seqMap.containsKey(s)) result.add(s);
  }
  return result;
}

// ═════════════════════════════════════════════════════════════════════════════
// Record parser
// ═════════════════════════════════════════════════════════════════════════════

/// Decode a single 14-byte EEPROM record.  [slotNum] is 1-based.
/// Returns null if the slot is empty, erased, or fails validation.
BPReading? parseRecord(Uint8List raw, int slotNum) {
  if (raw.length < RECORD_BYTES) return null;
  if (raw.every((b) => b == 0x00)) return null;
  if (raw.every((b) => b == 0xFF)) return null;
  if (raw[0] >= 0xE0)              return null; // padding marker

  final s     = raw[0] + 25; // systolic  (stored as value - 25)
  final d     = raw[1];      // diastolic
  final p     = raw[2];      // pulse
  final flags = raw[7];
  final seq   = raw[10];

  // Physiological sanity check
  if (!(s >= 50 && s <= 260 && d >= 25 && d <= 160 && d < s &&
        p >= 25 && p <= 220)) {
    return null;
  }

  // Checksum: sum of bytes 0..12, mod 256, should equal byte 13
  final expected = raw.sublist(0, 13).fold(0, (acc, b) => (acc + b) & 0xFF);
  final checksumOk = (raw.length > 13) && (expected == raw[13]);

  final user = (flags & FLAG_USER2) != 0 ? 2 : 1;
  final tsResult = _decodeTs(raw[3], raw[4], raw[5], raw[6]);

  return BPReading(
    slot:            slotNum,
    seq:             seq > 0 ? seq : slotNum,
    ringRank:        0, // overwritten after ordering
    systolicMmhg:   s,
    diastolicMmhg:  d,
    pulseBpm:        p,
    mapMmhg:         double.parse(((s + 2.0 * d) / 3).toStringAsFixed(1)),
    bpCategory:      _bpCategory(s, d),
    timestamp:       tsResult.ts,
    timestampNote:   tsResult.warn,
    timeOfDay:       tsResult.tod,
    user:            user,
    flags: BPFlags(
      raw:                '0x${flags.toRadixString(16).padLeft(2, '0')}',
      irregularHeartbeat: (flags & FLAG_IRREGULAR) != 0,
      bodyMovement:       (flags & FLAG_MOVEMENT) != 0,
      morningReading:     (flags & FLAG_MORNING) != 0,
    ),
    checksumOk: checksumOk,
    rawHex:     _hex(raw),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// BLE connection state
// ═════════════════════════════════════════════════════════════════════════════

class _OmronConn {
  final BluetoothDevice device;
  BluetoothCharacteristic? charUnlock;
  BluetoothCharacteristic? charTx;
  BluetoothCharacteristic? charRx;

  final _unlockQ = StreamController<List<int>>.broadcast();
  final _rxQ     = StreamController<List<int>>.broadcast();

  StreamSubscription<List<int>>? _unlockSub;
  StreamSubscription<List<int>>? _rxSub;

  _OmronConn(this.device);

  Future<void> connect() async {
    await device.connect(
      autoConnect: false,
      license: License.free,
    );
    await Future.delayed(const Duration(seconds: 2));
    try {
      await device.createBond();
    } catch (_) {}

    final services = await device.discoverServices();
    for (final svc in services) {
      for (final c in svc.characteristics) {
        final u = c.uuid.toString().toLowerCase();
        if (u.contains('b305b680')) charUnlock = c;
        if (u.contains('db5b55e0')) charTx     = c;
        if (u.contains('49123040')) charRx      = c;
      }
    }

    if (charUnlock == null || charTx == null || charRx == null) {
      throw Exception('Missing Omron custom BLE characteristics');
    }

    await charUnlock!.setNotifyValue(true);
    await charRx!.setNotifyValue(true);

    _unlockSub = charUnlock!.onValueReceived.listen(_unlockQ.add);
    _rxSub     = charRx!.onValueReceived.listen(_rxQ.add);

    await Future.delayed(const Duration(milliseconds: 500));
    _drainQ(_unlockQ);
    _drainQ(_rxQ);
  }

  void _drainQ(StreamController q) {
    // Nothing to drain with broadcast streams — they don't buffer.
    // We rely on timing (connect delay) to clear stale notifications.
  }

  Future<void> writeUnlock(List<int> data) =>
      charUnlock!.write(data, withoutResponse: true);

  Future<void> writeTx(List<int> data) =>
      charTx!.write(data, withoutResponse: true);

  Future<List<int>> waitUnlock({Duration timeout = const Duration(seconds: 7)}) =>
      _unlockQ.stream.first.timeout(timeout);

  Future<List<int>> waitRx({Duration timeout = const Duration(seconds: 5)}) =>
      _rxQ.stream.first.timeout(timeout);

  Future<void> disconnect() async {
    await _unlockSub?.cancel();
    await _rxSub?.cancel();
    await _unlockQ.close();
    await _rxQ.close();
    try {
      await device.disconnect();
    } catch (_) {}
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WLP 3-step unlock
// ═════════════════════════════════════════════════════════════════════════════

/// Performs the 3-step WLP unlock handshake.
///
/// Step 1: send  [0x11] + 4-byte client nonce + 15 zero bytes
/// Step 2: device replies [0x91, 0x00, ...device nonce...]
/// Step 3: send  [0x12] + AES-128-ECB( key, clientNonce||deviceNonce||0*8 )
Future<void> doUnlock(_OmronConn conn, {Uint8List? key}) async {
  key ??= DEFAULT_KEY;

  // Generate 4-byte random client nonce
  final rng = Random.secure();
  final clientNonce = Uint8List.fromList(
      List.generate(4, (_) => rng.nextInt(256)));

  final payload = Uint8List(20)
    ..[0] = 0x11
    ..setRange(1, 5, clientNonce);
  // bytes 5..19 are already 0

  await conn.writeUnlock(payload);

  final resp = await conn.waitUnlock();
  if (resp.length < 2 || resp[0] != 0x91) {
    throw Exception('Unexpected unlock response: ${_hex(resp)}');
  }
  if (resp[1] != 0x00) {
    throw Exception('Unlock rejected (status 0x${resp[1].toRadixString(16)})');
  }

  final deviceNonce = Uint8List.fromList(
      resp.length >= 6 ? resp.sublist(2, 6) : List.filled(4, 0));

  // If device nonce is all-zero, this is a simple firmware — no step 3 needed
  if (deviceNonce.any((b) => b != 0)) {
    final response  = _computeWlpResponse(key, clientNonce, deviceNonce);
    final authBytes = Uint8List(17)
      ..[0] = 0x12
      ..setRange(1, 17, response);

    await conn.writeUnlock(authBytes);

    try {
      final ack = await conn.waitUnlock(timeout: const Duration(seconds: 4));
      if (ack.length >= 2 && ack[0] == 0x92 && ack[1] == 0x00) {
        // WLP auth confirmed
      }
      // Any other ack: proceed anyway
    } on TimeoutException {
      // Simple firmware — no 0x92 ack expected
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Clock sync
// ═════════════════════════════════════════════════════════════════════════════

/// Sends a set-time command to sync the device clock to phone time.
Future<void> doSetTime(_OmronConn conn) async {
  await conn.writeUnlock(_setTimeCmd());
  await Future.delayed(const Duration(milliseconds: 500));
}

// ═════════════════════════════════════════════════════════════════════════════
// BPService — public API
// ═════════════════════════════════════════════════════════════════════════════

/// Result returned by [BPService.readAllRecords].
class BPServiceResult {
  final List<BPReading> readings;     // newest-first
  final BPReading?      latest;       // readings.first (or null)
  final IndexInfo       indexInfo;
  final String?         deviceClock;  // ISO-8601 from summary block, or null
  final bool            clockSynced;

  const BPServiceResult({
    required this.readings,
    required this.latest,
    required this.indexInfo,
    required this.deviceClock,
    required this.clockSynced,
  });
}

/// Blood-pressure service for the Omron HEM-7140T1 (and similar).
///
/// Usage:
/// ```dart
/// final result = await BPService.readAllRecords(
///   device: device,
///   syncTime: false,
///   onProgress: (msg) => print(msg),
/// );
/// ```
class BPService {
  BPService._();

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns true if [serviceUuid] matches any Omron custom characteristic UUID.
  /// Use this in BleManager.deviceType() to identify an Omron BP device when
  /// it does NOT advertise 0x1810.
  static bool isOmronCustomService(String serviceUuid) {
    final u = serviceUuid.toLowerCase();
    return u.contains('b305b680') ||
           u.contains('db5b55e0') ||
           u.contains('49123040');
  }

  // ── Clock-sync only (pair flow) ───────────────────────────────────────────

  /// Connect, unlock, sync clock, verify, disconnect.
  /// Equivalent to the Python `pair_device()` function.
  static Future<bool> syncClock({
    required BluetoothDevice device,
    Uint8List? key,
    void Function(String)? onProgress,
  }) async {
    final conn = _OmronConn(device);
    try {
      onProgress?.call('Connecting…');
      await conn.connect();

      onProgress?.call('Unlocking (WLP)…');
      await doUnlock(conn, key: key);

      onProgress?.call('Syncing clock…');
      await doSetTime(conn);

      // Start a session just long enough to read back the clock
      await conn.writeTx(CMD_START_TX);
      try {
        await conn.waitRx(timeout: const Duration(seconds: 5));
      } catch (_) {}

      await conn.writeTx(_readCmd(0x028c, 0x18));
      try {
        final resp = await conn.waitRx(timeout: const Duration(seconds: 5));
        final pkt  = _parsePkt(resp);
        final ts   = _decodeSummaryTs(pkt.payload);
        if (ts != null) onProgress?.call('Device clock verified: $ts');
      } catch (_) {}

      await conn.writeTx(CMD_END_TX);
      onProgress?.call('Clock sync complete ✓');
      return true;
    } catch (e) {
      onProgress?.call('Error: $e');
      return false;
    } finally {
      await conn.disconnect();
    }
  }

  // ── Full record read ──────────────────────────────────────────────────────

  /// Connect to an Omron HEM-7140T1, perform the WLP unlock, read all 14
  /// EEPROM slots, decode the ring-buffer order using sequence numbers, and
  /// return all valid [BPReading] objects newest-first.
  ///
  /// Parameters:
  ///  - [device]     : already-discovered BluetoothDevice (pass from BleManager)
  ///  - [syncTime]   : if true, sync device clock before reading
  ///  - [key]        : WLP AES-128 key (defaults to [DEFAULT_KEY])
  ///  - [onProgress] : optional callback for status strings
  static Future<BPServiceResult> readAllRecords({
    required BluetoothDevice device,
    bool syncTime = false,
    Uint8List? key,
    void Function(String)? onProgress,
  }) async {
    final conn = _OmronConn(device);
    try {
      onProgress?.call('Connecting to ${device.platformName}…');
      await conn.connect();

      onProgress?.call('Unlocking (3-step WLP)…');
      await doUnlock(conn, key: key);

      if (syncTime) {
        onProgress?.call('Syncing clock…');
        await doSetTime(conn);
      }

      // ── Start transmission session ──────────────────────────────────────
      onProgress?.call('Starting transmission…');
      await conn.writeTx(CMD_START_TX);
      try {
        await conn.waitRx(timeout: const Duration(seconds: 5));
      } on TimeoutException {
        onProgress?.call('No startTX response — continuing');
      }

      // ── Read metadata ───────────────────────────────────────────────────
      final rawMeta = <int, List<int>>{};
      for (final read in META_READS) {
        final address = read[0], size = read[1];
        await conn.writeTx(_readCmd(address, size));
        try {
          final resp = await conn.waitRx();
          final pkt  = _parsePkt(resp);
          if (pkt.ptype.length == 2 &&
              pkt.ptype[0] == 0x81 && pkt.ptype[1] == 0x00 &&
              pkt.payload.isNotEmpty) {
            rawMeta[address] = pkt.payload;
          }
        } on TimeoutException {
          onProgress?.call('Timeout reading meta 0x${address.toRadixString(16)}');
        }
      }

      // ── Parse index block ───────────────────────────────────────────────
      final indexData = rawMeta[0x0260] ?? [];
      final indexInfo = parseIndexBlock(indexData);
      final writePtr  = indexInfo.writePtr;

      onProgress?.call(
        'Index → writePtr=$writePtr  '
        'u1=${indexInfo.countU1}  u2=${indexInfo.countU2}  '
        'total=${indexInfo.totalEver}',
      );

      final summaryData  = rawMeta[0x028c] ?? [];
      final deviceClock  = _decodeSummaryTs(summaryData);
      if (deviceClock != null) onProgress?.call('Device clock: $deviceClock');

      // ── Read slot data ──────────────────────────────────────────────────
      onProgress?.call('Reading $TOTAL_SLOTS slots…');
      final slotRaw    = <int, Uint8List>{};
      int   byteCursor = 0;

      for (final read in RECORD_READS) {
        final address = read[0], size = read[1];
        await conn.writeTx(_readCmd(address, size));
        try {
          final resp = await conn.waitRx();
          final pkt  = _parsePkt(resp);
          if (pkt.ptype.length == 2 &&
              pkt.ptype[0] == 0x81 && pkt.ptype[1] == 0x00 &&
              pkt.payload.isNotEmpty) {
            for (var i = 0; i < pkt.payload.length; i += RECORD_BYTES) {
              final slot0 = byteCursor ~/ RECORD_BYTES;
              final chunk = pkt.payload.sublist(
                  i, (i + RECORD_BYTES).clamp(0, pkt.payload.length));
              if (chunk.length == RECORD_BYTES && slot0 < TOTAL_SLOTS) {
                slotRaw[slot0] = Uint8List.fromList(chunk);
              }
              byteCursor += chunk.length;
            }
          } else {
            byteCursor += size;
          }
        } on TimeoutException {
          onProgress?.call('Timeout at 0x${address.toRadixString(16)}');
          byteCursor += size;
        }
      }

      // ── Determine ring order ────────────────────────────────────────────
      final slotOrder = seqVerifiedOrder(slotRaw, writePtr, TOTAL_SLOTS);

      // ── Decode records ──────────────────────────────────────────────────
      final readings = <BPReading>[];
      for (final slot0 in slotOrder) {
        final raw = slotRaw[slot0];
        if (raw == null) continue;
        final rec = parseRecord(raw, slot0 + 1); // 1-based slot number
        if (rec != null) readings.add(rec);
      }

      // Re-assign ring rank after filtering
      final ranked = <BPReading>[];
      for (var i = 0; i < readings.length; i++) {
        final r = readings[i];
        ranked.add(BPReading(
          slot:            r.slot,
          seq:             r.seq,
          ringRank:        i,
          systolicMmhg:   r.systolicMmhg,
          diastolicMmhg:  r.diastolicMmhg,
          pulseBpm:        r.pulseBpm,
          mapMmhg:         r.mapMmhg,
          bpCategory:      r.bpCategory,
          timestamp:       r.timestamp,
          timestampNote:   r.timestampNote,
          timeOfDay:       r.timeOfDay,
          user:            r.user,
          flags:           r.flags,
          checksumOk:      r.checksumOk,
          rawHex:          r.rawHex,
        ));
      }

      onProgress?.call(
        'Found ${ranked.length} record(s) in $TOTAL_SLOTS slots  '
        '(user1: ${ranked.where((r) => r.user == 1).length}, '
        'user2: ${ranked.where((r) => r.user == 2).length})',
      );

      // ── Close session ───────────────────────────────────────────────────
      await conn.writeTx(CMD_END_TX);
      try {
        await conn.waitRx(timeout: const Duration(seconds: 3));
      } catch (_) {}

      return BPServiceResult(
        readings:    ranked,
        latest:      ranked.isNotEmpty ? ranked.first : null,
        indexInfo:   indexInfo,
        deviceClock: deviceClock,
        clockSynced: syncTime,
      );
    } catch (e) {
      onProgress?.call('Error: $e');
      rethrow;
    } finally {
      await conn.disconnect();
    }
  }

  // ── Convenience: latest reading only ─────────────────────────────────────

  /// Read all records and return only the most recent one.
  static Future<BPReading?> readLatest({
    required BluetoothDevice device,
    bool syncTime = false,
    Uint8List? key,
    void Function(String)? onProgress,
  }) async {
    final result = await readAllRecords(
      device: device, syncTime: syncTime, key: key, onProgress: onProgress);
    return result.latest;
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  /// Return only readings for user 1 or user 2.
  static List<BPReading> filterByUser(List<BPReading> readings, int user) =>
      readings.where((r) => r.user == user).toList();

  // ── BP category color ─────────────────────────────────────────────────────

  /// Suggested UI color string for a BP category.
  static String categoryColor(String category) {
    switch (category) {
      case 'NORMAL':         return 'green';
      case 'ELEVATED':       return 'yellow';
      case 'HIGH - STAGE 1': return 'orange';
      case 'HIGH - STAGE 2': return 'red';
      default:               return 'grey';
    }
  }

  // ── Feature characteristic ────────────────────────────────────────────────

  // NOTE: The Omron HEM-7140T1 does NOT expose the standard 0x2A49 BP Feature
  // characteristic.  All feature / capability information must be inferred from
  // the custom protocol.  This stub is provided for API compatibility with
  // devices that do support 0x2A49.

  /// Read the standard BP Feature characteristic (0x2A49) if present.
  /// Returns null if the characteristic is not found (Omron custom devices).
  static Future<int?> readBPFeatures(
      {required BluetoothService service}) async {
    const featureUuid = '2a49';
    for (final c in service.characteristics) {
      if (c.uuid.toString().toLowerCase().contains(featureUuid)) {
        try {
          final value = await c.read();
          return value.isNotEmpty ? value[0] : null;
        } catch (_) {}
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Standard 0x2A35 path — for non-Omron BP devices
  // ═══════════════════════════════════════════════════════════════════════════

  /// Subscribe to the standard BT-SIG Blood Pressure Measurement (0x2A35).
  /// Only used when [BleManager.hasOmronCustomServices] returns false.
  static Future<void> subscribeToStandardBPMeasurement({
    required BluetoothService service,
    required Function(BPReading) onReading,
    Function(String)? onError,
  }) async {
    const bpMeasurementUuid = '2a35';
    BluetoothCharacteristic? bpChar;

    for (final c in service.characteristics) {
      if (c.uuid.toString().toLowerCase().contains(bpMeasurementUuid)) {
        bpChar = c;
        break;
      }
    }

    if (bpChar == null) {
      onError?.call('BP Measurement characteristic (0x2A35) not found');
      return;
    }

    await bpChar.setNotifyValue(true);

    bpChar.onValueReceived.listen((value) {
      final reading = _decodeStandard2A35(value);
      if (reading != null) onReading(reading);
    });
  }

  static BPReading? _decodeStandard2A35(List<int> data) {
    if (data.length < 7) return null;
    try {
      final flags = data[0];
      final unit  = (flags & 0x01) == 1 ? 'kPa' : 'mmHg';

      double _sfloat(int raw) {
        int mantissa = raw & 0x0FFF;
        if (mantissa >= 0x0800) mantissa -= 0x1000;
        int exponent = (raw >> 12) & 0x0F;
        if (exponent >= 0x08) exponent -= 0x10;
        return mantissa * _pow10(exponent);
      }

      final s   = _sfloat(data[1] | (data[2] << 8)).round();
      final d   = _sfloat(data[3] | (data[4] << 8)).round();
      final map = _sfloat(data[5] | (data[6] << 8));

      int idx = 7;
      DateTime? ts;
      if ((flags & 0x02) != 0 && data.length >= idx + 7) {
        final year   = data[idx] | (data[idx + 1] << 8); idx += 2;
        final month  = data[idx++];
        final day    = data[idx++];
        final hour   = data[idx++];
        final minute = data[idx++];
        final second = data[idx++];
        ts = DateTime(year, month, day, hour, minute, second);
      }

      int pulse = 0;
      if ((flags & 0x04) != 0 && data.length >= idx + 2) {
        pulse = _sfloat(data[idx] | (data[idx + 1] << 8)).round();
        idx += 2;
      }

      if (s < 50 || s > 260 || d < 25 || d > 160 || d >= s) return null;

      return BPReading(
        slot: 0, seq: 0, ringRank: 0,
        systolicMmhg:  s,
        diastolicMmhg: d,
        pulseBpm:       pulse,
        mapMmhg:        double.parse(map.toStringAsFixed(1)),
        bpCategory:     _bpCategory(s, d),
        timestamp:      (ts ?? DateTime.now()).toIso8601String(),
        user: 1,
        flags: BPFlags(
          raw: '0x00',
          irregularHeartbeat: false,
          bodyMovement: false,
          morningReading: false,
        ),
        checksumOk: true,
        rawHex: _hex(data),
      );
    } catch (_) {
      return null;
    }
  }

  static double _pow10(int exp) {
    double result = 1.0;
    if (exp >= 0) {
      for (int i = 0; i < exp; i++) result *= 10.0;
    } else {
      for (int i = 0; i > exp; i--) result /= 10.0;
    }
    return result;
  }
}