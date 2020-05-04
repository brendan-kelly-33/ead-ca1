#!/bin/bash

# Author: Brendan Kelly X00159345
# This script retrieves the average response times of both the asynchronous and synchronous applications for a given number of runs.
# PARAM $1 number of runs to execute

echo "Beginning average response times test"

# Exit if number of runs not provided
if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

sync_endpoint=http://34.68.240.121:31080/
async_endpoint=http://34.68.240.121:31081/
graph_function_endpoint=https://us-central1-bk-eads-ca1.cloudfunctions.net/eades_msvcs_make_graph

num_executions=$1

# function to get response and calculate average time to complete
# PARAM $1 url to retrieve
# PARAM $2 number of runs to execute
get_average_response () {
  total=0

  for run in $(seq 1 $2); do

    # call application, parse total time to execute
    response_time=$(curl -s -o /dev/null -w '%{time_total}\n' "$1")
    total=$(echo $total + $response_time | bc -l)
  done

  # calculate average response time
  echo "scale=6; $total / $2 " | bc | sed -e 's/^-\./-0./' -e 's/^\./0./'
}

# get average response for websites
sync_average=$(get_average_response $sync_endpoint $num_executions)
async_average=$(get_average_response $async_endpoint $num_executions)

echo $sync_average
echo $async_average

# create graph filename based on current time
timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=response_times_$timestamp.png

# create json string to upload to cloud function
ylabel="Average time to execute over $1 runs (seconds)"
json_string=$(jq -n \
                  --arg fn "$filename" \
                  --arg sync_val "$sync_average" \
                  --arg async_val "$async_average" \
                  --arg ylab "$ylabel" \
                  '{filename: $fn, plottype: "bar", x: ["sync", "async"], y: [$sync_val, $async_val], ylab: $ylab}' )

echo $json_string

# Call Google Cloud function to create graph
curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$json_string" $graph_function_endpoint

# Create report
{
  echo "<!doctype html><html>"
  echo "<head><title>Average response times for synchronous and asynchronous applications</title>"
  echo "<style>table, th, td { padding: 10px; border: 1px solid black; border-collapse: collapse;}</style></head>"
  echo "<body><h1>Average response times for synchronous and asynchronous applications</h1>"
  echo "<h3>Number of runs: $1</h3>"
  echo "<table><tbody><tr><th>Asynchronous</th><th>Synchronous</th></tr>"
  echo "<tr><td>${async_average} s</td>"
  echo "<td>${sync_average} s</td></tr>"
  echo "</tbody></table>"
  echo "<img src='https://storage.cloud.google.com/bk-eads-ca-bucket/$filename'/>"
  echo "</body></html>"
} >> reports/response_times_$timestamp.html
