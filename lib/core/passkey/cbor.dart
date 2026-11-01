import 'dart:convert';
import 'dart:typed_data';

/// Minimal CBOR (RFC 8949) codec covering what WebAuthn/CTAP2 needs:
/// unsigned & negative ints, byte/text strings, arrays, maps, bools, null.
/// Map keys are emitted in CTAP2 canonical order.
class Cbor {
  Cbor._();

  static Uint8List encode(Object? value) {
    final b = BytesBuilder(copy: false);
    _encode(b, value);
    return b.toBytes();
  }

  static void _head(BytesBuilder b, int major, int n) {
    final m = major << 5;
    if (n < 24) {
      b.addByte(m | n);
    } else if (n < 0x100) {
      b
        ..addByte(m | 24)
        ..addByte(n);
    } else if (n < 0x10000) {
      b
        ..addByte(m | 25)
        ..addByte(n >> 8)
        ..addByte(n & 0xff);
    } else if (n < 0x100000000) {
      b.addByte(m | 26);
      for (var s = 24; s >= 0; s -= 8) {
        b.addByte((n >> s) & 0xff);
      }
    } else {
      b.addByte(m | 27);
      for (var s = 56; s >= 0; s -= 8) {
        b.addByte((n >> s) & 0xff);
      }
    }
  }

  static void _encode(BytesBuilder b, Object? v) {
    if (v == null) {
      b.addByte(0xf6);
    } else if (v is bool) {
      b.addByte(v ? 0xf5 : 0xf4);
    } else if (v is int) {
      if (v >= 0) {
        _head(b, 0, v);
      } else {
        _head(b, 1, -1 - v);
      }
    } else if (v is Uint8List) {
      _head(b, 2, v.length);
      b.add(v);
    } else if (v is String) {
      final bytes = utf8.encode(v);
      _head(b, 3, bytes.length);
      b.add(bytes);
    } else if (v is List) {
      _head(b, 4, v.length);
      for (final e in v) {
        _encode(b, e);
      }
    } else if (v is Map) {
      final entries = v.entries
          .map((e) => (encode(e.key), e.value))
          .toList()
        ..sort((a, c) => _compareKeys(a.$1, c.$1));
      _head(b, 5, entries.length);
      for (final (k, val) in entries) {
        b.add(k);
        _encode(b, val);
      }
    } else {
      throw ArgumentError('Unsupported CBOR type: ${v.runtimeType}');
    }
  }

  /// CTAP2 canonical ordering: shorter encoded keys first, then bytewise.
  static int _compareKeys(Uint8List a, Uint8List b) {
    if (a.length != b.length) return a.length - b.length;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] - b[i];
    }
    return 0;
  }

  static Object? decode(Uint8List data) {
    final r = _Reader(data);
    final v = r.read();
    if (r.pos != data.length) {
      throw const FormatException('Trailing bytes after CBOR item');
    }
    return v;
  }

  /// Decodes one item and returns it with the number of bytes consumed.
  static (Object?, int) decodePrefix(Uint8List data) {
    final r = _Reader(data);
    final v = r.read();
    return (v, r.pos);
  }
}

class _Reader {
  _Reader(this.data);
  final Uint8List data;
  int pos = 0;

  int _byte() {
    if (pos >= data.length) throw const FormatException('Truncated CBOR');
    return data[pos++];
  }

  int _arg(int info) {
    if (info < 24) return info;
    final n = switch (info) {
      24 => 1,
      25 => 2,
      26 => 4,
      27 => 8,
      _ => throw const FormatException('Unsupported CBOR length'),
    };
    var v = 0;
    for (var i = 0; i < n; i++) {
      v = (v << 8) | _byte();
    }
    return v;
  }

  Object? read() {
    final ib = _byte();
    final major = ib >> 5;
    final info = ib & 0x1f;
    switch (major) {
      case 0:
        return _arg(info);
      case 1:
        return -1 - _arg(info);
      case 2:
        final n = _arg(info);
        if (pos + n > data.length) throw const FormatException('Truncated');
        final out = Uint8List.fromList(data.sublist(pos, pos + n));
        pos += n;
        return out;
      case 3:
        final n = _arg(info);
        if (pos + n > data.length) throw const FormatException('Truncated');
        final s = utf8.decode(data.sublist(pos, pos + n));
        pos += n;
        return s;
      case 4:
        final n = _arg(info);
        return List<Object?>.generate(n, (_) => read());
      case 5:
        final n = _arg(info);
        final m = <Object?, Object?>{};
        for (var i = 0; i < n; i++) {
          final k = read();
          m[k] = read();
        }
        return m;
      case 7:
        return switch (info) {
          20 => false,
          21 => true,
          22 => null,
          _ => throw const FormatException('Unsupported CBOR simple value'),
        };
      default:
        throw FormatException('Unsupported CBOR major type $major');
    }
  }
}
