function err(msg) {
  print("ELF file error: ", msg)
  exit 1
}

BEGIN {
  lnum = 0
}

/^Program Header:/ {
  found = 1
  next
}

/^$/ {
  found = 0
}

found {
  if (lnum % 2 == 0) {		# LOAD off ... lines
    if ($1 != "LOAD" || $2 != "off" || $4 != "vaddr" || $6 != "paddr" || $8 != "align" || $9 !~ "^2**") {
      err("bad ELF file")
    }
    ioff = strtonum($3)
    ooff = strtonum($5)
    if (ooff != strtonum($7)) {
      err("vaddr != paddr (" $5 " != " $7 ")")
    }
  }
  else {			# filesz ... lines
    if ($1 != "filesz" || $3 != "memsz" || $5 != "flags") {
      err("bad ELF file")
    }
    sz = strtonum($2)

    if (sz > 0) {
      print(ioff " " ooff " " sz)
    }
  }

  lnum ++
}
