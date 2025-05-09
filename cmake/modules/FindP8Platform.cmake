# FindP8Platform
# -------
# Finds the P8-Platform library
#
# This will define the following target:
#
#   ${APP_NAME_LC}::P8Platform   - The P8-Platform library

# If find_package REQUIRED, check again to make sure any potential versions
# supplied in the call match what we can find/build
if(NOT TARGET ${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} OR P8Platform_FIND_REQUIRED)
  include(cmake/scripts/common/ModuleHelpers.cmake)

  macro(buildlibp8platform)
    set(patches "${CORE_SOURCE_DIR}/tools/depends/target/${${CMAKE_FIND_PACKAGE_NAME}_MODULE_LC}/001-all-fix-c++17-support.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${${CMAKE_FIND_PACKAGE_NAME}_MODULE_LC}/002-all-fixcmakeinstall.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${${CMAKE_FIND_PACKAGE_NAME}_MODULE_LC}/003-all-cmake_tweakversion.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${${CMAKE_FIND_PACKAGE_NAME}_MODULE_LC}/004-all-fix-cxx-standard.patch")

    generate_patchcommand("${patches}")

    set(CMAKE_ARGS -DBUILD_SHARED_LIBS=OFF)

    # p8-platform hasnt tagged a release since 2016. Force this for cmake 4.0
    # p8-platform master has updated cmake minimum to 3.12, so if they ever tag a new release
    # this can be dropped.
    list(APPEND CMAKE_ARGS -DCMAKE_POLICY_VERSION_MINIMUM=3.10)

    # CMAKE_INSTALL_LIBDIR in p8-platform prepends project prefix, so disable sending any
    # install_libdir to generator
    set(${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_INSTALL_LIBDIR "/lib")

    set(BUILD_NAME build-p8-platform)

    BUILD_DEP_TARGET()

    set(P8-PLATFORM_VERSION ${${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_VER})
  endmacro()

  set(${CMAKE_FIND_PACKAGE_NAME}_MODULE_LC p8-platform)
  SETUP_BUILD_VARS()

  # Search cmake-config. Suitable all platforms
  find_package(p8-platform CONFIG
                           HINTS ${DEPENDS_PATH}/lib/cmake
                           ${${CORE_PLATFORM_LC}_SEARCH_CONFIG})

  if(p8-platform_VERSION VERSION_LESS ${${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_VER})
    # build p8-platform lib
    buildlibp8platform()
  else()
    # p8-platform cmake config is terrible for modern cmake. For now just use pkgconfig
    # and manual find_* 
    find_package(PkgConfig QUIET)
    # Do not use pkgconfig on windows
    if(PKG_CONFIG_FOUND AND NOT WIN32)
      pkg_check_modules(PC_P8PLATFORM p8-platform QUIET)
      set(P8-PLATFORM_VERSION ${PC_P8PLATFORM_VERSION})
    else()
      set(P8-PLATFORM_VERSION ${p8-platform_VERSION})
    endif()

    # Hack: kodi uses a tweak version. Along with p8platform cmake config/pkgconfig
    # returns versions without patch. Just skip for now
    set(P8Platform_FIND_VERSION "2.1")
    find_library(P8-PLATFORM_LIBRARY NAMES p8-platform
                                     HINTS ${DEPENDS_PATH}/lib ${PC_P8PLATFORM_LIBDIR}
                                     ${${CORE_PLATFORM_LC}_SEARCH_CONFIG})
    find_path(P8-PLATFORM_INCLUDE_DIR NAMES p8-platform/os.h
                                      HINTS ${DEPENDS_PATH}/include ${PC_P8PLATFORM_INCLUDEDIR}
                                      ${${CORE_PLATFORM_LC}_SEARCH_CONFIG})
  endif()

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(P8Platform
                                    REQUIRED_VARS P8-PLATFORM_LIBRARY P8-PLATFORM_INCLUDE_DIR
                                    VERSION_VAR P8-PLATFORM_VERSION)

  if(P8PLATFORM_FOUND)
    add_library(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} UNKNOWN IMPORTED)
    set_target_properties(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} PROPERTIES
                                                                     IMPORTED_LOCATION "${P8-PLATFORM_LIBRARY}"
                                                                     INTERFACE_INCLUDE_DIRECTORIES "${P8-PLATFORM_INCLUDE_DIR}")

    if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
      set_target_properties(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} PROPERTIES
                                                                       INTERFACE_LINK_LIBRARIES "-framework CoreVideo")
    endif()

    if(TARGET build-p8-platform)
      add_dependencies(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} build-p8-platform)
      # If the build target exists here, set LIB_BUILD property to allow calling modules
      # know that this will be rebuilt, and they will need to rebuild as well
      set_target_properties(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} PROPERTIES LIB_BUILD ON)
    endif()

    # Add internal build target when a Multi Config Generator is used
    # We cant add a dependency based off a generator expression for targeted build types,
    # https://gitlab.kitware.com/cmake/cmake/-/issues/19467
    # therefore if the find heuristics only find the library, we add the internal build
    # target to the project to allow user to manually trigger for any build type they need
    # in case only a specific build type is actually available (eg Release found, Debug Required)
    # This is mainly targeted for windows who required different runtime libs for different
    # types, and they arent compatible
    if(_multiconfig_generator)
      if(NOT TARGET build-p8-platform)
        buildlibp8platform()
        set_target_properties(build-p8-platform PROPERTIES EXCLUDE_FROM_ALL TRUE)
      endif()
      add_dependencies(build_internal_depends build-p8-platform)
    endif()
  else()
    if(P8Platform_FIND_REQUIRED)
      message(FATAL_ERROR "P8-PLATFORM not found.")
    endif()
  endif()
endif()
