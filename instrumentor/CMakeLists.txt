cmake_minimum_required(VERSION 3.20)
project(Trace2Pass-Instrumentor)

# Find LLVM
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

# Add LLVM definitions and include directories
include_directories(${LLVM_INCLUDE_DIRS})
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

# Build standalone test runner
add_executable(test_runner test_runner.cpp)

# Get proper LLVM libraries for the test runner
llvm_map_components_to_libnames(llvm_libs support core irreader passes)
target_link_libraries(test_runner ${llvm_libs})
