# LGOS3 loader/bootblock file

bootblock_mbr = executable('bootblock_mbr.elf',
                           'bootblock_mbr.s',
                           c_args: [ '-Wa,-I,' + meson.current_source_dir()
                                   ],
                           link_args: [ '-T',
                                        meson.current_source_dir() + '/bootblock_mbr.ld'
                                      ]
                          )

bootblock_ext2 = executable('bootblock_ext2.elf',
                           'bootblock_ext2.s',
                           c_args: [ '-Wa,-I,' + meson.current_source_dir()
                                   ],
                           link_args: [ '-T',
                                        meson.current_source_dir() + '/bootblock_ext2.ld'
                                      ]
                          )

bootblock_fat = executable('bootblock_fat.elf',
                           'bootblock_fat.s',
                           c_args: [ '-Wa,-I,' + meson.current_source_dir()
                                   ],
                           link_args: [ '-T',
                                        meson.current_source_dir() + '/bootblock_fat.ld'
                                      ]
                          )
