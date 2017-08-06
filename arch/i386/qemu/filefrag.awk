BEGIN {
  FS = "(:|\\.\\.)? +"
  lasttag = ""
}
END {
  printf lasttag
}
{
  gsub("^ *", "", $0)
  if (tolower($0) ~ "^file size of") {		# compute block count of file
    bsize = $(NF - 1)				# block size in bytes
    fsize = $(NF - 5)				# file size in bytes
    bcount = int((fsize + bsize - 1) / bsize)
    if (bcount > BLKSIZE / 4) {
      print "Too long loader file!" > "/dev/stderr"
      exit 1
    }
    if (bcount <= BLKSIZE / 4 - 1) {		# close tag (if need)
      lasttag = "\\x00\\x00\\x00\\x00"
    }
  }
  else if ($0 ~ "^[0-9]+:" && bcount > 0) {	# processing lines

    lbastart = int($4) + RELPOS			# position on disk (LBA)
    lbaend = int($5) + RELPOS
    for (i = lbastart; i <= lbaend && bcount > 0; i ++) {
      printf "\\x%02x\\x%02x\\x%02x\\x%02x", and(i, 0xff),
        and(rshift(i, 8), 0xff), and(rshift(i, 16), 0xff),
        and(rshift(i, 24), 0xff)
      bcount --
    }
  }
}
