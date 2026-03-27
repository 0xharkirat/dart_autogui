import 'dart:io';

void main(List<String> args) async {
  print('Building dart_autogui native library...');

  final root = Directory.current;
  final buildDir = Directory('${root.path}/build');

  // Clean build dir if needed, or just recreate
  if (!buildDir.existsSync()) {
    buildDir.createSync();
  }

  // 1. Check for cmake
  try {
    final result = await Process.run('cmake', ['--version']);
    if (result.exitCode != 0) {
      print('Error: cmake not found. Please install cmake.');
      exit(1);
    }
  } catch (e) {
    print('Error: cmake not found. Please install cmake.');
    exit(1);
  }

  // 2. Run cmake
  print('Running cmake...');
  var cmakeProc = await Process.start('cmake', [
    '..',
  ], workingDirectory: buildDir.path);
  stdout.addStream(cmakeProc.stdout);
  stderr.addStream(cmakeProc.stderr);
  if (await cmakeProc.exitCode != 0) {
    print('cmake failed.');
    exit(1);
  }

  // 3. Build
  print('Building...');
  var makeProc = await Process.start('cmake', [
    '--build',
    '.',
  ], workingDirectory: buildDir.path);
  stdout.addStream(makeProc.stdout);
  stderr.addStream(makeProc.stderr);
  if (await makeProc.exitCode != 0) {
    print('Build failed.');
    exit(1);
  }

  // 4. Copy to convenient location or inform user
  print('Build successful!');

  String libName;
  if (Platform.isMacOS) {
    libName = 'libdart_autogui.dylib';
  } else if (Platform.isWindows) {
    libName = 'dart_autogui.dll';
  } else {
    libName = 'libdart_autogui.so';
  }

  // CMake build output is usually in build/ or build/Debug depending on generator
  // We search for it.
  final possiblePaths = [
    '${buildDir.path}/$libName',
    '${buildDir.path}/Debug/$libName',
    '${buildDir.path}/Release/$libName',
    '${buildDir.path}/src/native/macos/$libName', // Just in case cmake structure mimics source
  ];

  File? srcFile;
  for (final p in possiblePaths) {
    print('Checking for $p');
    final f = File(p);
    if (f.existsSync()) {
      srcFile = f;
      break;
    }
  }

  if (srcFile != null) {
    try {
      final dest = '${root.path}/$libName';
      srcFile.copySync(dest);
      print('Copied library to $dest');
    } catch (e) {
      print('Could not copy library to root: $e');
      print('Please manually copy ${srcFile.path} to your project root.');
    }
  } else {
    print('Could not locate built library in build directory.');
  }

  print('Setup complete. You can now use dart_autogui.');
}
