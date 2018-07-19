# LGOS3 kernel makefile

add_executable(kernel.elf init.s initc.c descript.c paging.c)
#target_sources(kernel.elf PRIVATE "${CMAKE_CURRENT_LIST_DIR}/init.s" "${CMAKE_CURRENT_LIST_DIR}/initc.c" "${CMAKE_CURRENT_LIST_DIR}/descript.c" "${CMAKE_CURRENT_LIST_DIR}/paging.c")
