target remote localhost:1234
#symbol-file ../loader/loader.elf
set arch i8086
display /5i $cs * 16 + $pc

watch *0x930
