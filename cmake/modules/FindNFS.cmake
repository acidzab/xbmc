#.rst:
# FindNFS
# -------
# Finds the libnfs library
#
# This will define the following target:
#
#   ${APP_NAME_LC}::NFS   - The libnfs library

if(NOT TARGET ${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME})

  macro(buildlibnfs)
    set(CMAKE_ARGS -DBUILD_SHARED_LIBS=OFF
                   -DENABLE_TESTS=OFF
                   -DENABLE_DOCUMENTATION=OFF
                   -DENABLE_UTILS=OFF
                   -DENABLE_EXAMPLES=OFF)

    if(WIN32 OR WINDOWS_STORE)
      set(${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_C_FLAGS "/sdl-")
      set(${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_CXX_FLAGS "/sdl-")
    endif()

    BUILD_DEP_TARGET()

    set(_nfs_definitions HAS_NFS_SET_TIMEOUT
                         HAS_NFS_MOUNT_GETEXPORTS_TIMEOUT)
  endmacro()

  include(cmake/scripts/common/ModuleHelpers.cmake)

  set(${CMAKE_FIND_PACKAGE_NAME}_MODULE_LC libnfs)

  SETUP_BUILD_VARS()

  # Search for cmake config. Suitable for all platforms including windows
  find_package(libnfs CONFIG QUIET
                             HINTS ${DEPENDS_PATH}/lib/cmake
                             ${${CORE_PLATFORM_NAME_LC}_SEARCH_CONFIG})

  # Check for existing LIBNFS. If version >= LIBNFS-VERSION file version, dont build
  # A corner case, but if a linux/freebsd user WANTS to build internal libnfs, build anyway
  if((libnfs_VERSION VERSION_LESS ${${${CMAKE_FIND_PACKAGE_NAME}_MODULE}_VER} AND ENABLE_INTERNAL_NFS) OR
     ((CORE_SYSTEM_NAME STREQUAL linux OR CORE_SYSTEM_NAME STREQUAL freebsd) AND ENABLE_INTERNAL_NFS))
    # Build lib
    buildlibnfs()
  else()
    if(TARGET libnfs::nfs)
      # This is for the case where a distro provides a non standard (Debug/Release) config type
      # convert this back to either DEBUG/RELEASE or just RELEASE
      # we only do this because we use find_package_handle_standard_args for config time output
      # and it isnt capable of handling TARGETS, so we have to extract the info
      get_target_property(_LIBNFS_CONFIGURATIONS libnfs::nfs IMPORTED_CONFIGURATIONS)
      foreach(_libnfs_config IN LISTS _LIBNFS_CONFIGURATIONS)
        # Just set to RELEASE var so select_library_configurations can continue to work its magic
        string(TOUPPER ${_libnfs_config} _libnfs_config_UPPER)
        if((NOT ${_libnfs_config_UPPER} STREQUAL "RELEASE") AND
           (NOT ${_libnfs_config_UPPER} STREQUAL "DEBUG"))
          get_target_property(LIBNFS_LIBRARY_RELEASE libnfs::nfs IMPORTED_LOCATION_${_libnfs_config_UPPER})
        else()
          get_target_property(LIBNFS_LIBRARY_${_libnfs_config_UPPER} libnfs::nfs IMPORTED_LOCATION_${_libnfs_config_UPPER})
        endif()
      endforeach()

      # libnfs cmake config doesnt include INTERFACE_INCLUDE_DIRECTORIES
      find_path(LIBNFS_INCLUDE_DIR NAMES nfsc/libnfs.h
                                   HINTS ${DEPENDS_PATH}/include
                                   ${${CORE_PLATFORM_LC}_SEARCH_CONFIG})
    else()
      find_package(PkgConfig QUIET)
      # Try pkgconfig based search as last resort
      if(PKG_CONFIG_FOUND AND NOT (WIN32 OR WINDOWS_STORE))
        if(NFS_FIND_VERSION)
          if(NFS_FIND_VERSION_EXACT)
            set(NFS_FIND_SPEC "=${NFS_FIND_VERSION_COMPLETE}")
          else()
            set(NFS_FIND_SPEC ">=${NFS_FIND_VERSION_COMPLETE}")
          endif()
        endif()

        pkg_check_modules(PC_LIBNFS libnfs${NFS_FIND_SPEC} QUIET)
      endif()

      find_library(LIBNFS_LIBRARY_RELEASE NAMES nfs libnfs
                                          HINTS ${DEPENDS_PATH}/lib
                                                ${PC_LIBNFS_LIBDIR}
                                          ${${CORE_PLATFORM_NAME_LC}_SEARCH_CONFIG})
      find_path(LIBNFS_INCLUDE_DIR nfsc/libnfs.h HINTS ${PC_LIBNFS_INCLUDEDIR}
                                                       ${DEPENDS_PATH}/include
                                                       ${${CORE_PLATFORM_NAME_LC}_SEARCH_CONFIG})
      set(LIBNFS_VERSION ${PC_LIBNFS_VERSION})
    endif()
  endif()

  include(SelectLibraryConfigurations)
  select_library_configurations(LIBNFS)

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(NFS
                                    REQUIRED_VARS LIBNFS_LIBRARY LIBNFS_INCLUDE_DIR
                                    VERSION_VAR LIBNFS_VERSION)

  if(NFS_FOUND)
    # Pre existing lib, so we can run checks
    if(NOT TARGET libnfs)
      set(CMAKE_REQUIRED_INCLUDES "${LIBNFS_INCLUDE_DIR}")
      set(CMAKE_REQUIRED_LIBRARIES ${LIBNFS_LIBRARY})

      # Check for nfs_set_timeout
      check_cxx_source_compiles("
         ${LIBNFS_CXX_INCLUDE}
         #include <nfsc/libnfs.h>
         int main()
         {
           nfs_set_timeout(NULL, 0);
         }
      " NFS_SET_TIMEOUT)

      if(NFS_SET_TIMEOUT)
        list(APPEND _nfs_definitions HAS_NFS_SET_TIMEOUT)
      endif()

      # Check for mount_getexports_timeout
      check_cxx_source_compiles("
         ${LIBNFS_CXX_INCLUDE}
         #include <nfsc/libnfs.h>
         int main()
         {
           mount_getexports_timeout(NULL, 0);
         }
      " NFS_MOUNT_GETEXPORTS_TIMEOUT)

      if(NFS_MOUNT_GETEXPORTS_TIMEOUT)
        list(APPEND _nfs_definitions HAS_NFS_MOUNT_GETEXPORTS_TIMEOUT)
      endif()

      unset(CMAKE_REQUIRED_INCLUDES)
      unset(CMAKE_REQUIRED_LIBRARIES)
    endif()

    list(APPEND _nfs_definitions HAS_FILESYSTEM_NFS)

    # cmake target and not building internal
    if(TARGET libnfs::nfs AND NOT TARGET libnfs)
      add_library(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} ALIAS libnfs::nfs)
    else()

      add_library(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} UNKNOWN IMPORTED)
      set_target_properties(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} PROPERTIES
                                                                       IMPORTED_LOCATION "${LIBNFS_LIBRARY}")
    endif()

    # Test if target is an alias. We cant set properties on alias targets, and must find
    # the actual target.
    get_property(aliased_target TARGET "${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME}" PROPERTY ALIASED_TARGET)
    if("${aliased_target}" STREQUAL "")
      set(_nfs_target "${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME}")
    else()
      set(_nfs_target "${aliased_target}")
    endif()

    # We need to append in case the cmake config already has definitions
    set_property(TARGET ${_nfs_target} APPEND PROPERTY
                                              INTERFACE_COMPILE_DEFINITIONS ${_nfs_definitions})

    # Need to manually set this, as libnfs cmake config does not provide INTERFACE_INCLUDE_DIRECTORIES
    set_target_properties(${_nfs_target} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES ${LIBNFS_INCLUDE_DIR})

    if(TARGET libnfs)
      add_dependencies(${APP_NAME_LC}::${CMAKE_FIND_PACKAGE_NAME} libnfs)
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
      if(NOT TARGET libnfs)
        buildlibnfs()
        set_target_properties(libnfs PROPERTIES EXCLUDE_FROM_ALL TRUE)
      endif()
      add_dependencies(build_internal_depends libnfs)
    endif()
  endif()
endif()
