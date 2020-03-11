#!/bin/bash
# Script to create snapshot of openstack Instance
# Place the computerc file in: /root/.openstack_snapshotrc

# Debian/Ubuntu install
# apt-get install python3-pip
# pip3 install python-openstackclient

# If you have any error while launchging openstack command :
# openstack --debug --help
# for me the fix was :
# pip3 install six --upgrade

# Get the script path
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# dry-run
DRY_RUN="${3}"

# First we check if all the commands we need are installed.
command_exists() {
  command -v "$1" >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "I require $1 but it's not installed. Aborting."
    exit 1
  fi
}

for COMMAND in "openstack" "dmidecode" "tr"; do
  command_exists "${COMMAND}"
done

# Check if the computerc file exists. If so, assume it has the credentials.
if [[ ! -f "/root/.openstack_snapshotrc" ]]; then
  echo "/root/.openstack_snapshotrc file required."
  exit 1
else
  source "/root/.openstack_snapshotrc"
fi

# Export the emails from & to
EMAIL_FROM="$LOG_EMAIL_FROM"
EMAIL_TO="$LOG_EMAIL_TO"

# backup_type
BACKUP_TYPE="${1}"
if [[ -z "${BACKUP_TYPE}" ]]; then
  BACKUP_TYPE="manual"
fi

# rotation of snapshots
ROTATION="${2}"

launch_instances_backups () {
  if output=$(openstack server list | awk -F'|' '/\|/ && !/ID/{system("echo "$2"__"$3"")}'); then
    set -- "$output"
    IFS=$'\n'; declare -a arrOutput=($*)

    for instance in "${arrOutput[@]}"; do
      set -- "$instance"
      IFS=__; declare arrInstance=($*)

      # instance UUID
      INSTANCE_UUID="${arrInstance[0]:0:${#arrInstance[0]}-1}"

      # instance name
      INSTANCE_NAME="${arrInstance[2]:1:${#arrInstance[2]}-1}"

      # snapshot names will sort by date, instance_name and UUID.
      SNAPSHOT_NAME="snapshot-$(date "+%Y%m%d%H%M")-${BACKUP_TYPE}-${INSTANCE_NAME}"

      echo "INFO: Start OpenStack snapshot creation : ${INSTANCE_NAME}"

      if [ "$DRY_RUN" = "--dry-run" ] ; then
        echo "DRY-RUN is enabled. In real a backup of the instance called ${SNAPSHOT_NAME} would've been done like that :
        openstack server backup create ${INSTANCE_UUID} --name ${SNAPSHOT_NAME} --type ${BACKUP_TYPE} --rotate ${ROTATION}"
      else
        openstack server backup create "${INSTANCE_UUID}" --name "${SNAPSHOT_NAME}" --type "${BACKUP_TYPE}" --rotate "${ROTATION}" 2> tmp_error.log
      fi
      if [[ "$?" != 0 ]]; then
        cat tmp_error.log >> openstack_errors.log
      else
        echo "SUCCESS: Backup image created and pending upload."
      fi
    done

  else
    echo "NO INSTANCE FOUND"
  fi
}

launch_volumes_backups () {
  if output=$(openstack volume list | awk -F'|' '/\|/ && !/ID/{system("echo "$2"__"$3"")}'); then
    set -- "$output"
    IFS=$'\n'; declare -a arrOutput=($*)

    for volume in "${arrOutput[@]}"; do
      set -- "$volume"
      IFS=__; declare arrVolume=($*)

      # Get the volume UUID
      VOLUME_UUID="${arrVolume[0]:0:${#arrVolume[0]}-1}"

      # Get the volume name
      VOLUME_NAME="${arrVolume[2]:1:${#arrVolume[2]}-1}"

      # snapshot names will sort by date, instance_name and UUID.
      SNAPSHOT_NAME="snapshot-$(date "+%Y%m%d%H%M")-${BACKUP_TYPE}-${VOLUME_NAME}"

      echo "INFO: Start OpenStack snapshot creation : ${VOLUME_NAME}"
      if [ "$DRY_RUN" = "--dry-run" ] ; then
        echo "DRY-RUN is enabled. In real a backup of the volume called ${SNAPSHOT_NAME} would've been done like that :"
        echo "openstack volume snapshot create --force --volume ${VOLUME_UUID} ${SNAPSHOT_NAME}"
      else
        openstack volume snapshot create --force --volume "${VOLUME_UUID}" "${SNAPSHOT_NAME}" 2> tmp_error.log
      fi
      if [[ "$?" != 0 ]]; then
        cat tmp_error.log >> openstack_errors.log
      else
        echo "SUCCESS: Backup volume created and pending upload."
      fi

    done
  else
    echo "NO VOLUME FOUND"
  fi
}

send_errors_if_there_are () {
  if [ -f openstack_errors.log ]; then
    echo -e "ERRORS:\n\n$(cat openstack_errors.log)" | mail -s "Snapshot errors" -aFrom:Backup\<$EMAIL_FROM\> "$EMAIL_TO"
  fi
}

if [ -f openstack_errors.log ]; then
  rm openstack_errors.log
fi
launch_instances_backups
launch_volumes_backups
send_errors_if_there_are
bash "$SCRIPTPATH/count_volume_snapshots.sh" "$ROTATION"
