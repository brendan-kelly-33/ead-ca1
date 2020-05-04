#/bin/bash

# Author: Brendan Kelly X00159345
# This script retrieves the average recovery times of the asynchronous application for a given number of runs.
# Between runs, publish and subscribe intervals are changed in order to modify how the application behaves.
# PARAM $1 number of runs to execute

# Exit if number of runs not provided
if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

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

# authenticate and configure kubectl to point at Kubernetes
gcloud container clusters get-credentials bk-eads-ca --zone us-central1-c --project bk-eads-ca1

# list of publish and subscribe intervals to change
publishIntervals=(10 50 100 500)
subscribeIntervals=(500 2000 10000 50000)
averageTimes=()

# loop through both sets of intervals to ensure all cases are executed
for pubInt in ${publishIntervals[@]}; do
  for subInt in ${subscribeIntervals[@]}; do

    # replace deployment values with new interval values
    kubectl get deployment door1-deployment -o json | jq --arg pInt "$pubInt" '.spec.template.spec.containers[0].args[1] = $pInt' | kubectl replace --force -f -
    kubectl get deployment door2-deployment -o json | jq --arg pInt "$pubInt" '.spec.template.spec.containers[0].args[1] = $pInt' | kubectl replace --force -f -
    kubectl get deployment seccon-deployment -o json | jq --arg sInt "$subInt" '.spec.template.spec.containers[0].args[1] = $sInt' | kubectl replace --force -f -

    # sleep while containers get replaced
    sleep 10

    # retrieve average time to call application
    average_time=$(get_average_response $async_endpoint $num_executions)
    echo $average_time
    averageTimes+=( $average_time )
  done
done

# create graph filename based on current time
timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=async_variable_response_$timestamp.png

# create json string to upload to cloud function
jsonSubInt=$(echo ${subscribeIntervals[@]} | jq -s '{x: .} ' )
jsonPubInt=$(echo ${publishIntervals[@]} | jq -s '{ylab: .} ' )
jsonTimes=$(echo ${averageTimes[@]} | jq -s '{y: .} ' )

jsonString=$(jq -s '.[0] + .[1] + .[2]' <<EOF
$jsonSubInt
$jsonTimes
$jsonPubInt
EOF
)

finalJsonString=$(echo $jsonString | jq --arg fn $filename '. += {filename: $fn, plottype: "line"}')
echo $finalJsonString

# Call Google Cloud function to create graph
curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$finalJsonString" $graph_function_endpoint
