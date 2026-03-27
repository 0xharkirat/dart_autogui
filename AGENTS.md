# AGENTS.md

This file is the working guide for future AI-assisted development in this
repository. It is intentionally practical: it explains what exists, what is
broken, what is only documented, and how to change the code without creating
more drift between Dart, FFI, native code, tests, and docs.

## Repo Purpose

`autogui` is a Dart package that aims to provide cross-platform desktop GUI
automation through FFI bindings to native implementations on macOS, Linux, and
Windows.

The package is currently closer to an early prototype than a finished
cross-platform library. Treat the current code as a functional skeleton with
real platform glue, not as a stable or complete API.

## Current Reality

As of 2026-03-27:

- `dart analyze` passes.
- `dart test` passes.
- The tests are mock-driven and do not validate native loading or real desktop
  automation behavior.
- macOS has the most complete implementation.
- Linux and Windows now expose the keyboard symbols the Dart FFI layer expects.
- Keyboard support exists on all three desktop backends, but text entry remains
  basic and layout-sensitive.
- The setup script, CMake target name, and runtime loader names are aligned.
- `MouseButton` is exported from the public package barrel.
- The README has been corrected to match the current API and limitations more
  closely, but should still be verified whenever behavior changes.

Do not assume "tests pass" means the package works end-to-end on all platforms.

## High-Level Architecture

The package has five layers:

1. Public Dart API in `lib/autogui.dart`
2. Keyboard-specific Dart API in `lib/src/keyboard.dart`
3. Platform abstraction and singleton wiring in `lib/src/platform.dart`
4. Per-platform FFI bindings in `lib/src/ffi/*.dart`
5. Per-platform native code in `src/native/*`

There is also a build/setup layer:

- `CMakeLists.txt`
- `bin/setup.dart`

And a lightweight validation/documentation layer:

- `test/*`
- `example/*`
- `README.md`
- `CHANGELOG.md`

## File Walkthrough

### `lib/autogui.dart`

This is the main package barrel and the main user-facing API surface.

It currently provides:

- easing helpers (`easeLinear`, `easeInQuad`, etc.)
- `Screen`
- `Mouse`

Important details:

- `Screen.size()` delegates to `platformMouse.screenSize()`.
- `Screen.onScreen()` is a simple bounds check against the primary screen.
- `Mouse.moveTo()` performs tweening in Dart and calls
  `platformMouse.moveToAbsolute()` for each step.
- `Mouse.dragTo()` is implemented as `mouseDown -> moveTo -> mouseUp`.
- `Mouse.click()` and scroll helpers optionally call `moveTo()` first.

Important caveats:

- `autogui.dart` imports `src/platform.dart` but only exports
  `src/keyboard.dart`.
- `Mouse` methods expose `MouseButton` in their signatures, but `MouseButton`
  is not exported from the public barrel.
- `Mouse.click()`, `Mouse.scroll()`, and `Mouse.hscroll()` call `moveTo()`
  without awaiting it. For zero-duration moves this is fine; for future
  non-zero-duration call sites this can create ordering surprises.

### `lib/src/keyboard.dart`

This file defines:

- `AutoGUIKey`
- `Keyboard`

Behavior:

- `Keyboard.press()` does `keyDown`, optional delay, then `keyUp`.
- `Keyboard.typeWrite()` iterates characters and calls `_typeChar()`.
- `_typeChar()` asks the platform keyboard mapper for a keycode and emits a
  simple down/up pair.

Important caveats:

- `_getKeyCode()` only accepts `int` and `AutoGUIKey`.
- The README currently documents `Keyboard.press('a')`, but that does not work.
- Uppercase and symbol handling are incomplete; there is no generic Shift
  synthesis.
- Unsupported characters are silently dropped instead of throwing.

### `lib/src/platform.dart`

This is the central abstraction layer.

It defines:

- `MouseButton`
- `PlatformMouse`
- `PlatformKeyboard`
- `_MacMouse`, `_LinuxMouse`, `_WindowsMouse`
- `_MacKeyboard`, `_LinuxKeyboard`, `_WindowsKeyboard`
- lazy singleton getters `platformMouse` and `platformKeyboard`
- test override setters `platformMouseInstance` and `platformKeyboardInstance`

This file is the most important integration point in the repo.

Important behavior:

- Public APIs in `lib/autogui.dart` and `lib/src/keyboard.dart` eventually flow
  through these singleton getters.
- Tests replace these singletons with mocks.
- The platform implementations are thin wrappers over FFI bindings.

Important caveats:

- Linux and Windows mouse classes depend on FFI binding objects that currently
  carry optional keyboard hooks so mouse usage is insulated from partial
  keyboard work or future symbol drift.
