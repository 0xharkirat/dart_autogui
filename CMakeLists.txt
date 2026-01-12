cmake_minimum_required(VERSION 3.10)

project(dart_autogui)

set(CMAKE_CXX_STANDARD 14)

# Define source files for each platform
if (APPLE)
    enable_language(OBJCXX)
    set(SOURCES src/native/macos/autogui.mm)
    find_library(COREGRAPHICS CoreGraphics)
    find_library(APPLICATIONSERVICES ApplicationServices)
    set(LIBS ${COREGRAPHICS} ${APPLICATIONSERVICES})
elseif (UNIX AND NOT APPLE) # Linux
    set(SOURCES src/native/linux/autogui.c)
    find_package(X11 REQUIRED)
    find_library(XTEST_LIB Xtst REQUIRED)
    set(LIBS ${X11_LIBRARIES} ${XTEST_LIB})
elseif (WIN32)
    set(SOURCES src/native/windows/autogui.cpp)
    set(LIBS user32)
endif()

add_library(dart_autogui SHARED ${SOURCES})

target_link_libraries(dart_autogui ${LIBS})

# Set output directory to where Dart expects it usually, or just build/
# For local dev, users might want to copy it or we set output directly
# set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/build/lib)
