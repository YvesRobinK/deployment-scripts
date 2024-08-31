## Prerequisites

### config.sh
Please update the following fields:

* `SSH_KEY_NAME`: The name of the AWS key used to access S3 and EC2, see [here](#SSH_KEY_NAME) for more details.
* `INSTANCE_PROFILE`: This is a role in your aws account. To create a new one,
    1. goto aws IAM
    2. goto roles
    3. create new role
    4. select AWS service
    5. select EC2 for usecase
    6. set a proper name and finish. Finally set the the name of the role to `INSTANCE_PROFILE`
* `GIT_USERNAME`: set your github username.
* `GIT_TOKEN`: your github token. You can create one at /settings/developer settings on github.
* `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`: This is the access key for your user. To create a new one,
    1. goto aws IAM
    2. goto users
    3. select your user
    4. goto security credentials
    5. create a new access key
* `PATH_TO_PRIVATE_KEY`: this is the path to your SSH private key.
* `PATH_TO_CONFIGFILE`: this is the path to the `credentials.json` file of the `experiment` repository.

### credentials.json
Please make a copy of the `credentials.json` file of your `experiment` repository and put it in the `common` folder. You can also find a template for it at `credentials_template.json`.

### snowflake-config.txt
Please make a copy of the config file of your snowflake into the base folder (`deployment-scripts`). Usually this file can be found at `~/.snowsql`. Your config should include your account name, username, password, and the connection name.

### Software installed locally

* The [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).
* [Docker](https://docs.docker.com/engine/install/).
* Python 3 with `pip`. The systems using Python come with their own
  `requirements.txt`, which you probably want to install into dedicated
  [virtual environments](https://docs.python.org/3/library/venv.html).
* `jq`, `make`

### AWS

#### `SSH_KEY_NAME`

The scripts assume that running `ssh some-ec2instance` works without user
intervention, so you should use your default SSH key in AWS. To do that, follow
[this guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#how-to-generate-your-own-key-and-import-it-to-aws) to create a key pair.
The name that you choose during the key import is the one you need to store in `SSH_KEY_NAME`.

To make a keypair as your default SSH key do the followings:
- `cd ~/.ssh`
- `touch config`
- in `config` file put this line: `IdentityFile /path/to/keypair.pem`
- `chmod 400 /path/to/keypair.pem`

#### Setting user permissions
In order to run the deploy script, your user must have certain permissions. For this, first create a new policy using the below json:
```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Resource": "*",
			"Action": [
				"cloudwatch:*",
				"dynamodb:*",
				"ec2:Describe*",
				"elasticmapreduce:Describe*",
				"elasticmapreduce:ListBootstrapActions",
				"elasticmapreduce:ListClusters",
				"elasticmapreduce:ListInstanceGroups",
				"elasticmapreduce:ListInstances",
				"elasticmapreduce:ListSteps",
				"kinesis:CreateStream",
				"kinesis:DeleteStream",
				"kinesis:DescribeStream",
				"kinesis:GetRecords",
				"kinesis:GetShardIterator",
				"kinesis:MergeShards",
				"kinesis:PutRecord",
				"kinesis:SplitShard",
				"rds:Describe*",
				"s3:*",
				"sdb:*",
				"sns:*",
				"sqs:*",
				"glue:CreateDatabase",
				"glue:UpdateDatabase",
				"glue:DeleteDatabase",
				"glue:GetDatabase",
				"glue:GetDatabases",
				"glue:CreateTable",
				"glue:UpdateTable",
				"glue:DeleteTable",
				"glue:GetTable",
				"glue:GetTables",
				"glue:GetTableVersions",
				"glue:CreatePartition",
				"glue:BatchCreatePartition",
				"glue:UpdatePartition",
				"glue:DeletePartition",
				"glue:BatchDeletePartition",
				"glue:GetPartition",
				"glue:GetPartitions",
				"glue:BatchGetPartition",
				"glue:CreateUserDefinedFunction",
				"glue:UpdateUserDefinedFunction",
				"glue:DeleteUserDefinedFunction",
				"glue:GetUserDefinedFunction",
				"glue:GetUserDefinedFunctions",
				"ec2:CreateSecurityGroup",
				"ec2:AuthorizeSecurityGroupIngress",
				"ec2:DeleteSecurityGroup",
				"iam:ListInstanceProfiles",
				"iam:PassRole",
				"ec2:RunInstances",
				"ec2:TerminateInstances"
			]
		}
	]
}
```
Then add this policy to the permissions of your user.

## Enabling SSH on EC2
EC2 instances are launched using the default security group. Either adapt your default AWS security group to accept SSH connections from your device/IP, or create your own security group and adapt the script to attach to the deployed instance. For the later, you can uncomment and adapt `ec2-helper.sh` between lines 64-86.

## Deploying an insance
Go to `snowpandas` folder. At line 7, set the `INSTANCE_TYPE` to the proper machine type (e.g. `m5d.8xlarge`, `m5d.16xlarge`, etc.). Then run `./deploy.sh`. Once this command is finished, you can use `./connect.sh` to connect to the created instance. when your experiments are finished, make sure to terminate the instance with `./terminate.sh` script.

Note: instead of using `./termiante.sh` and `./connect.sh`, you can also manually terminate your instance, and SSH into the instance through the AWS web console, respectively.
