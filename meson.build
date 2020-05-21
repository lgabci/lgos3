# LGOS3 top meson file

project('lgos3', 'c',
        meson_version: '>=0.49.2',
        version: '0.0.1'
       )

assert(meson.is_cross_build(), 'Only cross build enabled!')

objcopy = find_program('objcopy')

subdir('arch')
