#!/bin/bash

# Author: Brendan Kelly X00159345
# This script retrieves the average recovery times of both the asynchronous and synchronous applications for a given number of runs.
# Every deployment is tested by deleting a pod and testing the ready time of the replacement pod
# PARAM $1 number of runs to execute

echo "Beginning average recovery times test"

# Exit if number of runs not provided
if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

graph_function_endpoint=https://us-central1-bk-eads-ca1.cloudfunctions.net/eades_msvcs_make_graph

# List of deployments to retrieve pods for
deployments=("door1-deployment" "door2-deployment" "seccon-deployment" "door1-sync-deployment" "door2-sync-deployment" "seccon-sync-deployment" )
average_recovery_times=()

# Loop through deployments to calculate recovery time
for deployment in ${deployments[@]}; do
  total=0
  for run in $(seq 1 $1); do

    # get pod ID
    pod=$(kubectl get pods | grep $deployment | awk '{print $1}')

    # calculate start time of run
    startTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # delete pod
    kubectl delete pod $pod

    # sleep for 10 seconds to allow pod to recover
    sleep 10

    # get new pod ID
    newPod=$(kubectl get pods | grep $deployment | awk '{print $1}')

    # get pod ready time
    newPodReadyTime=$(kubectl get pod $newPod -o json | jq -r '.status.containerStatuses[0].state.running.startedAt')
    
    echo $startTime
    echo $newPodReadyTime

    # calculate difference between start time and ready time
    difference=$(($(gdate -d "$newPodReadyTime" '+%s') - $(gdate -d "$startTime" '+%s')))
    total=$(echo $total + $difference | bc)
  done
  average_recovery_time=$(echo $total / $1 | bc)
  average_recovery_times+=( $average_recovery_time )
done

# create graph filename based on current time
timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=recovery_times_$timestamp.png

# convert recovery times into JSON array
jsonTimes=$(echo ${average_recovery_times[@]} | jq -s '{y: .} ' )

# create JSON string for graph upload
jsonString=$(jq -s '.[0]' <<EOF
$jsonTimes
EOF
)

finalJsonString=$(echo $jsonString | jq --arg fn $filename '. += {filename: $fn, plottype: "bar", x: ["door1-A", "door2-A", "seccon-A", "door1-S", "door2-S", "seccon-S"], ylab: "Average time to recover"}')
echo $finalJsonString

# Call Google Cloud function to create graph
curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$finalJsonString" $graph_function_endpoint

# Create report
{
  echo "<!doctype html><html>"
  echo "<head><title>Average recovery times for synchronous and asynchronous applications</title>"
  echo "<style>table, th, td { padding: 10px; border: 1px solid black; border-collapse: collapse;}</style></head>"
  echo "<body><h1>Average recovery times for synchronous and asynchronous applications</h1>"
  echo "<h3>Number of runs: $1</h3>"
  echo "<table><tbody><tr><th>Deployment</th><th>Recovery time</th></tr>"

  for i in "${!deployments[@]}"; do
    echo "<tr><td>${deployments[$i]}</td><td>${average_recovery_times[$i]} s</td></tr>"
  done

  echo "</tbody></table>"
  echo "<img src='https://storage.cloud.google.com/bk-eads-ca-bucket/$filename'/>"
  echo "</body></html>"
} >> reports/recovery_times_$timestamp.html
