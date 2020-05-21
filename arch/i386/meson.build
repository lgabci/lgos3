# LGOS3 i386 meson file

add_project_arguments(['-ffreestanding', '-O2', '-std=gnu99'],
                      language: 'c'
                     )

add_project_link_arguments(['-nostdlib', '-lgcc'],
                           language: 'c'
                          )

subdir('kernel')
subdir('loader')
subdir('emulator')
