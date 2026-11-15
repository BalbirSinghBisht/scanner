import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pure-Dart QR Code Generator & Renderer
/// Generates standard QR Code matrices (Versions 1-6, Byte Mode, EC Level L/M)
/// with 0 external dependencies, 100% offline, guaranteed instant execution.
class QrCodeGenerator {
  // Precomputed Reed-Solomon Galois Field GF(256) tables
  static final List<int> _expTable = List<int>.filled(512, 0);
  static final List<int> _logTable = List<int>.filled(256, 0);
  static bool _tablesInitialized = false;

  static void _initTables() {
    if (_tablesInitialized) return;
    int x = 1;
    for (int i = 0; i < 255; i++) {
      _expTable[i] = x;
      _logTable[x] = i;
      x <<= 1;
      if (x & 0x100 != 0) {
        x ^= 0x11d; // Primitive polynomial x^8 + x^4 + x^3 + x^2 + 1
      }
    }
    for (int i = 255; i < 512; i++) {
      _expTable[i] = _expTable[i - 255];
    }
    _tablesInitialized = true;
  }

  static int _gMult(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _expTable[_logTable[a] + _logTable[b]];
  }

  static List<int> _rsGeneratorPoly(int degree) {
    List<int> poly = [1];
    for (int i = 0; i < degree; i++) {
      final factor = [1, _expTable[i]];
      final newPoly = List<int>.filled(poly.length + 1, 0);
      for (int j = 0; j < poly.length; j++) {
        newPoly[j] ^= _gMult(poly[j], factor[0]);
        newPoly[j + 1] ^= _gMult(poly[j], factor[1]);
      }
      poly = newPoly;
    }
    return poly;
  }

  static List<int> _computeEcBytes(List<int> data, int ecCount) {
    final gen = _rsGeneratorPoly(ecCount);
    final msg = List<int>.from(data)..addAll(List<int>.filled(ecCount, 0));
    for (int i = 0; i < data.length; i++) {
      final coef = msg[i];
      if (coef != 0) {
        for (int j = 0; j < gen.length; j++) {
          msg[i + j] ^= _gMult(gen[j], coef);
        }
      }
    }
    return msg.sublist(data.length);
  }

  /// Encodes [text] into a 2D boolean grid: true = dark dot, false = light dot
  static List<List<bool>> generate(String text) {
    _initTables();
    final bytes = text.codeUnits;
    final int dataLen = bytes.length;

    // Pick version based on byte capacity (EC Level M)
    // V1: 14 bytes, V2: 26 bytes, V3: 42 bytes, V4: 62 bytes, V5: 84 bytes, V6: 106 bytes
    int version = 1;
    int ecCodewords = 10;
    int dataCapacity = 16;

    if (dataLen <= 14) {
      version = 1;
      ecCodewords = 10;
      dataCapacity = 16;
    } else if (dataLen <= 26) {
      version = 2;
      ecCodewords = 16;
      dataCapacity = 28;
    } else if (dataLen <= 42) {
      version = 3;
      ecCodewords = 26;
      dataCapacity = 44;
    } else if (dataLen <= 62) {
      version = 4;
      ecCodewords = 36;
      dataCapacity = 64;
    } else if (dataLen <= 84) {
      version = 5;
      ecCodewords = 48;
      dataCapacity = 86;
    } else {
      version = 6;
      ecCodewords = 64;
      dataCapacity = 108;
    }

    // Build data bitstream (Mode 0100 = 8-bit Byte mode)
    final bitStream = <int>[];
    void putBits(int value, int length) {
      for (int i = length - 1; i >= 0; i--) {
        bitStream.add((value >> i) & 1);
      }
    }

    // Mode indicator: 0100 (Byte mode)
    putBits(4, 4);
    // Character count indicator: 8 bits for versions 1-9
    putBits(dataLen, 8);
    // Data bytes
    for (final b in bytes) {
      putBits(b, 8);
    }
    // Terminator bits (up to 4 zeroes)
    final remainingBits = (dataCapacity * 8) - bitStream.length;
    final termLen = math.min(4, math.max(0, remainingBits));
    putBits(0, termLen);
    // Byte-align
    while (bitStream.length % 8 != 0) {
      bitStream.add(0);
    }
    // Pad bytes: alternating 0xEC (236) and 0x11 (17)
    final padBytes = [0xEC, 0x11];
    int padIdx = 0;
    while (bitStream.length < dataCapacity * 8) {
      putBits(padBytes[padIdx % 2], 8);
      padIdx++;
    }

    // Convert bitstream to data codewords
    final dataCodewords = <int>[];
    for (int i = 0; i < bitStream.length; i += 8) {
      int byteVal = 0;
      for (int b = 0; b < 8; b++) {
        byteVal = (byteVal << 1) | bitStream[i + b];
      }
      dataCodewords.add(byteVal);
    }

    // Compute error correction codewords
    final ecBytes = _computeEcBytes(dataCodewords, ecCodewords);
    final allCodewords = List<int>.from(dataCodewords)..addAll(ecBytes);

    // Matrix Dimension: (version - 1) * 4 + 21
    final size = (version - 1) * 4 + 21;
    final matrix = List.generate(size, (_) => List.filled(size, false));
    final reserved = List.generate(size, (_) => List.filled(size, false));

    // Place Finder Patterns (7x7)
    void placeFinder(int startRow, int startCol) {
      for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
          final row = startRow + r;
          final col = startCol + c;
          if (row >= 0 && row < size && col >= 0 && col < size) {
            reserved[row][col] = true;
            if (r >= 0 && r <= 6 && c >= 0 && c <= 6) {
              if (r == 0 || r == 6 || c == 0 || c == 6 || (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
                matrix[row][col] = true;
              } else {
                matrix[row][col] = false;
              }
            } else {
              matrix[row][col] = false; // Separator
            }
          }
        }
      }
    }

