#!/bin/bash
set -xe

PROJECT="linkedlist"
ASMFILES=$(find . -type f -name "*.asm")
ASM=nasm
ASMFLAGS="-g -felf64"
LINK=gcc
LINKFLAGS="-no-pie"

for file in $ASMFILES; do
  $ASM $ASMFLAGS $file
done

$LINK $LINKFLAGS -o $PROJECT $(find -type f -name "*.o")
rm *.o