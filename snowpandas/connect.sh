#!/usr/bin/env bash

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Get the parameters
NUM_INSTANCES=${1:-1}
INSTANCE_TYPE=${2:-"m5d.16xlarge"}
PORT_OFFSET=${3:-0}  # Useful when running multiple clusters in parallel

# Load common functions
. "$SCRIPT_PATH/../common/ec2-helpers.sh"


experiments_dir="$SCRIPT_PATH/../experiments/snowpandas"
deploy_dir="$(discover_cluster "$experiments_dir")"
dnsname="$(discover_dnsnames "$deploy_dir")"


sudo ssh -i $PATH_TO_PRIVATE_KEY ec2-user@$dnsname

#Here we can implement all kind of logic
