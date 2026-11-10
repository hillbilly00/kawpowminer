cmake_policy(SET CMP0015 NEW)

aux_source_directory(. SRC_LIST)

include_directories(BEFORE ..)

set(EXECUTABLE kawpowminer)

file(GLOB HEADERS "*.h")

add_executable(${EXECUTABLE} ${SRC_LIST} ${HEADERS})
if(MSVC)
	target_sources(${EXECUTABLE} PRIVATE kawpowminer.rc)
endif()

# CLI11 is used as a single header (v1.9.x) placed in deps/include/CLI/CLI.hpp
# Hunter / find_package disabled for modern Ubuntu builds without Hunter.
# hunter_add_package(CLI11)
# find_package(CLI11 CONFIG REQUIRED)
include_directories(${CMAKE_SOURCE_DIR}/deps/include)

target_link_libraries(kawpowminer PRIVATE ethcore poolprotocols devcore kawpowminer-buildinfo Boost::filesystem Boost::system)

if(ETHDBUS)
	find_package(PkgConfig)
	set( ENV{PKG_CONFIG_PATH} "$ENV{PKG_CONFIG_PATH}:/usr/lib/x86_64-linux-gnu/pkgconfig" )
	pkg_check_modules(DBUS dbus-1)
	include_directories(${DBUS_INCLUDE_DIRS})
	link_directories(${DBUS_LIBRARY_DIRS})
	target_link_libraries(kawpowminer PRIVATE ${DBUS_LIBRARIES})
endif()

if(APICORE)
	target_link_libraries(kawpowminer PRIVATE apicore)
endif()

include(GNUInstallDirs)
install(TARGETS kawpowminer DESTINATION ${CMAKE_INSTALL_BINDIR})
if(MSVC)
    install(FILES $<TARGET_PDB_FILE:kawpowminer> DESTINATION ${CMAKE_INSTALL_BINDIR} OPTIONAL)
endif()
