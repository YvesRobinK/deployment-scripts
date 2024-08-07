#!/usr/bin/env bash

SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Get the parameters
NUM_INSTANCES=${1:-1}
INSTANCE_TYPE=${2:-"m5d.16xlarge"}
PORT_OFFSET=${3:-0}  # Useful when running multiple clusters in parallel

# Load common functions
. "$SCRIPT_PATH/../common/ec2-helpers.sh"

# Deploy cluster
experiments_dir="$SCRIPT_PATH/../experiments/snowpandas"
mkdir -p "$experiments_dir"

deploy_cluster "$experiments_dir" $NUM_INSTANCES $INSTANCE_TYPE
deploy_dir="$(discover_cluster "$experiments_dir")"
dnsname="$(discover_dnsnames "$deploy_dir")"

SECONDS=0

# Deploy and start Rumble
echo "Deploying software..."
(
    echo "Executed"
    ssh -q ec2-user@$dnsname -o StrictHostKeyChecking=accept-new true
    
    ssh -q ec2-user@$dnsname \
        <<-EOF
        sudo yum -y install pip
		EOF
	ssh -q ec2-user@$dnsname \
        <<-EOF
        wget -q https://repo.anaconda.com/archive/Anaconda3-2024.02-1-Linux-x86_64.sh
        bash Anaconda3-2024.02-1-Linux-x86_64.sh -b
        echo 'export PATH=~/anaconda3/bin:\$PATH' >> ~/.bashrc
        source ~/.bashrc
        conda init
		EOF
	ssh -q ec2-user@$dnsname \
        <<-EOF
        wget -q https://sfc-repo.snowflakecomputing.com/snowsql/bootstrap/1.3/linux_x86_64/snowflake-snowsql-1.3.1-1.x86_64.rpm
        sudo rpm -i https://sfc-repo.snowflakecomputing.com/snowsql/bootstrap/1.3/linux_x86_64/snowflake-snowsql-1.3.1-1.x86_64.rpm
        mkdir /home/ec2-user/.snowsql
		EOF
		
	scp ../snowflake-config.txt ec2-user@$dnsname:~/.snowsql/config
	
	ssh -q ec2-user@$dnsname \
        <<-EOF
        sudo ls -ld /usr/lib64/snowflake/snowsql
        sudo ls -ld /usr/lib64/snowflake/snowsql/*
        sudo chmod -R 755 /usr/lib64/snowflake/snowsql
		EOF
		
	ssh -q ec2-user@$dnsname \
        <<-EOF
        sudo yum -y install git
        git clone https://$GIT_USERNAME:$GIT_TOKEN@github.com/YvesRobinK/experiments
		EOF
		
	ssh -q ec2-user@$dnsname \
        <<-EOF
		aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID --profile $AWS_PROFILE
        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY --profile $AWS_PROFILE
        aws configure set region $AWS_DEFAULT_REGION --profile $AWS_PROFILE
        aws configure set output $AWS_OUTPUT_FORMAT --profile $AWS_PROFILE
		EOF
		
	ssh -q ec2-user@$dnsname \
        <<-EOF
        git clone https://$GIT_USERNAME:$GIT_TOKEN@github.com/intel-ai/hdk.git
        cd hdk
        conda env create -f omniscidb/scripts/mapd-deps-conda-dev-env.yml
        conda activate omnisci-dev
        mkdir build && cd build
        cmake ..
        make -j 
        make install
		EOF
		
	ssh -q ec2-user@$dnsname \
        <<-EOF
        git clone https://$GIT_USERNAME:$GIT_TOKEN@github.com/YvesRobinK/modin
        conda activate omnisci-dev
        pip install modin
        pip install /home/ec2-user/modin
		EOF
	
	scp ../common/credentials.json ec2-user@$dnsname:~/experiments/credentials.json
	
	ssh -q ec2-user@$dnsname \
        <<-EOF
        conda env create --file /home/ec2-user/experiments/requirements/pandas_req.yml
        conda env create --file /home/ec2-user/experiments/requirements/modin_req.yml
        conda env create --file /home/ec2-user/experiments/requirements/spark_req.yml
        conda env create --file /home/ec2-user/experiments/requirements/polars_req.yml
        conda env create --file /home/ec2-user/experiments/requirements/snowpark_pandas_req.yml
        conda env create --file /home/ec2-user/experiments/requirements/vaex_req.yml
		EOF
		
	ssh -q ec2-user@$dnsname \
        <<-EOF
        export PYTHONPATH=$PYTHONPATH:/home/ec2-user/experiments
        echo 'export PYTHONPATH=$PYTHONPATH:/home/ec2-user/experiments' >> ~/.bashrc

		EOF
		
	ssh -q ec2-user@$dnsname \
        <<-EOF
        sudo yum install java-1.8.0-openjdk -y
        bash /home/ec2-user/experiments/requirements/snowpandas_setup.sh
        bash /home/ec2-user/experiments/requirements/vaex_setup.sh
		EOF
	
) &> "$deploy_dir/deploy_$dnsname.log"
echo "Done."
duration=$SECONDS
echo "$((duration / 60)) minutes and $((duration % 60)) seconds elapsed during sorfware deployment."

sudo ssh -i /home/yves/Desktop/experiments-scripts-master/experiments/new-ohio-key.pem ec2-user@$dnsname
yes

# Set up SSH tunnel to head node
#for p in 4040 8001 18080
#do  
#	ssh -L $(( ${p} + ${PORT_OFFSET} )):localhost:${p} -N -q hadoop@$dnsname &
#	tunnelpid=$!
#	echo "$tunnelpid" >> "$deploy_dir/tunnel.pid"
#done
