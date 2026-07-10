cmake_minimum_required(VERSION 3.10)

project(dart_autogui)

set(CMAKE_CXX_STANDARD 14)

# Define source files for each platform
if (APPLE)
    enable_language(OBJCXX)
    # ScreenCaptureKit exists from macOS 12.3; SCScreenshotManager (used by
    # dag_capture_screen) is gated at runtime to macOS 14+.
    if (NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "" FORCE)
    endif()
    set(SOURCES src/native/macos/autogui.mm)
    # ARC so the ScreenCaptureKit objects manage themselves.
    set_source_files_properties(src/native/macos/autogui.mm
        PROPERTIES COMPILE_FLAGS "-fobjc-arc")
    find_library(COREGRAPHICS CoreGraphics)
    find_library(APPLICATIONSERVICES ApplicationServices)
    find_library(SCREENCAPTUREKIT ScreenCaptureKit)
    set(LIBS ${COREGRAPHICS} ${APPLICATIONSERVICES} ${SCREENCAPTUREKIT})
elseif (UNIX AND NOT APPLE) # Linux
    set(SOURCES src/native/linux/autogui.c)
    find_package(X11 REQUIRED)
    find_library(XTEST_LIB Xtst REQUIRED)
    set(LIBS ${X11_LIBRARIES} ${XTEST_LIB})
elseif (WIN32)
    set(SOURCES src/native/windows/autogui.cpp)
    # gdi32: BitBlt / CreateCompatibleDC / GetDIBits for dag_capture_screen
    set(LIBS user32 gdi32)
endif()

add_library(dart_autogui SHARED ${SOURCES})

target_link_libraries(dart_autogui ${LIBS})

# Set output directory to where Dart expects it usually, or just build/
# For local dev, users might want to copy it or we set output directly
# set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/build/lib)
