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
#set(CMAKE_SYSTEM_PROCESSOR i686)
#set(CMAKE_CROSSCOMPILING 1)

message(STATUS "1")
set(CMAKE_C_COMPILER "i686-lgos-gcc")
message(STATUS "2")
#set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffreestanding -nostdlib -nostdinc -O2 -pedantic -Werror -Wall -Wextra")
#set(CMAKE_C_COMPILER_WORKS 1)



message(STATUS "3")
project(lgos3 C ASM)
message(STATUS "4")
message(STATUS "${CMAKE_CURRENT_SOURCE_DIR}")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffreestanding -nostdlib -nostdinc -O2 -pedantic -Werror -Wall -Wextra")
#set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -Wa,-I,${CMAKE_CURRENT_LIST_DIR}")
set(CMAKE_ASM_FLAGS "${CMAKE_ASM_FLAGS} -Wa,-I,/home/gabci/lgos3/arch/i386/loader/loader -Wa,-I,/home/gabci/lgos3/arch/i386/kernel")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-T,/home/gabci/lgos3/arch/i386/kernel/kernel.ld")
set(CMAKE_STATIC_FLAGS "${CMAKE_STATIC_FLAGS} -Wl,-T,/home/gabci/lgos3/arch/i386/kernel/kernel.ld")

#add_executable(kernel.elf "")
add_subdirectory(arch/i386/kernel)
add_subdirectory(arch/i386/loader)
