import argparse
import json
import pandas
from pathlib import Path
import re
import sys


# Set up the input parameters
parser = argparse.ArgumentParser(
    description='Get the soft metrics for the JSONiq queries.',
)
parser.add_argument('path', help='Path to the queries.')
parser.add_argument('--extension', type=str, default="jq",
                    help="The extension of the query files. Can be 'jq', "
                    "'sql', 'sqlpp', 'C'")
parser.add_argument('--csv', action="store_true")
parser.add_argument('--avg_clauses', action="store_true")
parser.add_argument('--for_paper', action="store_true", help="Prints a CSV row "
                    "for the table in the paper")
parser.add_argument('--system', help="Required when printing for paper")
args = parser.parse_args()


# The dictionary which stores the counts
if args.extension == "jq":
  dict_counter = {
    "FUNCTION": 0,
    "LET": 0,
    "FOR": 0,
    "IF": 0,
    "GROUP": 0,
    "ORDER": 0,
    "WHERE": 0,
    "COUNT": 0,
    "EXISTS": 0,
    "EMPTY": 0
  }
elif args.extension == "sql" or args.extension == "sqlpp":
  dict_counter = {
    "SELECT": 0,
    "CAST": 0,
    "CASE": 0,
    "WHEN": 0,
    "WHERE": 0,
    "GROUP": 0,
    "COUNT": 0,
    "ORDER": 0,
    "JOIN": 0,
    "ARRAY_CAT": 0,
    "ARRAY_AGG": 0,
    "ARRAY_LENGTH": 0,
    "CARDINALITY": 0,
    "FILTER": 0,
    "WITH": 0,
    "AND": 0,
    "HAVING": 0,
    "DROP": 0,
    "CREATE": 0,
    "COALESCE": 0,
    "TRANSFORM": 0,
    "ARRAY_UNION": 0,
    "NONE_MATCH": 0,
    "UNNEST": 0,
    "FUNCTION": 0,
    "LIMIT": 0,
    "EXISTS": 0,
    "UNION": 0,
    "MAX_BY": 0,
    "MIN_BY": 0,
    "ARRAY_MAX": 0,
    "SUM": 0,
    "LET": 0,
    "VALUE": 0,
    "FLATTEN": 0,
    "ANY_VALUE": 0,
    "BOOLAND_AGG": 0,
    "OBJECT_CONSTRUCT": 0,
    "WITHIN": 0,
    "GET": 0,
    "OR": 0,
    "NOT": 0,
    "FROM": 0,
  }
else:
  # This is the C (e.g. RDF) case
  dict_counter = {
    "RETURN": 0,  # These are proxies for functions
    "FOR": 0,
    "IF": 0,
    "FILTER": 0,
    "DEFINE": 0,
    "VECOPS": 0,
    "CONCATENATE": 0,
    "ARGMIN": 0,
    "REVERSE": 0,
    "HISTO1D": 0,
    "PUSH_BACK": 0,
    "EMPLACE_BACK": 0,
    "COMBINATIONS": 0,
    "ENABLEIMPLICITMT": 0,
    "SUM": 0,
    "MAP": 0,
    "MAX": 0,
    "TAKE": 0
  }


def line_metrics(lines, metrics):
  for line in lines:
    if line.strip() != "":
      metrics["lines"] += 1

      tokens = line.split()
      for token in tokens:
        metrics["characters"] += len(token)
        split_tokens = re.split("[^A-Z_]", token.upper())
        for split_token in split_tokens:
          if split_token in metrics["tokens"]:
            metrics["tokens"][split_token] += 1

  metrics["unique_clauses"] = sum([1 for _, v in metrics["tokens"].items() if v > 0])
  metrics["total_clauses"] = sum(metrics["tokens"].values())
  return metrics

# Parse a query
def eval_query(path):
  metrics = {
    "type": args.extension,
    "name": str(path),
    "lines": 0,
    "characters": 0,
    "unique_clauses": 0,
    "total_clauses": 0,
    "tokens": dict_counter.copy()
  }

  with open(path, "r") as f:
    lines = f.readlines()

  line_metrics(lines, metrics)
  return metrics, lines


def main():
  lines = []
  summary = {}
  concatenated = ""

  for path in Path(args.path).rglob(f'*.{args.extension}'):
    result = eval_query(path)
    summary[path] = result[0]
    lines.extend(result[1])

  with open("summary.json", "w") as f:
    for j in summary.values():
      json.dump(j, f)
      f.write("\n")

  if args.csv:
    pandas.json_normalize(summary.values()).to_csv("summary.csv")

  if args.avg_clauses:
    queries = [s for k, s in summary.items() if (k.name.startswith("query.") if args.extension != "C" else k.name.startswith("benchmark"))]
    avg_unique_clause = sum([x["unique_clauses"] for x in queries]) / len(queries)
    avg_clause = sum([x["total_clauses"] for x in queries]) / len(queries)
    metrics = line_metrics(
      lines,
      {
        "type": args.extension,
        "name": "all",
        "lines": 0,
        "characters": 0,
        "unique_clauses": 0,
        "total_clauses": 0,
        "avg_clause_per_query": avg_clause,
        "avg_unique_clauses_per_query": avg_unique_clause,
        "tokens": dict_counter.copy()
      })
    print("Summary:\n", json.dumps(metrics, indent=4, sort_keys=True))

    if args.for_paper:
      # system,characters,lines,clauses,avg_clauses,unique_clauses,avg_unique
      print(f"{args.system},{metrics['characters']},{metrics['lines']},"
            f"{metrics['total_clauses']},{metrics['avg_clause_per_query']},"
            f"{metrics['unique_clauses']},"
            f"{metrics['avg_unique_clauses_per_query']}")


if __name__ == '__main__':
  main()
