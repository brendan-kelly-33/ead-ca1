#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

graph_function_endpoint=https://us-central1-bk-eads-ca1.cloudfunctions.net/eades_msvcs_make_graph

deployments=("door1-deployment" "door2-deployment" "seccon-deployment" "door1-sync-deployment" "door2-sync-deployment" "seccon-sync-deployment" )
average_recovery_times=()

for deployment in ${deployments[@]}; do
  total=0
  for run in $(seq 1 $1); do
    pod=$(kubectl get pods | grep $deployment | awk '{print $1}')
    startTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    kubectl delete pod $pod
    sleep 10
    newPod=$(kubectl get pods | grep $deployment | awk '{print $1}')
    newPodReadyTime=$(kubectl get pod $newPod -o json | jq -r '.status.containerStatuses[0].state.running.startedAt')
    
    echo $startTime
    echo $newPodReadyTime

    difference=$(($(gdate -d "$newPodReadyTime" '+%s') - $(gdate -d "$startTime" '+%s')))
    total=$(echo $total + $difference | bc)
  done
  average_recovery_time=$(echo $total / $1 | bc)
  average_recovery_times+=( $average_recovery_time )
done

timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=recovery_times_$timestamp.png

jsonTimes=$(echo ${average_recovery_times[@]} | jq -s '{y: .} ' )

jsonString=$(jq -s '.[0]' <<EOF
$jsonTimes
EOF
)

finalJsonString=$(echo $jsonString | jq --arg fn $filename '. += {filename: $fn, plottype: "bar", x: ["door1-A", "door2-A", "seccon-A", "door1-S", "door2-S", "seccon-S"], ylab: "Average time to recover"}')
echo $finalJsonString

curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$finalJsonString" $graph_function_endpoint
