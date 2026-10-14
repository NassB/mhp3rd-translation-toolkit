import 'errors.dart';

/// Taille d'un secteur ISO / bloc de patch, en octets (AGENTS.md §4.4).
const int sectorSize = 2048;

/// Arrondit [n] au multiple supérieur de [alignment].
///
/// [n] doit être ≥ 0 et [alignment] > 0, sinon [FormatError].
int alignUp(int n, int alignment) {
  if (n < 0) throw FormatError('alignUp: negative value $n');
  if (alignment <= 0) {
    throw FormatError('alignUp: non-positive alignment $alignment');
  }
  final rem = n % alignment;
  return rem == 0 ? n : n + alignment - rem;
}
