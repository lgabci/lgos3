cmake_minimum_required(VERSION 2.6)

function(AssureOutOfSourceBuilds)
  get_filename_component(srcdir ${CMAKE_SOURCE_DIR} REALPATH)
  get_filename_component(bindir ${CMAKE_BINARY_DIR} REALPATH)

  if(${srcdir} STREQUAL ${bindir})
    message("#####################################")
    message("You are attempting to build in your source dir.")
    message("You must run CMake from a build directory.")
    message("#####################################")

    file(REMOVE_RECURSE "${SMAKE_SOURCE_DIR}/CMakeCahce.txt" "${SMAKE_SOURCE_DIR}/CMakeFiles")

    message(FATAL_ERROR "In-source builds are forbidden.")
  endif()

    if(EXISTS ${SMAKE_SOURCE_DIR}/CMakeCahce.txt OR EXISTS ${SMAKE_SOURCE_DIR}/CMakeFiles)
    message("#####################################")
    message("Found results from an in-source build in your source dir.")
    message("#####################################")

    file(REMOVE_RECURSE "${SMAKE_SOURCE_DIR}/CMakeCahce.txt" "${SMAKE_SOURCE_DIR}/CMakeFiles")

    message(FATAL_ERROR "Source directory cleaned, please re-run CMake.")
  endif()
endfunction()

AssureOutOfSourceBuilds()
project(lgos3)
