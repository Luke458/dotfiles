cmake_minimum_required(VERSION 3.20)
project(quickshell_pinentry VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(gpg_error REQUIRED IMPORTED_TARGET gpg-error)
find_package(Qt6 6.6 REQUIRED COMPONENTS Core Network Qml)

qt_standard_project_setup(REQUIRES 6.6)

set(PINENTRY_MODULE_URI "Luke.Quickshell.Pinentry")
set(PINENTRY_MODULE_DIR "${CMAKE_BINARY_DIR}/qml/Luke/Quickshell/Pinentry")
set(PINENTRY_SHARED_SOURCES
    src/protocol.cpp
)

qt_add_library(quickshell_pinentry SHARED
    ${PINENTRY_SHARED_SOURCES}
    src/pinentryserver.cpp
    src/pinentryserver.hpp
)

# Keep the QML backing library beside the generated extension plugin. This makes
# the build tree directly loadable through QML2_IMPORT_PATH.
set_target_properties(quickshell_pinentry PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${PINENTRY_MODULE_DIR}"
    BUILD_RPATH "$ORIGIN"
    INSTALL_RPATH "$ORIGIN"
)

qt_add_qml_module(quickshell_pinentry
    URI ${PINENTRY_MODULE_URI}
    VERSION 1.0
    OUTPUT_DIRECTORY "${PINENTRY_MODULE_DIR}"
    SOURCES
        src/pinentryserver.hpp
)

target_link_libraries(quickshell_pinentry PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Qml
)
target_include_directories(quickshell_pinentry PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
)

qt_query_qml_module(quickshell_pinentry
    PLUGIN_TARGET pinentry_plugin_target
    TARGET_PATH pinentry_module_target_path
    QMLDIR pinentry_module_qmldir
    TYPEINFO pinentry_module_typeinfo
)
set_target_properties(${pinentry_plugin_target} PROPERTIES
    BUILD_RPATH "$ORIGIN"
    INSTALL_RPATH "$ORIGIN"
)

qt_add_executable(pinentry-quickshell
    ${PINENTRY_SHARED_SOURCES}
    src/main.cpp
)
target_link_libraries(pinentry-quickshell PRIVATE
    Qt6::Core
    Qt6::Network
    PkgConfig::gpg_error
)

include(GNUInstallDirs)
set(PINENTRY_QML_INSTALL_DIR "${CMAKE_INSTALL_DATADIR}/qml/${pinentry_module_target_path}")
install(TARGETS quickshell_pinentry ${pinentry_plugin_target}
    LIBRARY DESTINATION "${PINENTRY_QML_INSTALL_DIR}"
    RUNTIME DESTINATION "${PINENTRY_QML_INSTALL_DIR}"
)
install(FILES ${pinentry_module_qmldir} ${pinentry_module_typeinfo}
    DESTINATION "${PINENTRY_QML_INSTALL_DIR}"
)
install(TARGETS pinentry-quickshell
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
)