- macOS key mapping is a hardcoded partial map.
- Linux key mapping depends on `dag_keysym_to_keycode`, which is not currently
  robust for every keyboard layout.
- Windows key mapping assumes virtual key behavior and remains basic.

### `lib/src/ffi/macos.dart`

Loads `libdart_autogui.dylib` and looks up:

- mouse position
- move
- mouse down/up/click
- vertical/horizontal scroll
- screen size
- accessibility permission status
- keyboard down/up

This is the only platform where the required native symbols currently exist for
both mouse and keyboard.

### `lib/src/ffi/linux.dart`

Attempts to load `libdart_autogui.so` and eagerly resolve:

- mouse symbols
- accessibility symbol
- `dag_key_down`
- `dag_key_up`
- `dag_keysym_to_keycode`

Important caveat:

- Linux mouse symbols are required and loaded eagerly.
- Linux keyboard symbols are also implemented now, but higher-level text entry
  remains limited by key mapping and layout assumptions.

### `lib/src/ffi/windows.dart`

Attempts to load `dart_autogui.dll` and eagerly resolve:

- mouse symbols
- accessibility symbol
- `dag_key_down`
- `dag_key_up`

Important caveat:

- Windows mouse symbols are required and loaded eagerly.
- Windows keyboard symbols are also implemented now, but higher-level text
  entry remains limited by key mapping and layout assumptions.

### `src/native/macos/autogui.mm`

Uses CoreGraphics/ApplicationServices to implement:

- screen size
- mouse position
- mouse move
- mouse down/up/click
- vertical/horizontal scroll
- accessibility trust
- keyboard down/up

Important caveat:

- `dag_move_mouse()` always posts `kCGEventMouseMoved`.
- Dragging in Dart is implemented by holding a button and repeatedly calling
  this move function, so macOS drag gestures may not be recognized correctly by
  all applications. Proper drag event types may be needed.

### `src/native/linux/autogui.c`

Uses X11/XTest to implement:

- screen size
- mouse position
- absolute move
- mouse down/up/click
- vertical/horizontal scroll
- accessibility/trust-like display check

Important caveat:

- No keyboard functions are exported yet.

### `src/native/windows/autogui.cpp`

Uses Win32 `SendInput` and `GetSystemMetrics` to implement:

- screen size
- mouse position
- absolute move
- mouse down/up/click
- vertical/horizontal scroll
- a trivial trust check

Important caveat:

- No keyboard functions are exported yet.

### `CMakeLists.txt`

Builds a shared library target named `dart_autogui`.

That target name matters. It determines the expected library filenames:

- macOS: `libdart_autogui.dylib`
- Linux: `libdart_autogui.so`
- Windows: `dart_autogui.dll`

Any code that builds, copies, loads, or documents library artifacts must stay
consistent with this target name.

### `bin/setup.dart`

This is meant to be the user-facing native build helper.

Current behavior:

- creates `build/`
- runs `cmake ..`
- runs `cmake --build .`
- searches for built artifacts
- copies the result to the package root

Important note:

- The script now uses the same `dart_autogui` artifact names that CMake
  produces and the FFI loaders expect.
- A future agent must keep setup script names, CMake output names, and FFI
  runtime loader names aligned.

### `test/*`

Tests are intentionally shallow and mock-based.

They currently validate:

- easing helpers
- `Mouse` method delegation to the mock platform layer
- `Keyboard` method delegation to the mock platform layer

They do not validate:

- native library loading
- symbol lookup success
- actual keyboard/mouse desktop behavior
- setup/build flow
- platform-specific key mapping correctness
- documentation accuracy

The mock override seam is:

- `platformMouseInstance`
- `platformKeyboardInstance`

That seam is useful and should be preserved.

### `example/*`

Examples serve as manual smoke tests more than polished samples.

- `example/autogui_example.dart` demonstrates mouse movement, double click,
  scroll, and position printing.
- `example/keyboard_example.dart` demonstrates typing and Enter presses.

Important caveat:

- Example success depends on platform permissions and on native behavior that is
  not covered by tests.
- The keyboard example currently exercises text that includes uppercase and
  punctuation, which the package does not robustly support across platforms.

### `README.md` and `CHANGELOG.md`

These files currently overstate maturity.

Specific drift:

- README has been corrected for current API names and limitations.
- CHANGELOG language should still be reviewed before a real release because
  Linux and Windows keyboard support remain incomplete.

Future agents must treat docs as potentially stale and verify against code.

## What Is Actually Validated Today

Validated:

- the package analyzes cleanly
- the mock injection seams work
- public Dart methods roughly delegate to platform abstractions
- easing helpers return expected sample values

