#!/usr/bin/env bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. "$SOURCE_DIR/../common/emr-helpers.sh"

# Get the parameters
PORT_OFFSET=${1:-0}  # Useful when running multiple clusters in parallel
instance=${2:-""}  
running_vm_sweeps=${3:-"no"}  # Can also be 'yes'

INPUT_TABLE_FORMAT="s3://hep-adl-ethz/hep-parquet/native/Run2012B_SingleMu-%i.parquet"
INPUT_TABLE_FORMAT_SF="s3://hep-adl-ethz/hep-parquet/native-sf/%i/*.parquet"
NUM_RUNS=3

experiments_dir="$SOURCE_DIR/../experiments/pyspark"
deploy_dir="$(discover_cluster "$experiments_dir")"
dnsname="$(discover_dnsname "$deploy_dir")"
query_cmd="ssh ec2-user@${dnsname} -q"

stat_port=$(( 18080 + ${PORT_OFFSET} ))

# Create result dir
experiment_dir="$experiments_dir/experiment_$(date +%F-%H-%M-%S)"
mkdir -p $experiment_dir

function run_one {(
	trap 'exit 1' ERR

	num_events=$1
	query_id=$2
	run_num=$3
	warmup=$4

	input_table="$(printf $INPUT_TABLE_FORMAT $num_events)"
	if [ "$num_events" -gt "65536000" ]; then 
		input_table="$(printf $INPUT_TABLE_FORMAT_SF $(( $num_events / 65536000 )))"
	fi

	run_dir="$experiment_dir/run_$(date +%F-%H-%M-%S.%3N)"
	mkdir $run_dir

	tee "$run_dir/config.json" <<-EOF
		{
			"VM": "${instance}",
			"system": "pyspark",
			"run_dir": "$(basename "$experiment_dir")/$(basename "$run_dir")",
			"num_events": $num_events,
			"input_table": "$input_table",
			"query_id": "$query_id",
			"run_num": $run_num
		}
		EOF

	(
		ssh ec2-user@$dnsname -q "cd queries/query-${query_id} && spark-submit query.py --input_path=${input_table}"
		exit_code=$?
		echo "Exit code: $exit_code"
		echo $exit_code > "$run_dir"/exit_code.log
	) 2>&1 | tee "$run_dir"/run.log
	if [ "$warmup" != "yes" ]; then
		sleep 1
		application_id=$(curl "http://localhost:${stat_port}/api/v1/applications/" | jq -r '[.[]|select(.name=="pyspark-query")][0]["id"]')
		entries=$(curl "http://localhost:${stat_port}/api/v1/applications/${application_id}/jobs" | jq length)
		python3 get_metrics.py ${application_id} ${entries} 0 ${run_dir} --port=${stat_port}
	fi
)}

function run_many() {(
	trap 'exit 1' ERR

	local -n num_events_configs=$1
	local -n query_ids_configs=$2
	local warmup=$3

	for num_events in "${num_events_configs[@]}"
	do
		for query_id in "${query_ids_configs[@]}"
		do
			for run_num in $(seq $NUM_RUNS)
			do
				run_one "$num_events" "$query_id" "$run_num" "$warmup"
			done
		done
	done
)}


# Run the warmups
NUM_EVENTS=($(for l in 0; do echo $((2**$l*1000)); done))
QUERY_IDS=($(for q in 1 2 3 4 5 6 7 8; do echo ${q}; done))
run_many NUM_EVENTS QUERY_IDS yes

if [ "${running_vm_sweeps}" = "no" ]; then
	# Run the experiments until SF16 with all queries
	NUM_EVENTS=($(for l in {0..20}; do echo $((2**$l*1000)); done))
	QUERY_IDS=($(for q in 1 2 3 4 5 6 7 8; do echo ${q}; done))
	run_many NUM_EVENTS QUERY_IDS no

	# Run the rest of the experiments without query 6
	NUM_EVENTS=($(for l in {20..23}; do echo $((2**$l*1000)); done))
	QUERY_IDS=($(for q in 1 2 3 4 5 7 8; do echo ${q}; done))
	run_many NUM_EVENTS QUERY_IDS no

	# Summarize experiments
	./summarize_experiment.py ${experiment_dir} 
else
	NUM_EVENTS=($(for l in 16; do echo $((2**$l*1000)); done))
	QUERY_IDS=($(for q in 1 2 3 4 5 6 7 8; do echo ${q}; done))
	run_many NUM_EVENTS QUERY_IDS no

	# Summarize experiments
	dir_path=$(./summarize_experiment.py ${experiment_dir} | tail -n 1)
	echo "${instance}: ${dir_path}" >> vm_sweep_paths.log
fi
