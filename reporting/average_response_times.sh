#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

sync_endpoint=http://34.68.240.121:31080/
async_endpoint=http://34.68.240.121:31081/
graph_function_endpoint=https://us-central1-bk-eads-ca1.cloudfunctions.net/eades_msvcs_make_graph

num_executions=$1

get_average_response () {
  total=0

  for run in $(seq 1 $2); do
    response_time=$(curl -s -o /dev/null -w '%{time_total}\n' "$1")
    total=$(echo $total + $response_time | bc -l)
  done

  echo "scale=6; $total / $2 " | bc | sed -e 's/^-\./-0./' -e 's/^\./0./'
}

sync_average=$(get_average_response $sync_endpoint $num_executions)
async_average=$(get_average_response $async_endpoint $num_executions)

echo $sync_average
echo $async_average

timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=response_times_$timestamp.png

ylabel="Average time to execute over $1 runs (seconds)"

json_string=$(jq -n \
                  --arg fn "$filename" \
                  --arg sync_val "$sync_average" \
                  --arg async_val "$async_average" \
                  --arg ylab "$ylabel" \
                  '{filename: $fn, plottype: "bar", x: ["sync", "async"], y: [$sync_val, $async_val], ylab: $ylab}' )

echo $json_string

curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$json_string" $graph_function_endpoint