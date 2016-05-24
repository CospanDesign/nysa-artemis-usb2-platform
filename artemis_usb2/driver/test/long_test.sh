#! /bin/bash

for i in {0..10000}
  do
    ./build/pcie_tester
    echo "$i"
  done
