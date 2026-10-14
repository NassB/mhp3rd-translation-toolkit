import 'dart:typed_data';

import 'errors.dart';

/// Écrivain séquentiel little-endian sur un tampon extensible.
///
/// Symétrique de `ByteReader` ; toute valeur hors plage lève [FormatError].
final class ByteWriter {
  /// Crée un écrivain vide.
  ByteWriter({int initialCapacity = 256})
      : _buf = Uint8List(initialCapacity < 16 ? 16 : initialCapacity) {
    _view = ByteData.sublistView(_buf);
  }

  Uint8List _buf;
  late ByteData _view;
  int _len = 0;

  /// Nombre d'octets écrits (= position courante).
  int get length => _len;

  /// Écrit un `u8`.
  void u8(int v) {
    _range(v, 0, 0xFF, 'u8');
    _ensure(1);
    _buf[_len++] = v;
  }

  /// Écrit un `u16` little-endian.
  void u16(int v) {
    _range(v, 0, 0xFFFF, 'u16');
    _ensure(2);
    _view.setUint16(_len, v, Endian.little);
    _len += 2;
  }

  /// Écrit un `u32` little-endian.
  void u32(int v) {
    _range(v, 0, 0xFFFFFFFF, 'u32');
    _ensure(4);
    _view.setUint32(_len, v, Endian.little);
    _len += 4;
  }

  /// Écrit un `i32` little-endian.
  void i32(int v) {
    _range(v, -0x80000000, 0x7FFFFFFF, 'i32');
    _ensure(4);
    _view.setInt32(_len, v, Endian.little);
    _len += 4;
  }

  /// Écrit [data] tel quel.
  void bytes(Uint8List data) {
    _ensure(data.length);
    _buf.setRange(_len, _len + data.length, data);
    _len += data.length;
  }

  /// Écrit [count] octets valant [value] (par défaut 0).
  void fill(int count, [int value = 0]) {
    if (count < 0) throw FormatError('negative fill $count', offset: _len);
    _range(value, 0, 0xFF, 'u8');
    _ensure(count);
    _buf.fillRange(_len, _len + count, value);
    _len += count;
  }

  /// Complète avec des zéros jusqu'au prochain multiple de [alignment].
  void padTo(int alignment) {
    if (alignment <= 0) {
      throw FormatError('non-positive alignment $alignment', offset: _len);
    }
    final rem = _len % alignment;
    if (rem != 0) fill(alignment - rem);
  }

  /// Copie des octets écrits.
  Uint8List toBytes() =>
      Uint8List.fromList(Uint8List.sublistView(_buf, 0, _len));

  void _range(int v, int min, int max, String type) {
    if (v < min || v > max) {
      throw FormatError('value $v out of range for $type', offset: _len);
    }
  }

  void _ensure(int extra) {
    final need = _len + extra;
    if (need <= _buf.length) return;
    var cap = _buf.length;
    while (cap < need) {
      cap *= 2;
    }
    final next = Uint8List(cap)..setRange(0, _len, _buf);
    _buf = next;
    _view = ByteData.sublistView(next);
  }
}
