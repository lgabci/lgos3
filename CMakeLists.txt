# LGOS3 main cmake file

cmake_minimum_required(VERSION 3.1)

function(AssureOutOfSourceBuilds)
  get_filename_component(srcdir ${CMAKE_SOURCE_DIR} REALPATH)
  get_filename_component(bindir ${CMAKE_BINARY_DIR} REALPATH)

  if(${srcdir} STREQUAL ${bindir})
    message("#####################################")
    message("You are attempting to build in your source dir.")
    message("You must run CMake from a build directory.")
    message("#####################################")

    file(REMOVE_RECURSE "${SMAKE_SOURCE_DIR}/CMakeCahce.txt" "${CMAKE_SOURCE_DIR}/CMakeFiles")

    message(FATAL_ERROR "In-source builds are forbidden.")
  endif()

    if(EXISTS ${CMAKE_SOURCE_DIR}/CMakeCahce.txt OR EXISTS ${CMAKE_SOURCE_DIR}/CMakeFiles/)
    message("#####################################")
    message("Found results from an in-source build in your source dir.")
    message("#####################################")

    file(REMOVE_RECURSE "${CMAKE_SOURCE_DIR}/CMakeCahce.txt" "${CMAKE_SOURCE_DIR}/CMakeFiles")

    message(FATAL_ERROR "Source directory cleaned, please re-run CMake.")
  endif()
endfunction()

AssureOutOfSourceBuilds()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/lgos3-CMakeFiles")

set(CMAKE_SYSTEM_NAME lgos3)

set(CMAKE_SYSTEM_VERSION 0.0.1)
set(CMAKE_SYSTEM_PROCESSOR i386)
#set(CMAKE_CROSSCOMPILING 1)

message(STATUS "1")
set(CMAKE_C_COMPILER "i686-elf-gcc")
message(STATUS "2")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffreestanding -nostdlib -nostdinc -O2 -pedantic -Werror -Wall -Wextra")
#set(CMAKE_C_COMPILER_WORKS 1)



message(STATUS "3")
project(lgos3 C)
message(STATUS "4")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffreestanding -nostdlib -nostdinc -O2 -pedantic -Werror -Wall -Wextra")

#add_executable(kernel.elf "")
add_subdirectory(arch/i386/kernel)
