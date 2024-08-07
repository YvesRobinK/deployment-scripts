SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if ! [ -f "$SOURCE_DIR/config.sh" ]
then
    echo "Config file config.sh not found. You probably forgot to add a config.sh file to your common folder. See README for more details." >&2
    exit 1
else
    . "$SOURCE_DIR/config.sh"
fi

function discover_instanceids {
    trap 'echo "Error!"; exit 1' ERR
    deploy_dir=$1
    cat "$deploy_dir/run-instances.json" | jq -r ".Instances[].InstanceId"
}

function discover_dnsnames {
    trap 'echo "Error!"; exit 1' ERR
    deploy_dir=$1
    cat "$deploy_dir/describe-instances.json" | jq -r ".Reservations[].Instances[].PublicDnsName"
}


function discover_privatednsnames {
    trap 'echo "Error!"; exit 1' ERR
    deploy_dir=$1
    cat "$deploy_dir/describe-instances.json" | jq -r ".Reservations[].Instances[].PrivateDnsName"
}

function discover_privateips {
    trap 'echo "Error!"; exit 1' ERR
    deploy_dir=$1
    cat "$deploy_dir/describe-instances.json" | jq -r ".Reservations[].Instances[].PrivateIpAddress"
}

function discover_cluster {
    trap 'echo "Error!"; exit 1' ERR
    experiments_dir=$1
    ls -d "$experiments_dir"/deploy_* | sort | tail -n1
}

function deploy_cluster {
    trap 'echo "Error!"; exit 1' ERR
    experiments_dir=$1
    num_instances=$2
    instance_type=$3


    # Directory for logging
    [ -d "$experiments_dir" ]
    deploy_dir="${experiments_dir}/deploy_$(date +%F-%H-%M-%S)"
    mkdir -p "$deploy_dir"
    echo "$deploy_dir"
    # Find image ID in this region
    #image_name="amzn2-ami-hvm-2.0.20200722.0-x86_64-gp2"
    image_name="amzn2-ami-hvm-2.0.20240719.0-x86_64-gp2"
    echo $image_name
    image_id="$(aws ec2 describe-images \
                    --owners amazon \
                    --region "us-east-2" \
                    --filters "Name=name,Values=$image_name" "Name=state,Values=available" \
                    --query "Images[0].ImageId" --output text)"
                    
    MY_IP=$(curl -s http://checkip.amazonaws.com)
    SECURITY_GROUP_NAME="MySecurityGroup"
    DESCRIPTION="Security group for SSH access from a specific IP"
    echo $DESCRIPTION
    # Check if the security group already exists
    GROUP_ID=$(aws ec2 describe-security-groups --filters Name=group-name,Values="$SECURITY_GROUP_NAME" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

    echo $DESCRIPTION
    # If the security group exists, delete it
    if [ "$GROUP_ID" != "None" ]; then
        echo "Security group '$SECURITY_GROUP_NAME' exists. Deleting..."
        aws ec2 delete-security-group --group-id "$GROUP_ID"
        echo "Deleted existing security group: $SECURITY_GROUP_NAME"
    fi
    echo $DESCRIPTION
    # Create a new security group
    echo "Creating security group: $SECURITY_GROUP_NAME"
    NEW_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "$DESCRIPTION" --query "GroupId" --output text)

    # Add a rule to allow SSH from the current IP
    aws ec2 authorize-security-group-ingress --group-name MySecurityGroup --protocol tcp --port 22 --cidr ${MY_IP}/32

    # Start instances
    aws ec2 run-instances \
        --count $num_instances \
        --instance-type $instance_type \
        --iam-instance-profile Name="$INSTANCE_PROFILE" \
        --image-id "$image_id" \
        --key-name $SSH_KEY_NAME \
        --region "us-east-2" \
        --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":32}}]' \
        --security-groups MySecurityGroup \
        > "$deploy_dir/run-instances.json"

    instanceids=($(discover_instanceids "$deploy_dir"))
    echo "Running instances: ${instanceids[*]}."

    # Wait until they are running
    while [[ "$(aws ec2 describe-instances --instance-id ${instanceids[*]} | jq -r ".Reservations[].Instances[].State.Name" | sort -u )" != "running" ]]
    do
        echo "Waiting for them to run..."
        echo "$(aws ec2 describe-instances --instance-id ${instanceids[*]} | jq -r ".Reservations[].Instances[].State.Name" | sort -u )"
        echo ${instanceids}
        sleep 1s
    done
    echo "All running."

    # Retrieve metadata
    aws ec2 describe-instances --instance-id ${instanceids[*]} \
        > "$deploy_dir/describe-instances.json"
    dnsnames=($(discover_dnsnames "$deploy_dir"))
    privatednsnames=($(discover_privatednsnames "$deploy_dir"))
    privateips=($(discover_privateips "$deploy_dir"))

    # Print node information
    echo "Nodes:"
    (
        echo "  Node ID;Instance ID;Public DNS name;Private DNS name;Private IP"
        for (( i=0; i<${#instanceids[@]}; i++ ))
        do
            echo "  $i;${instanceids[$i]};${dnsnames[$i]};${privatednsnames[$i]};${privateips[$i]}"
        done
    ) | column -t -s";"

    # Deploy software on machines
    echo "Deploying common software..."
    echo $dnsnames
    for dnsname in ${dnsnames[*]}
    do
        (
            echo "before ssh"
            (
                # Wait for SSH to come up
                while [[ "$(ssh -q -o  ConnectTimeout=2 -o StrictHostKeyChecking=accept-new ec2-user@$dnsname whoami)" != "ec2-user" ]]
                do  
                    echo "$(ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=accept-new ec2-user@$dnsname whoami)"
                    echo "Waiting for SSH to come up..."
                    sleep 3s
                done
                echo "before ssh"
                ssh -q ec2-user@$dnsname \
                    <<-'EOF'
				# Set up external disk
				devices="$(sudo lsblk | sed -n 's~^\(nvme[^0][^ ]*\).*$~/dev/\1~p')"
				sudo mdadm --create --verbose /dev/md0 --level=0 --name=data --raid-devices=$(echo "$devices" | wc -l) --force $devices
				sudo mkfs.ext4 -L data /dev/md0
				sudo mkdir /data
				sudo mount LABEL=data /data
				sudo chown $USER:$USER /data
				
			    
				
				# Sane ulimits
				echo -e "* soft nofile 16384\n* hard nofile 16384" | sudo tee /etc/security/limits.d/99-nfiles.conf
				EOF
            ) &> "$deploy_dir/deploy_$dnsname.log"
            echo "Done deploying $dnsname."
        ) &
        sleep .1
    done
    wait
    echo "Done deploying common software."
}

function terminate_cluster {
    trap 'echo "Error!"; exit 1' ERR

    deploy_dir=$1

    # Find instances
    instanceids=($(discover_instanceids "$deploy_dir"))
    dnsnames=($(discover_dnsnames "$deploy_dir"))
    echo "Found instances: ${instanceids[*]}."


    # Shut them down
    for (( i=0; i<${#instanceids[@]}; i++ ))
    do
        (
            state="$(aws ec2 describe-instances --instance-id ${instanceids[$i]} | jq -r ".Reservations[].Instances[].State.Name")"
            echo "Stopping node $i (instance ID: ${instanceids[$i]}, current state: $state)..."
            aws ec2 terminate-instances --instance-id ${instanceids[$i]} > /dev/null
        ) &
        sleep .1
    done
    wait
    echo "Done"
}
