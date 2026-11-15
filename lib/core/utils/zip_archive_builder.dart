import 'dart:typed_data';

/// Pure-Dart Zero-Dependency Zip Archive Builder
/// Creates standard, spec-compliant ZIP archives (Store / No-Compression mode)
/// 100% compatible with iOS Files, macOS Archive Utility, Windows Explorer, and Linux unzip.
/// Perfect for photos and videos which are already natively compressed (JPEG, PNG, MP4).
class ZipArchiveBuilder {
  static final List<int> _crcTable = _makeCrcTable();

  static List<int> _makeCrcTable() {
    final table = List<int>.filled(256, 0);
    for (int i = 0; i < 256; i++) {
      int c = i;
      for (int k = 0; k < 8; k++) {
        if ((c & 1) != 0) {
          c = 0xEDB88320 ^ (c >>> 1);
        } else {
          c = c >>> 1;
        }
      }
      table[i] = c;
    }
    return table;
  }

  static int computeCrc32(List<int> bytes) {
    int crc = 0xFFFFFFFF;
    for (final b in bytes) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }

  /// Builds a complete ZIP binary byte buffer from a map of [fileName] -> [fileBytes]
  static Uint8List buildZip(Map<String, List<int>> entries) {
    final centralDirBytes = BytesBuilder();
    final zipOutput = BytesBuilder();

    int offset = 0;
    int entryCount = 0;

    for (final entry in entries.entries) {
      final fileName = entry.key;
      final fileData = entry.value;
      final fileNameBytes = Uint8List.fromList(fileName.codeUnits);
      final crc = computeCrc32(fileData);
      final size = fileData.length;

      // Local File Header (30 bytes + filename)
      final localHeader = ByteData(30);
      localHeader.setUint32(0, 0x04034b50, Endian.little); // Signature
      localHeader.setUint16(4, 20, Endian.little); // Version needed (2.0)
      localHeader.setUint16(6, 0, Endian.little); // General flags
      localHeader.setUint16(8, 0, Endian.little); // Compression (0 = Store)
      localHeader.setUint16(10, 0x4821, Endian.little); // Mod time
      localHeader.setUint16(12, 0x5897, Endian.little); // Mod date
      localHeader.setUint32(14, crc, Endian.little); // CRC-32
      localHeader.setUint32(18, size, Endian.little); // Compressed size
      localHeader.setUint32(22, size, Endian.little); // Uncompressed size
      localHeader.setUint16(26, fileNameBytes.length, Endian.little); // Name length
      localHeader.setUint16(28, 0, Endian.little); // Extra field length

      zipOutput.add(localHeader.buffer.asUint8List());
      zipOutput.add(fileNameBytes);
      zipOutput.add(fileData);

      // Central Directory Header (46 bytes + filename)
      final centralHeader = ByteData(46);
      centralHeader.setUint32(0, 0x02014b50, Endian.little); // Central signature
      centralHeader.setUint16(4, 20, Endian.little); // Version made by
      centralHeader.setUint16(6, 20, Endian.little); // Version needed
      centralHeader.setUint16(8, 0, Endian.little); // Flags
      centralHeader.setUint16(10, 0, Endian.little); // Compression (0 = Store)
      centralHeader.setUint16(12, 0x4821, Endian.little); // Mod time
      centralHeader.setUint14(14, 0x5897, Endian.little); // Mod date
      centralHeader.setUint32(16, crc, Endian.little); // CRC-32
      centralHeader.setUint32(20, size, Endian.little); // Compressed size
      centralHeader.setUint32(24, size, Endian.little); // Uncompressed size
      centralHeader.setUint16(28, fileNameBytes.length, Endian.little); // Name length
      centralHeader.setUint16(30, 0, Endian.little); // Extra length
      centralHeader.setUint16(32, 0, Endian.little); // Comment length
      centralHeader.setUint16(34, 0, Endian.little); // Disk start
      centralHeader.setUint16(36, 0, Endian.little); // Internal attrs
      centralHeader.setUint32(38, 0, Endian.little); // External attrs
      centralHeader.setUint32(42, offset, Endian.little); // Offset of local header

      centralDirBytes.add(centralHeader.buffer.asUint8List());
      centralDirBytes.add(fileNameBytes);

      offset += 30 + fileNameBytes.length + size;
      entryCount++;
    }

    final centralDirData = centralDirBytes.toBytes();
    final centralDirOffset = offset;
    final centralDirSize = centralDirData.length;

    zipOutput.add(centralDirData);

    // End of Central Directory Record (22 bytes)
    final eocd = ByteData(22);
    eocd.setUint32(0, 0x06054b50, Endian.little); // EOCD Signature
    eocd.setUint16(4, 0, Endian.little); // Disk number
    eocd.setUint16(6, 0, Endian.little); // Disk with start of CD
    eocd.setUint16(8, entryCount, Endian.little); // Entries on disk
    eocd.setUint16(10, entryCount, Endian.little); // Total entries
    eocd.setUint32(12, centralDirSize, Endian.little); // Size of central dir
    eocd.setUint32(16, centralDirOffset, Endian.little); // Offset of central dir
    eocd.setUint16(20, 0, Endian.little); // Comment length

    zipOutput.add(eocd.buffer.asUint8List());

    return zipOutput.toBytes();
  }
}

extension on ByteData {
  void setUint14(int byteOffset, int value, Endian endian) {
    setUint16(byteOffset, value, endian);
  }
}

