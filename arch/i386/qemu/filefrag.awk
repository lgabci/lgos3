function printbin(value, len) {
  if (FORMAT == 1) {
    printf "%d", value
  }
  else {
    for (i = 0; i < len; i ++) {
      printf "\\\\x%02x", value % 256
      value = int(value / 256)
    }
  }
}

function printpairs(db, pos) {
  if (db > 0) {
    if (SECSIZE == 0) {				# serial values
      for (j = 0; j < db; j ++) {
        printbin(pos + j, plen)
        printf "\n"
      }
    }
    else {					# count and pos values
      if (outpos < clean + plen + plen) {	# at the end of sector?
        printbin(0, outpos)
        printf "\n"
        outpos = SECSIZE
      }
      printbin(db, clen)
      printbin(pos, plen)
      printf "\n"
      outpos = outpos - clen - plen
    }
  }
}

BEGIN {
  plen = 8					# length of pos in bytes
  clen = 2					# length of len in bytes

  pos = 0					# position in input (LBA)
  db = 0					# length in input
  bcount = 0					# remaining block counter

  SECSIZE = 0					# set from parameters
	# if SECSIZE is empty then the output is a list of block numbers,
	# else count and block number pairs
  RELPOS = 0
  FORMAT = 0

  firstline = 0
  ffragerr = 0
  lastpos = 0
}

{
  if (tolower($0) ~ "^file size of") {		# compute block count of file
    bsize = $(NF - 1)				# block size in bytes
    fsize = $(NF - 5)				# file size in bytes
    bcount = int((fsize + bsize - 1) / bsize)

    outpos = SECSIZE	# position of the output in a BLOCKSIZE bytes len block
  }
  else if ($1 ~ "[0-9]+:" && bcount > 0) {	# processing lines
    if (firstline == 0) {			# filefrag error
      gsub("\\.+", "", $2)
      ffragerr = int($2)
      firstline ++
    }

    gsub("\\.+", "", $4)			# position on disk (LBA)
    gsub(":", "", $6)				# block count at this position
    locpos = int($4) + RELPOS
    locdb = int($6)

    if (locdb > bcount) {			# on last block it may be less
      locdb = bcount
    }

    if (int($4) != lastpos) {			# filefrag error
      locpos = locpos - ffragerr
    }

    if (pos + db == locpos) {			# consecutive blocks
      db = db + locdb
    }
    else {					# non consecutive blocks
      printpairs(db, pos)			# print db and pos pair
      pos = locpos
      db = locdb
    }
    bcount = bcount - locdb			# remaining block number

    gsub(":", "", $5)				# last position
    lastpos = int($5)
  }
}

END {
  printpairs(db, pos)				# last count and pos pair

  if (SECSIZE != 0) {
    if (outpos < clean + plen + plen) {		# at the end of sector?
      llen = outpos
    }
    else {
      llen = clen
    }
    printbin(0, llen)				# trailing zero
    printf "\n"
  }
}
