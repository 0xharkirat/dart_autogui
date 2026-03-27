import 'dart:io';
import 'package:autogui/autogui.dart';

Future<void> main() async {
  stdout.writeln('⚠️  Switch to a text editor! Starting in 3 seconds...');
  await Future.delayed(Duration(seconds: 3));

  stdout.writeln('Typing...');

  await Keyboard.typeWrite('hello from dart autogui', intervalSec: 0.05);
  await Keyboard.press(AutoGUIKey.enter);

  await Keyboard.typeWrite('type with instant speed');
  await Keyboard.press(AutoGUIKey.enter);

  stdout.writeln('Done!');
}
