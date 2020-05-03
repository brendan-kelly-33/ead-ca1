#/bin/bash

if [ $# -eq 0 ]; then
  echo "Number of runs not provided"
  exit 1
fi

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

# authenticate and configure kubectl to point at Kubernetes
gcloud container clusters get-credentials bk-eads-ca --zone us-central1-c --project bk-eads-ca1

publishIntervals=(10 50 100 500)
subscribeIntervals=(500 2000 10000 50000)

averageTimes=()

for pubInt in ${publishIntervals[@]}; do
  for subInt in ${subscribeIntervals[@]}; do
    # replace deployment values
    kubectl get deployment door1-deployment -o json | jq --arg pInt "$pubInt" '.spec.template.spec.containers[0].args[1] = $pInt' | kubectl replace --force -f -
    kubectl get deployment door2-deployment -o json | jq --arg pInt "$pubInt" '.spec.template.spec.containers[0].args[1] = $pInt' | kubectl replace --force -f -
    kubectl get deployment seccon-deployment -o json | jq --arg sInt "$subInt" '.spec.template.spec.containers[0].args[1] = $sInt' | kubectl replace --force -f -

    # sleep while containers get replaced
    sleep 10
    average_time=$(get_average_response $async_endpoint $num_executions)
    echo $average_time
    averageTimes+=( $average_time )
  done
done

timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=async_variable_response_$timestamp.png

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

curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$finalJsonString" $graph_function_endpoint
