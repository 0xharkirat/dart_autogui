import 'dart:io';
import 'package:dart_autogui/dart_autogui.dart';

Future<void> main() async {
  stdout.writeln('⚠️  Switch to a text editor! Starting in 3 seconds...');
  await Future.delayed(Duration(seconds: 3));

  stdout.writeln('Typing...');

  await Keyboard.typeWrite('Hello from Dart AutoGUI!', intervalSec: 0.05);
  await Keyboard.press(AutoGUIKey.enter);

  await Keyboard.typeWrite('Type with instant speed.');
  await Keyboard.press(AutoGUIKey.enter);

  stdout.writeln('Done!');
}
