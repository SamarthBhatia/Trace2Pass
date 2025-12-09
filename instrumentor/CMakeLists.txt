cmake_minimum_required(VERSION 3.20)
project(Trace2Pass-Instrumentor)

# Find LLVM
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

# Add LLVM definitions and include directories
include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/include)
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_definitions(${LLVM_DEFINITIONS_LIST})

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build HelloPass as a shared library (LLVM pass plugin)
add_library(HelloPass MODULE src/HelloPass.cpp)

# Link against LLVM libraries
target_link_libraries(HelloPass LLVM)

# Don't add 'lib' prefix to the output
set_target_properties(HelloPass PROPERTIES PREFIX "")

# Build Trace2Pass instrumentation framework
add_library(Trace2PassLib STATIC
    src/PassInstrumentor.cpp
)

target_include_directories(Trace2PassLib PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(Trace2PassLib LLVM)

# Enable PIC for linking into shared libraries (required on Linux)
set_target_properties(Trace2PassLib PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Build InstrumentedInstCombine pass plugin
add_library(InstrumentedInstCombine MODULE
    src/InstrumentedInstCombinePass.cpp
)

target_include_directories(InstrumentedInstCombine PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(InstrumentedInstCombine Trace2PassLib LLVM)
set_target_properties(InstrumentedInstCombine PROPERTIES PREFIX "")

# Build InstrumentedGVN pass plugin
add_library(InstrumentedGVN MODULE
    src/InstrumentedGVNPass.cpp
)

target_include_directories(InstrumentedGVN PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(InstrumentedGVN Trace2PassLib LLVM)
set_target_properties(InstrumentedGVN PROPERTIES PREFIX "")

# Build InstrumentedDSE pass plugin
add_library(InstrumentedDSE MODULE
    src/InstrumentedDSEPass.cpp
)

target_include_directories(InstrumentedDSE PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(InstrumentedDSE Trace2PassLib LLVM)
set_target_properties(InstrumentedDSE PROPERTIES PREFIX "")

# Build InstrumentedLICM pass plugin
add_library(InstrumentedLICM MODULE
    src/InstrumentedLICMPass.cpp
)

target_include_directories(InstrumentedLICM PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(InstrumentedLICM Trace2PassLib LLVM)
set_target_properties(InstrumentedLICM PROPERTIES PREFIX "")

# Build standalone test runner
add_executable(test_runner test_runner.cpp)

# Get proper LLVM libraries for the test runner
llvm_map_components_to_libnames(llvm_libs support core irreader passes)
target_link_libraries(test_runner ${llvm_libs})
