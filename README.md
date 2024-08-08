# Experiments

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

## Running experiments

### Typical experiment workflow

The flow for running the experiments is roughly the following:

1. Follow the setup procedure of each system as explained in the respective
   subfolder.
1. For self-managed systems, start the resources on AWS EC2 using `deploy.sh` and set up or upload the data on these resources using `upload.sh` of the respective system.
1. Run queries in one of the following ways:
   * Run individual queries using the `test_queries.py` script or (similar). The `deploy.sh` of the self-managed systems opens a tunnel to the deployed EC2 instances, such that you can use the local script with the cloud resources.
   * Modify and run `run_experiments.sh` to run a batch of queries and trace its results.
1. Terminate the deployed resources with `terminate.sh`.
1. Run `make -f path/to/common/make.mk -C results/results_date-of-experiment/` to parse the trace files and produce `result.json` with the statistics of all runs.

### Running different VM sizes

Self-deployed systems are evaluated in the paper by running the ADL benchmark
queries at a fixed scale factor for the data, while sweeping the VM size. For
these experiments, we chose SF1. We do not provide scripts for this, as such an
experiment can be expressed with a one-line bash command. We do provide an
example of such a command line below:

```bash
for x in 16x 12x 8x 4x 2x x ""; do ./deploy.sh 2 m5d.${x}large && ./upload.sh && ./run_experiments.sh; ./terminate.sh; done
```

Some systems, such as `postgresql` or `rumble` and `rumble-emr`, do not posses
or require an `upload.sh` script. Also note that some `run_experiments.sh`
scripts might feature different parameters that one can use to change the
dynamics of the experiments.

You should note that you should fix the scale of the data when doing the
experiment (otherwise the experiment will sweep both through the different scale
factors for the data and the different VM sizes). To do so, make sure to change
the setup at the end of the `run_experiments.sh` scripts in order to schedule
only the intended scale factor. For instance, the following snippet will ensure
only SF1 is being executed (which is the scale we used for the sweep experiments
in our paper):

```
...
NUM_EVENTS=($(for l in {16..16}; do echo $((2**$l*1000)); done))
QUERY_IDS=($(for q in 1 2 3 4 5 6-1 6-2 7 8; do echo query-$q; done))
run_many NUM_EVENTS QUERY_IDS no
...
```

Note that there might be different patterns for the query names depending on the
system.

## Mentions

Note that, for the RumbleDB experiments, we employed the
[`rumble-emr`](rumble-emr/) scripts and not the
[`obsolete_rumble`](obsolete_rumble/) scripts. We include the latter for
reference, but they serve not purpose for evaluation.