Not validated:

- native compilation on all platforms
- setup script correctness
- runtime symbol loading on Linux and Windows
- real drag behavior on macOS
- correctness of keycode mappings
- examples as runnable end-to-end demos

## Critical Invariants

When editing this repo, preserve these invariants:

1. The CMake target name, setup artifact names, and FFI loader names must match.
2. If a Dart FFI binding eagerly looks up a symbol, every supported native
   backend must export that symbol or the binding must be split/lazily resolved.
3. Publicly documented API types must be exported from the public barrel.
4. If a method is documented in README, verify the symbol name and signature in
   code before changing docs or examples.
5. Mock-based unit tests are not enough for native changes. Native work should
   be paired with at least one platform smoke test plan.

## Known Problems To Keep In View

Priority order for future work:

1. Decide whether `Keyboard.press()` should support `String`, and either
   implement it or remove the claim from docs.
2. Improve layout-aware text entry and shifted/symbol character support across
   macOS, Linux, and Windows.
3. Add at least one native integration smoke test path or documented manual test
   procedure per platform.
4. Review README and CHANGELOG again once keyboard support changes land.

## Phase 1 Plan

Phase 1 is the "make the package credible and safe to build on all claimed
desktop platforms" milestone. It is not feature expansion. The goal is to
remove runtime blockers, align packaging, and make the documented surface match
the code.

Phase 1 scope:

1. Restore Linux backend usability.
2. Restore Windows backend usability.
3. Fix setup/build artifact naming and loader alignment.
4. Fix public API export drift.
5. Fix documentation and example drift.
6. Fix macOS drag event semantics.
7. Add minimal validation that covers the repaired paths.

Recommended execution order:

### Milestone 1: Unblock Linux mouse loading

Files:

- `lib/src/ffi/linux.dart`
- `lib/src/platform.dart`
- optionally `src/native/linux/autogui.c`

Target:

- Linux mouse APIs must load even if Linux keyboard support remains incomplete.

Preferred approach:

- split mouse and keyboard symbol loading so missing keyboard symbols do not
  break mouse initialization

Alternative approach:

- implement the missing Linux keyboard symbols now if the scope is controlled

Exit criteria:

- `platformMouse` on Linux can initialize without unresolved keyboard symbols
- design is explicit about whether Linux keyboard is supported, stubbed, or
  deferred

### Milestone 2: Unblock Windows mouse loading

Files:

- `lib/src/ffi/windows.dart`
- `lib/src/platform.dart`
- optionally `src/native/windows/autogui.cpp`

Target:

- Windows mouse APIs must load even if keyboard support is not fully shipped in
  the same step.

Preferred approach:

- split mouse and keyboard symbol loading as done for Linux

Alternative approach:

- implement native Windows keyboard symbols if the work is small and testable

Exit criteria:

- `platformMouse` on Windows can initialize without unresolved keyboard symbols

### Milestone 3: Fix build/setup naming alignment

Files:

- `bin/setup.dart`
- `CMakeLists.txt`
- `lib/src/ffi/macos.dart`
- `lib/src/ffi/linux.dart`
- `lib/src/ffi/windows.dart`

Target:

- CMake output names, setup artifact discovery, copied filenames, and runtime
  loader names must all match.

Exit criteria:

- one canonical library name per platform
- setup script copies the same artifact names the FFI layer loads
- README setup instructions remain accurate

### Milestone 4: Clean the public API surface

Files:

- `lib/autogui.dart`
- `README.md`
- tests that validate public imports if added

Target:

- public types used by public method signatures must be exported from the
  barrel

Exit criteria:

- consumers using `package:autogui/autogui.dart` can reference `MouseButton`

### Milestone 5: Bring docs and examples back to reality

Files:

- `README.md`
- `example/autogui_example.dart`
- `example/keyboard_example.dart`
- optionally `CHANGELOG.md`

Target:

- no documented feature should be missing from the code
- examples should avoid unsupported keyboard cases unless that support is
  implemented in the same phase

Exit criteria:

- README reflects the actual API names and current support level
- examples are runnable against the current implementation assumptions

### Milestone 6: Fix macOS drag semantics

Files:

- `src/native/macos/autogui.mm`
- possibly `lib/src/platform.dart` if the API needs state-aware movement

Target:

- drag operations on macOS should emit dragged events, not plain move events,
  while a mouse button is held

Exit criteria:

- macOS drag behavior is intentionally implemented and documented

### Milestone 7: Add minimum validation coverage

Files:

- `test/*`
- optionally a lightweight smoke-test doc section in `README.md` or this file

Target:

