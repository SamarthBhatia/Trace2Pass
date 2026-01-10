cmake_minimum_required(VERSION 3.20)
project(Trace2Pass-Runtime C)

# Set C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Include directories
include_directories(include)

# Build runtime library as static library
add_library(Trace2PassRuntime STATIC
    src/trace2pass_runtime.c
)

# Link pthread for mutex support and dl for dladdr()
# ${CMAKE_DL_LIBS} is libdl on Linux, empty on macOS (where dladdr is in libc)
target_link_libraries(Trace2PassRuntime pthread ${CMAKE_DL_LIBS})

# Enable PIC for linking into shared objects
set_target_properties(Trace2PassRuntime PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Install headers
install(FILES include/trace2pass_runtime.h
        DESTINATION include)

# Install library
install(TARGETS Trace2PassRuntime
        ARCHIVE DESTINATION lib)

# Build test executable
add_executable(test_runtime test/test_runtime.c)
target_link_libraries(test_runtime Trace2PassRuntime pthread ${CMAKE_DL_LIBS})
