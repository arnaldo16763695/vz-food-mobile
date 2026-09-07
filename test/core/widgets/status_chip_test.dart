import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/core/widgets/status_chip.dart';

void main() {
  group('localizedStatusLabel', () {
    test('translates common order lifecycle codes to Spanish', () {
      expect(localizedStatusLabel('fulfilled'), 'Completado');
      expect(localizedStatusLabel('unfulfilled'), 'Sin completar');
      expect(
        localizedStatusLabel('partially_fulfilled'),
        'Completado parcialmente',
      );
      expect(localizedStatusLabel('preparing'), 'En preparacion');
      expect(localizedStatusLabel('awaiting_review'), 'En revision');
      expect(localizedStatusLabel('pickup'), 'Retiro');
    });

    test('is case and whitespace insensitive', () {
      expect(localizedStatusLabel('  FULFILLED '), 'Completado');
    });

    test('falls back to a titleized token for unknown codes', () {
      expect(localizedStatusLabel('some_new_state'), 'Some New State');
    });
  });
}
