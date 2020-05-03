#/bin/bash

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

# apply standard manifests and run standard test
kubectl replace --force -f manifests/door.yaml
kubectl replace --force -f manifests/seccon.yaml
sleep 10
average_time_standard=$(get_average_response $async_endpoint $num_executions)

# change door to have increased publish frequency
kubectl replace --force -f manifests/door_increased.yaml
sleep 10
average_time_door_increase=$(get_average_response $async_endpoint $num_executions)

# change seccon to have increased poll frequency
kubectl replace --force -f manifests/seccon_increased.yaml
sleep 10
average_time_door_increase_and_seccon_increase=$(get_average_response $async_endpoint $num_executions)

# seccon still increased, door back to standard
kubectl replace --force -f manifests/door.yaml
sleep 10
average_time_seccon_increase=$(get_average_response $async_endpoint $num_executions)

echo $average_time_standard
echo $average_time_door_increase
echo $average_time_door_increase_and_seccon_increase
echo $average_time_seccon_increase

timestamp=$(date +%d-%m-%Y_%H-%M-%S)
filename=linechart_$timestamp.png

json_string=$(jq -n \
                  --arg fn "$filename" \
                  --arg standard "$average_time_standard" \
                  --arg seccon_increase "$average_time_seccon_increase" \
                  --arg door_increase "$average_time_door_increase" \
                  --arg door_and_seccon_increase "$average_time_door_increase_and_seccon_increase"\
                  --arg door_standard_line "Door publish interval: 10ms" \
                  --arg door_increase_line "Door publish interval: 50ms" \
                  '{filename: $fn, plottype: "line", x: ["2000", "10000"], "y":[$standard, $seccon_increase, $door_increase, $door_and_seccon_increase], "ylab":[$door_standard_line, $door_increase_line]}' )

echo $json_string

curl -i \
      -H "Accept: application/json" \
      -H "Content-Type:application/json" \
      -X POST --data "$json_string" $graph_function_endpoint