- Phase 1 changes should not rely only on existing mock tests

Recommended minimum:

- keep unit tests for Dart delegation
- add tests around public exports and documented behavior where practical
- document manual smoke tests for macOS, Linux, and Windows backend loading

Exit criteria:

- every Phase 1 milestone has either automated coverage or a documented manual
  smoke-test procedure

Definition of done for Phase 1:

- Linux mouse backend loads
- Windows mouse backend loads
- setup script and loaders agree on artifact names
- public API export drift is removed
- README/examples no longer promise unsupported behavior
- macOS drag path is corrected or explicitly constrained in docs
- validation instructions exist for all repaired paths

## Git Branch SOP

Use branch-based development for all non-trivial work. Do not develop Phase 1
fixes directly on `main`.

Branch naming:

- use `codex/<short-topic>` by default
- examples:
  - `codex/linux-loader-fix`
  - `codex/setup-name-alignment`
  - `codex/phase1-doc-sync`

Standard operating procedure:

1. Start from an up-to-date `main`.
2. Create a focused branch for one milestone or tightly related change set.
3. Make changes across all affected layers in the same branch.
4. Run validation before staging.
5. Stage intentionally.
6. Commit with a message that describes the outcome, not just the file names.
7. Push the branch.
8. Open a PR with validation notes and any remaining platform caveats.

Suggested command flow:

```bash
git checkout main
git pull --ff-only
git checkout -b codex/<topic>

dart analyze
dart test

git add <files>
git commit -m "<type>: <summary>"
git push -u origin codex/<topic>
```

Branch scope rules:

- prefer one branch per milestone
- if a fix touches multiple layers for one bug, keep it in one branch
- if two fixes can be reviewed independently, split them into separate branches
- do not mix feature expansion with Phase 1 stabilization in the same branch

PR checklist:

- summarize the user-visible problem
- list the files changed by layer: public API, platform abstraction, FFI,
  native, docs, tests
- include `dart analyze` and `dart test` results
- include manual smoke-test notes for any native/platform-specific behavior
- call out any platform that remains partially implemented

Commit guidance:

- use small, reviewable commits when a milestone is large
- avoid "catch-all" commits that combine loader fixes, docs cleanup, and new
  features unless they are inseparable
- if README/examples changed because code changed, keep them in the same branch
  and usually the same PR

Agent-specific rules:

- before editing, check the current branch with `git status --short --branch`
- if you are on `main` and the work is non-trivial, create a branch first
- do not rewrite or delete user changes on the branch
- do not merge `main` into feature branches unless necessary; prefer rebasing or
  recreating the branch when appropriate
- before handing off, report branch name, validation run, and any uncommitted
  changes

Current branch note:

- This file should not be treated as the source of truth for the active git
  branch.
- Always check the live branch with `git status --short --branch`.

## Recommended Workflow For Future Agents

When starting work:

- read `AGENTS.md` first
- read the specific files you plan to change
- compare README claims against code before assuming behavior
- run `dart analyze`
- run `dart test`

When changing public API:

- update `lib/autogui.dart`
- update any affected `src` files
- update README examples and signatures
- update tests

When changing native functionality:

- update the relevant native source file
- update the matching FFI binding file
- verify symbol names exactly match
- check whether `CMakeLists.txt` needs new libraries or sources
- check whether `bin/setup.dart` needs artifact path updates
- document how the behavior should be smoke tested on the target OS

When changing docs:

- verify against code, not intention
- avoid advertising features that do not exist in the current tree
- call out platform limitations explicitly

## Suggested Validation Commands

Run from the package root:

```bash
dart analyze
dart test
```

For manual smoke testing on macOS:

```bash
dart run example/autogui_example.dart
dart run example/keyboard_example.dart
```

For native build/setup validation:

```bash
dart run bin/setup.dart
```

Use manual examples cautiously because they can move the mouse and type into the
active application.

## Release Hygiene

Before cutting a real release, a future agent should verify all of the
following:

- setup script produces a loadable library on each claimed platform
- runtime loading succeeds on each claimed platform
- README does not promise unsupported features
- examples only use supported API and supported character cases
- changelog language matches actual platform support
- versioning reflects the real maturity of the package

## Notes For AI Agents

- Prefer small, cross-layer fixes over isolated edits. In this repo, many bugs
  are caused by one layer drifting from another.
- Do not trust the docs over the code.
- Do not trust mock tests as proof of native correctness.
- If you touch platform loading, always inspect `lib/src/platform.dart`,
  `lib/src/ffi/*`, native sources, `CMakeLists.txt`, and `bin/setup.dart`
  together.
- If you make a behavior user-visible, update README and examples in the same
  change.
