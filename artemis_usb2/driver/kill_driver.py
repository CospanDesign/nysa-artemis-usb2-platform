#! /bin/bash

echo "Kill the module"
echo 1 > /sys/class/nysa_pcie/nysa_pcie0/unlock_driver
echo 1 > /sys/class/nysa_pcie/nysa_pcie0/reset_fpga

