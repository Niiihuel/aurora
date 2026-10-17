cmake_minimum_required(VERSION 3.27)
project(aurora-rims DESCRIPTION "Liquid glass rims on every window (Hyprland plugin)" VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(GNUInstallDirs)
find_package(PkgConfig REQUIRED)
pkg_check_modules(hyprland REQUIRED IMPORTED_TARGET hyprland)

add_library(aurora-rims MODULE src/main.cpp src/Rim.cpp)
target_link_libraries(aurora-rims PRIVATE PkgConfig::hyprland)
target_compile_options(aurora-rims PRIVATE -Wall -Wextra -Wno-narrowing -Wno-unused-parameter)
install(TARGETS aurora-rims LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})
