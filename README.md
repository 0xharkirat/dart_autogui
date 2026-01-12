# dart_autogui

`dart_autogui` is a Dart package for cross-platform GUI automation. It enables you to programmatically control mouse and keyboard actions, take screenshots, and interact with the desktop—ideal for automation, testing, or scripting tasks.

**Note:** This package is under development. It is implemented purely in Dart using FFI bindings to C and platform-native interfaces. There are **no dependencies on Python or external runtimes**.

## Features

- Move and control the mouse
- Perform mouse clicks and drags
- Send keyboard input and shortcuts
- Capture screenshots and locate images on the screen
- Works on Windows, macOS, and Linux

## Installation

1. Add the dependency:
```yaml
dependencies:
  dart_autogui: ^1.0.0
```

2. **Setup Native Library**:
   This package relies on a native shared library that must be built for your system.
   Run the setup script to compile it (requires `cmake` and a C++ compiler):
   
   ```bash
   dart run dart_autogui:setup
   ```

## Usage

```dart
import 'package:dart_autogui/dart_autogui.dart';

void main() async {
  // Move mouse
  await Mouse.moveTo(100, 100);
  
  // Type text
  await Keyboard.typeWrite('Hello World');
}
```

## Requirements
- **macOS**: Xcode Command Line Tools.
- **Linux**: `libx11-dev`, `libxtst-dev`, `cmake`, `build-essential`.
- **Windows**: Visual Studio (C++) or MinGW, `cmake`.
