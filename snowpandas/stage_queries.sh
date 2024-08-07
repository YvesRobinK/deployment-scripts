#!/usr/bin/env bash

for i in {1..8}; do aws s3 cp queries/queries/query-${i}/query.py s3://hep-adl-queries/pyspark/query-${i}/; done
aws s3 cp queries/queries/common/functions.py s3://hep-adl-queries/pyspark/common/
aws s3 cp queries/requirements.txt s3://hep-adl-queries/pyspark/