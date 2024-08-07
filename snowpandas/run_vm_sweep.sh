#!/usr/bin/env bash

for instance_type in "m5d.2xlarge" "m5d.4xlarge" "m5d.12xlarge" "m5d.24xlarge"; do
# for instance_type in "m5d.xlarge"; do
  ./deploy.sh 1 ${instance_type}
  ./run_experiments.sh 0 ${instance_type} "yes"
  echo "qqq" | ./terminate.sh
done