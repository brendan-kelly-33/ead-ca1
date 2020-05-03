#!/bin/bash

# Author: Brendan Kelly X00159345
# This script calls the three test scripts in order to fully automate the running of each one

if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

bash average_response_times.sh $1
bash async_variable_response_times.sh $1
bash average_recovery_times.sh $1