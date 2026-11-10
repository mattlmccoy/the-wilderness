#!/bin/sh
# Runs the package tests with the Command Line Tools' Swift Testing framework
# (works before the Xcode license is accepted).
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
cd "$(dirname "$0")" && exec swift test -Xswiftc -F -Xswiftc $F -Xlinker -F -Xlinker $F \
  -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L "$@"
