# i386 loader makefile include

PHONY: loader
loader: bootblock

$(call make_include,bootblock/makefile.mk loader/makefile.mk)
