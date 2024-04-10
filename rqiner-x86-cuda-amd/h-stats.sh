#!/usr/bin/env bash
source /hive/miners/custom/rqiner-x86-cuda-amd/h-manifest.conf

start_time=$(date +%s)

get_cpu_temps () {
  local t_core=`cpu-temp`
  local i=0
  local l_num_cores=$1
  local l_temp=
  for (( i=0; i < ${l_num_cores}; i++ )); do
    l_temp+="$t_core "
  done
  echo ${l_temp[@]} | tr " " "\n" | jq -cs '.'
}

get_cpu_fans () {
  local t_fan=0
  local i=0
  local l_num_cores=$1
  local l_fan=
  for (( i=0; i < ${l_num_cores}; i++ )); do
    l_fan+="$t_fan "
  done
  echo ${l_fan[@]} | tr " " "\n" | jq -cs '.'
}

get_cpu_bus_numbers () {
  local i=0
  local l_num_cores=$1
  local l_numbers=
  for (( i=0; i < ${l_num_cores}; i++ )); do
    l_numbers+="null "
  done
  echo ${l_numbers[@]} | tr " " "\n" | jq -cs '.'
}

get_miner_uptime(){
    local start_time=$(cat "/tmp/miner_start_time")
    local current_time=$(date +%s)
    let uptime=current_time-start_time
    echo $uptime
}

get_log_time_diff(){
  local a=0
  let a=`date +%s`-`stat --format='%Y' $log_name`
  echo $a
}

get_average_its() {
   echo $(awk -F'|' '/Average\(10\):/ {split($3, a, " "); for (i in a) {if (a[i] ~ /Average\(10\):/) avg=a[i+1]}} END{print avg}' "${CUSTOM_LOG_BASENAME}.log")

}
get_accepted_solutions() {

	echo $(tail -n 1 "${CUSTOM_LOG_BASENAME}.log" | grep 'Solutions' | awk -F'Solutions: ' '{print $2}')
}


# GPUs

gpu_stats_nvidia=$(jq '[.brand, .temp, .fan, .power, .busids, .mtemp, .jtemp] | transpose | map(select(.[0] == "amd")) | transpose' <<< $gpu_stats)
gpu_temp=$(jq -c '[.[1][]]' <<< "$gpu_stats_nvidia")
gpu_fan=$(jq -c '[.[2][]]' <<< "$gpu_stats_nvidia")
gpu_bus=$(jq -c '[.[4][]]' <<< "$gpu_stats_nvidia")
gpu_count=$(jq '.busids | select(. != null) | length' <<< $gpu_stats)



uptime=$(get_miner_uptime)
[[ $uptime -lt 60 ]] && head -n 50 $log_name > $log_head_name
echo "miner uptime is: $uptime"

cpu_temp=`cpu-temp`
[[ $cpu_temp = "" ]] && cpu_temp=null

cpu_is_working=$( [[ -f "$conf_cpu" ]] && echo "yes" || echo "no" )

stats=""
algo="qubic"
uptime=$(get_miner_uptime)
khs=$(get_average_its)
hs_units="hs"


lines_to_process=$((gpu_count *2 +4  ))
while IFS= read -r line; do

    if echo "$line" | grep -q "GPU[0-9]\+.*it/s"; then
        # Extract the GPU ID
        gpu=$(echo "$line" grep  GPU  | awk -F' ' '{print $4}' | sed 's/GPU//;s/://' | sed 's/ //g')
	#echo "Working on gpu $gpu"

        # Extract the iteration rate (it/s value)
	iterrate=$(echo "$line" | awk '{print $(NF -1)}')

	#echo "hs[$gpu]=$iterrate"

        # Store the it/s value in the associative array
        hs[$gpu]=$iterrate
    fi
done < <(tail -n "$lines_to_process" "${CUSTOM_LOG_BASENAME}.log")




ver=$(awk '{print$2}'  "/tmp/.rqiner-x86-cuda-version" )




total_khs=$khs
ac=$(get_accepted_solutions)
rj=0
stats=$(jq -nc \
        --argjson total_khs "$total_khs" \
        --argjson khs "$total_khs" \
        --arg hs_units "$hs_units" \
        --argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
        --argjson temp "${gpu_temp}"                               \
        --argjson fan "${gpu_fan}"                                 \
        --arg uptime "$uptime" \
        --arg ver "$ver" \
        --arg ac "$ac" --arg rj "$rj" \
        --arg algo "$algo" \
        --argjson bus_numbers "`echo ${bus_numbers[@]} | tr " " "\n" | jq -cs '.'`" \
        '{$total_khs, $khs, $hs_units, $hs, $temp, $fan, $uptime, $ver, ar: [$ac, $rj], $algo, $bus_numbers}')

# debug output

 echo khs:   $hs
 echo stats: $stats
 echo ----------
