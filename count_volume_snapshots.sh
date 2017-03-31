#!/bin/bash
ROTATION="${1}"
declare -A ARRAY

if output=$(nova volume-list | awk -F'|' '/\|/ && !/ID/{system("echo "$2"")}'); then
  set -- "$output"
  IFS=$'\n'; declare arrOutput=($*)
  for volume in "${arrOutput[@]}"; do
    declare -A ARRAY["count__${volume:0:8}"]
  done

else
  echo "NO INSTANCE FOUND"
fi

if output=$(nova volume-snapshot-list | awk -F'|' '/\|/ && !/ID/{system("echo "$5"__"$2"__"$3"")}' | sort -n); then
  set -- "$output"
  IFS=$'\n'; declare arrOutput=($*)

  for volume in "${arrOutput[@]}"; do
  	set -- "$volume"
  	IFS=__; declare arrVolume=($*)
  	# snapshot UUID
    SNAPSHOT_UUID="${arrVolume[2]:1:${#arrVolume[2]}-1}"

    # volume UUID
    VOLUME_UUID="${arrVolume[4]:1:${#arrVolume[4]}-1}"

    ARRAY[count__${VOLUME_UUID:0:8}]+="${SNAPSHOT_UUID}"
  done

  # Get the counts and if some volumes get more than `rotation` backups we've to remove the older one
  for K in "${!ARRAY[@]}"; do
  	STRINGLENGTH=${#ARRAY[$K][@]}
  	LENGTH="$((STRINGLENGTH/36))"

  	echo "length $K:::${LENGTH}---${ARRAY[$K]}"
  	if [ "${LENGTH}" -gt "${ROTATION}" ]; then
  		echo "$K has to remove its older backup :: ${ARRAY[$K]:0:36}"
  		nova volume-snapshot-delete "${ARRAY[$K]:0:36}"
  	fi
  done
else
  echo "NO VOLUME FOUND"
fi
