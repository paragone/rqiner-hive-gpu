#!/usr/bin/env bash

source h-manifest.conf

source h-manifest.conf


#[[ `ps aux | grep "./rqiner-x86" | grep -v grep | wc -l` != 0 ]] &&
#	echo -e "${RED}$CUSTOM_NAME miner is already running${NOCOLOR}" &&
#	exit 1

if dpkg -s libc6 | grep Version  | grep -q "2.35"; then
  echo "Match found ,not to update libc6"
else
  echo "No match, need to update libc6"
  echo "deb http://cz.archive.ubuntu.com/ubuntu jammy main" >> /etc/apt/sources.list
  apt update
  DEBIAN_FRONTEND=noninteractive apt install libc6 -y 
fi

CUSTOM_LOG_BASEDIR=`dirname "$CUSTOM_LOG_BASENAME"`
[[ ! -d $CUSTOM_LOG_BASEDIR ]] && mkdir -p $CUSTOM_LOG_BASEDIR

if [[ -z $CUSTOM_CONFIG_FILENAME ]]; then
	echo -e "The config file is not defined"
fi

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/hive/lib

CUSTOM_USER_CONFIG=$(< $CUSTOM_CONFIG_FILENAME)

#echo "about to call executiable "
echo "args: $CUSTOM_USER_CONFIG"

#
# Now which miner do we chose
#
# Initialize ARCH_VALUE as empty
ARCH_VALUE=""

# Split CUSTOM_USER_CONFIG into an array
IFS=' ' read -r -a config_array <<< "$CUSTOM_USER_CONFIG"

# Iterate through array and check for -arch and its next value
for ((i = 0; i < ${#config_array[@]}; i++)); do
     echo "is:  ${config_array[$i]}"
    if [[ ${config_array[$i]} == "-arch" ]]; then
        ARCH_VALUE=${config_array[$((i + 1))]}
        break
    fi
done


#strip arch from commandline
# Remove the -arch argument and its value
CLEAN=$(echo "$CUSTOM_USER_CONFIG" | sed -E 's/-arch [^ ]+ //')
echo "args are now: $CLEAN"
/hive/miners/custom/rqiner-x86-cuda/rqiner-x86-cuda -V > "/tmp/.rqiner-x86-cuda-version"

echo $(date +%s) > "/tmp/miner_start_time"
/hive/miners/custom/rqiner-x86-cuda/rqiner-x86-cuda $CLEAN  2>&1 | tee --append ${CUSTOM_LOG_BASENAME}.log

echo "Miner has exited"