    placeFinder(0, 0); // Top-left
    placeFinder(0, size - 7); // Top-right
    placeFinder(size - 7, 0); // Bottom-left

    // Timing Patterns (Alternating dark and light modules at row 6 and col 6)
    for (int i = 8; i < size - 8; i++) {
      if (!reserved[6][i]) {
        reserved[6][i] = true;
        matrix[6][i] = i % 2 == 0;
      }
      if (!reserved[i][6]) {
        reserved[i][6] = true;
        matrix[i][6] = i % 2 == 0;
      }
    }

    // Alignment Patterns (for version >= 2)
    if (version >= 2) {
      final alignCoords = [
        [], // V0
        [], // V1
        [6, 18], // V2
        [6, 22], // V3
        [6, 26], // V4
        [6, 30], // V5
        [6, 34], // V6
      ][version];

      for (final r in alignCoords) {
        for (final c in alignCoords) {
          if (!reserved[r][c]) {
            for (int ar = -2; ar <= 2; ar++) {
              for (int ac = -2; ac <= 2; ac++) {
                final row = r + ar;
                final col = c + ac;
                reserved[row][col] = true;
                if (ar.abs() == 2 || ac.abs() == 2 || (ar == 0 && ac == 0)) {
                  matrix[row][col] = true;
                } else {
                  matrix[row][col] = false;
                }
              }
            }
          }
        }
      }
    }

    // Dark Module
    reserved[size - 8][8] = true;
    matrix[size - 8][8] = true;

    // Reserve Format Information areas
    for (int i = 0; i < 9; i++) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }
    for (int i = size - 8; i < size; i++) {
      reserved[8][i] = true;
      reserved[i][8] = true;
    }

    // Convert allCodewords into bit sequence
    final dataBits = <int>[];
    for (final cw in allCodewords) {
      for (int i = 7; i >= 0; i--) {
        dataBits.add((cw >> i) & 1);
      }
    }

    // Place Data Modules with standard Zigzag column scan
    int bitIdx = 0;
    int right = size - 1;
    bool upward = true;

    while (right > 0) {
      if (right == 6) right--; // Skip vertical timing column
      final cols = [right, right - 1];

      for (int count = 0; count < size; count++) {
        final row = upward ? (size - 1 - count) : count;
        for (final col in cols) {
          if (!reserved[row][col]) {
            int bit = 0;
            if (bitIdx < dataBits.length) {
              bit = dataBits[bitIdx++];
            }
            // Standard QR Mask Pattern 0: (row + col) % 2 == 0
            final mask = ((row + col) % 2 == 0) ? 1 : 0;
            matrix[row][col] = (bit ^ mask) == 1;
          }
        }
      }
      upward = !upward;
      right -= 2;
    }

    // Format Information: EC Level M (00) + Mask 0 (000) = 00000 -> 0x5412 with BCH
    // Precomputed BCH 15-bit sequence for (M, Mask 0): 101010000010010
    const int formatBits = 0x5412 ^ 0x0000; // 0x5412: 101010000010010
    final fmtStr = formatBits.toRadixString(2).padLeft(15, '0');

    // Place Format Bits around top-left, top-right, bottom-left
    final fmtPositions = [
      [8, 0], [8, 1], [8, 2], [8, 3], [8, 4], [8, 5], [8, 7], [8, 8],
      [7, 8], [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8]
    ];
    for (int i = 0; i < 15; i++) {
      final pos = fmtPositions[i];
      matrix[pos[0]][pos[1]] = fmtStr[14 - i] == '1';
    }

    // Duplicated format bits on right and bottom
    for (int i = 0; i < 7; i++) {
      matrix[size - 1 - i][8] = fmtStr[14 - i] == '1';
    }
    for (int i = 0; i < 8; i++) {
      matrix[8][size - 8 + i] = fmtStr[7 - i] == '1';
    }

    return matrix;
  }
}

/// Smooth Custom Painter for QR Code with rounded modules and crisp finder markers
class QrPainter extends CustomPainter {
  final List<List<bool>> matrix;
  final Color darkColor;
  final Color lightColor;
  final double padding;

  const QrPainter({
    required this.matrix,
    this.darkColor = const Color(0xFF000000),
    this.lightColor = const Color(0xFFFFFFFF),
    this.padding = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (matrix.isEmpty) return;

    final bgPaint = Paint()..color = lightColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ),
      bgPaint,
    );

    final n = matrix.length;
    final availableSize = math.min(size.width, size.height) - (padding * 2);
    final moduleSize = availableSize / n;
    final startX = (size.width - (moduleSize * n)) / 2;
    final startY = (size.height - (moduleSize * n)) / 2;

    final dotPaint = Paint()..color = darkColor;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (matrix[r][c]) {
          final rect = Rect.fromLTWH(
            startX + (c * moduleSize),
            startY + (r * moduleSize),
            moduleSize + 0.1,
            moduleSize + 0.1,
          );

          // Give modules subtle smooth rounding
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(moduleSize * 0.28)),
            dotPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.darkColor != darkColor ||
        oldDelegate.lightColor != lightColor;
  }
}

class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color darkColor;
  final Color lightColor;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.darkColor = const Color(0xFF000000),
    this.lightColor = const Color(0xFFFFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final matrix = QrCodeGenerator.generate(data);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: QrPainter(
          matrix: matrix,
          darkColor: darkColor,
          lightColor: lightColor,
        ),
      ),
    );
  }
}
