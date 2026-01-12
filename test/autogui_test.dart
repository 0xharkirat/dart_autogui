import 'package:autogui/autogui.dart';
import 'package:test/test.dart';

void main() {
  group('Easing tests', () {
    test('Linear easing', () {
      expect(easeLinear(0.0), 0.0);
      expect(easeLinear(0.5), 0.5);
      expect(easeLinear(1.0), 1.0);
    });

    test('Quad easing', () {
      expect(easeInQuad(0.0), 0.0);
      expect(easeInQuad(0.5), 0.25);
      expect(easeInQuad(1.0), 1.0);
    });
  });
}
