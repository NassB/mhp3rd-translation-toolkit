import 'dart:typed_data';

import 'errors.dart';

/// Lecteur séquentiel little-endian sur un tampon d'octets.
///
/// Toute lecture hors bornes lève [FormatError] avec l'offset fautif
/// (AGENTS.md §4.4 et §7). Aucune lecture silencieuse.
final class ByteReader {
  /// Crée un lecteur sur [data] ; [fileId] sert uniquement aux messages.
  ByteReader(Uint8List data, {this.fileId})
      : _data = data,
        _view = ByteData.sublistView(data);

  final Uint8List _data;
  final ByteData _view;

  /// ID de fichier (mhtools, base 1) joint aux erreurs, si connu.
  final int? fileId;

  int _pos = 0;

  /// Taille totale du tampon.
  int get length => _data.length;

  /// Position courante.
  int get position => _pos;

  /// Octets restants.
  int get remaining => _data.length - _pos;

  /// Lit un `u8`.
  int u8() {
    _need(1);
    return _view.getUint8(_pos++);
  }

  /// Lit un `u16` little-endian.
  int u16() {
    _need(2);
    final v = _view.getUint16(_pos, Endian.little);
    _pos += 2;
    return v;
  }

  /// Lit un `u32` little-endian.
  int u32() {
    _need(4);
    final v = _view.getUint32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

  /// Lit un `i32` little-endian.
  int i32() {
    _need(4);
    final v = _view.getInt32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

  /// Retourne une **vue** (sans copie) sur les [n] octets suivants.
  Uint8List bytes(int n) {
    if (n < 0) {
      throw FormatError('negative length $n', offset: _pos, fileId: fileId);
    }
    _need(n);
    final out = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return out;
  }

  /// Positionne le curseur à [offset] absolu (0 ≤ offset ≤ [length]).
  void seek(int offset) {
    if (offset < 0 || offset > _data.length) {
      throw FormatError(
        'seek out of bounds (length ${_data.length})',
        offset: offset,
        fileId: fileId,
      );
    }
    _pos = offset;
  }

  /// Avance (ou recule si négatif) le curseur de [n] octets.
  void skip(int n) => seek(_pos + n);

  void _need(int n) {
    if (n > _data.length - _pos) {
      throw FormatError(
        'read of $n byte(s) out of bounds (length ${_data.length})',
        offset: _pos,
        fileId: fileId,
      );
    }
  }
}
