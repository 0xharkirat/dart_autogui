import 'package:autogui/autogui.dart';
import 'package:test/test.dart';

void main() {
  test('MouseButton is exported from the public package barrel', () {
    expect(MouseButton.right, MouseButton.right);
    expect(MouseButton.middle, MouseButton.middle);
  });
}
