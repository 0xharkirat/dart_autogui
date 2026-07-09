import 'dart:io';
import 'package:autogui/autogui.dart';

Future<void> main() async {
  stdout.writeln('⚠️  Switch to a text editor! Starting in 3 seconds...');
  await Future.delayed(Duration(seconds: 3));

  stdout.writeln('Typing...');

  // Type a line, then press Enter by name. A key can be given as a PyAutoGUI
  // style string ('enter'), an AutoGUIKey (AutoGUIKey.enter), or a raw keycode.
  await Keyboard.write(
    'hello from dart autogui',
    interval: Duration(milliseconds: 50),
  );
  await Keyboard.press('enter');

  // Named keys with a repeat count, plus navigation keys.
  await Keyboard.write('typo123');
  await Keyboard.press('backspace', presses: 3); // delete the "123"
  await Keyboard.press('home'); // jump to start of line
  await Keyboard.press('end'); // ...and back to the end
  await Keyboard.press('enter');

  // Chords use pyautogui-style string names. Use the platform's select-all
  // modifier: Command on macOS, Control elsewhere.
  final modifier = Platform.isMacOS ? 'command' : 'ctrl';
  await Keyboard.hotkey([modifier, 'a']); // select all
  await Keyboard.hotkey([modifier, 'c']); // copy

  final supported = Keyboard.keyboardKeys.where(Keyboard.isValidKey).length;
  stdout.writeln('Named keys supported on this platform: $supported');
  stdout.writeln('Done!');
}
