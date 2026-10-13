cmake_minimum_required(VERSION 3.21)

project(AccessSpeech VERSION 1.0.0 LANGUAGES CXX)

# ---- Paths to the SKSE 2.3.1 sources (runtime 1.7.104) and ianpatt's "common" library ----
set(SKSE_ROOT "C:/Users/Josh/SkyrimDev/skse64-2.3.1/skse64-2.3.1" CACHE PATH "skse64 source root (contains skse64/, skse64_common/, xbyak/)")
set(COMMON_ROOT "C:/Program Files (x86)/Steam/steamapps/common/Skyrim Special Edition/src/common" CACHE PATH "directory that contains the common/ folder")

if(NOT EXISTS "${SKSE_ROOT}/skse64/PluginAPI.h")
	message(FATAL_ERROR "SKSE_ROOT does not point at the skse64 sources: ${SKSE_ROOT}")
endif()
if(NOT EXISTS "${COMMON_ROOT}/common/IPrefix.h")
	message(FATAL_ERROR "COMMON_ROOT does not contain common/IPrefix.h: ${COMMON_ROOT}")
endif()

# Static CRT, like SKSE itself.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ---- SKSE sources compiled into the plugin (no game hooks) ----
file(GLOB COMMON_SRC CONFIGURE_DEPENDS "${COMMON_ROOT}/common/*.cpp")
file(GLOB SKSE_COMMON_SRC CONFIGURE_DEPENDS "${SKSE_ROOT}/skse64_common/*.cpp")
# Only the pieces needed to register Papyrus natives; the rest of skse64 depends on its game hooks.
set(SKSE_SRC
	"${SKSE_ROOT}/skse64/PapyrusNativeFunctions.cpp"
	"${SKSE_ROOT}/skse64/PapyrusArgs.cpp"
	"${SKSE_ROOT}/skse64/PapyrusVM.cpp"
	"${SKSE_ROOT}/skse64/PapyrusValue.cpp"
	"${SKSE_ROOT}/skse64/PapyrusInterfaces.cpp"
	"${SKSE_ROOT}/skse64/GameTypes.cpp"
	"${SKSE_ROOT}/skse64/GameAPI.cpp"
	"${SKSE_ROOT}/skse64/GameUtilities.cpp"
	"${SKSE_ROOT}/skse64/GameRTTI.cpp"
)

add_library(${PROJECT_NAME} SHARED
	src/PluginMain.cpp
	src/Speech.cpp
	src/Speech.h
	${COMMON_SRC}
	${SKSE_COMMON_SRC}
	${SKSE_SRC}
)

source_group("skse64" FILES ${SKSE_SRC})
source_group("skse64_common" FILES ${SKSE_COMMON_SRC})
source_group("common" FILES ${COMMON_SRC})

target_include_directories(${PROJECT_NAME} PRIVATE
	"${SKSE_ROOT}"
	"${COMMON_ROOT}"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
	RUNTIME
	RUNTIME_VERSION=0x01070680
	_CRT_SECURE_NO_WARNINGS
	_CRT_NONSTDC_NO_WARNINGS
)

target_compile_options(${PROJECT_NAME} PRIVATE
	/MP
	/W3
	/FI"common/IPrefix.h"
	/permissive
	/Zc:__cplusplus
	/wd4996
	/Zi
)

target_link_options(${PROJECT_NAME} PRIVATE /DEBUG:FULL /OPT:REF /OPT:ICF)

target_link_libraries(${PROJECT_NAME} PRIVATE
	version
	psapi
	dbghelp
	shlwapi
	ole32
	oleaut32
	sapi
	ws2_32
	winmm
)

set_target_properties(${PROJECT_NAME} PROPERTIES
	OUTPUT_NAME "AccessSpeech"
	PREFIX ""
)

# ---- Console smoke test for the speech backend (optional) ----
option(ACCESSSPEECH_BUILD_TEST "Build the SpeechTest console program" ON)
if(ACCESSSPEECH_BUILD_TEST)
	add_executable(SpeechTest tests/SpeechTest.cpp src/Speech.cpp src/Speech.h ${COMMON_SRC})
	target_include_directories(SpeechTest PRIVATE "${COMMON_ROOT}" "${CMAKE_CURRENT_SOURCE_DIR}/src")
	target_compile_definitions(SpeechTest PRIVATE _CRT_SECURE_NO_WARNINGS _CRT_NONSTDC_NO_WARNINGS)
	target_compile_options(SpeechTest PRIVATE /MP /W3 /FI"common/IPrefix.h" /wd4996)
	target_link_libraries(SpeechTest PRIVATE ole32 oleaut32 sapi winmm)
endif()
