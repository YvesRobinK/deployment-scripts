#!/usr/bin/env bash

echo "system,characters,lines,clauses,avg_clauses,unique_clauses,avg_unique" > soft_metrics.csv

for system in snowflake athena bigquery presto; do
  python3 keyword_counter.py --extension="sql" --avg_clauses ../${system}/queries/queries --for_paper --system="${system}" | tail -n 1 >> soft_metrics.csv
done

python3 keyword_counter.py --extension="sqlpp" --avg_clauses ../asterixdb-sqlpp/queries/queries --for_paper --system="asterixdb" | tail -n 1 >> soft_metrics.csv

python3 keyword_counter.py --extension="sql" --avg_clauses ../postgresql/queries/queries --for_paper --system="postgres" | tail -n 1 >> soft_metrics.csv

python3 keyword_counter.py --extension="jq" --avg_clauses ../rumble-emr/queries/queries/native-objects --for_paper --system="rumble" | tail -n 1 >> soft_metrics.csv
python3 keyword_counter.py --extension="jq" --avg_clauses ../rumble-emr/queries/queries/native-objects --for_paper --system="snowjsoniq" | tail -n 1 >> soft_metrics.csv

python3 keyword_counter.py --extension="C" --avg_clauses ../rdataframes/queries/macros --for_paper --system="rdataframes" | tail -n 1 >> soft_metrics.csv

# TODO for pyspark


python3 -c 'import pandas as pd; df = pd.read_csv("soft_metrics.csv"); df = df.rename({"characters": "#characters", "lines": "#lines", "clauses": "#clauses", "avg_clauses": "avg. \#clauses/query", "unique_clauses": "\#unique clauses", "avg_unique": "avg. \#unique clauses/query"}, axis=1); df = df.transpose(); df.columns = df.iloc[0]; df = df[1:]; df = df[["athena", "bigquery", "postgres", "presto", "rumble", "asterixdb", "rdataframes", "snowflake", "snowjsoniq"]]; print(df.to_latex())' | tail -n +5 | head -n -3 