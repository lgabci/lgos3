#!/bin/sh
set -e

IMG="$1"
ELF="$2"
OFFSET=$3

if [[ $($AWK --version 2>/dev/null) = GNU* ]]; then
  AWKFLAGS=--non-decimal-data
fi

AWKPROG='/^Idx/,0 {
  if ($1 ~ /[0-9]+/) {
    count = sprintf("%d", "0x" $3);
    seek = sprintf("%d", "0x" $5);
    skip = sprintf("%d", "0x" $6);
    getline;
    if (/ ALLOC/ && / LOAD/) {
      print skip " " seek " " count
    }
  }
}'

$OBJDUMP -h "$ELF"
$OBJDUMP -h "$ELF" |
  $AWK $AWKFLAGS "$AWKPROG" - |
  while read skip seek count; do
    $DD if=$ELF of=$IMG bs=1 skip=$skip seek=$seek count=$count conv=notrunc
  done
