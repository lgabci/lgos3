# LGOS3 top meson file

project('lgos3', 'c', meson_version: '>=0.49.2', version: '0.0.1')

assert(meson.is_cross_build(), 'Only cross build enabled!')

objcopy = find_program('objcopy')

add_global_arguments ([ '-ffreestanding',
                        '-O2',
                        '-pedantic',
                        '-Werror',
                        '-Wall',
                        '-Wextra'
                      ],
                      language: 'c'
                     )

add_global_link_arguments ([ '-nostdlib',
                             '-lgcc'
                           ],
                           language: 'c'
                          )

subdir('arch')
