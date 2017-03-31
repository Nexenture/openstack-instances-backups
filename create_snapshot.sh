#!/bin/bash
# Script to create snapshot of Nova Instance (to glance)
# Place the computerc file in: /root/.openstack_snapshotrc

# To restore to a new server:
# nova boot --image "SNAPSHOT_NAME" --poll --flavor "Standard 1" --availability-zone NL1 --nic net-id=00000000-0000-0000-0000-000000000000 --key "SSH_KEY" "VM_NAME"
# To restore to this server (keep public IP)
# nova rebuild --poll "INSTANCE_UUID" "SNAPSHOT_IMAGE_UUID"

# OpenStack Command Line tools required:
# apt-get install python-novaclient
# apt-get install python-keystoneclient
# apt-get install python-glanceclient

# Or for older/other distributions:
# apt-get install python-pip || yum install python-pip
# pip install python-novaclient
# pip install python-keystoneclient
# pip install python-glanceclient

# To create a snapshot before an apt-get upgrade:
# Place the following in /etc/apt/apt.conf.d/00glancesnapshot
# DPKG::Pre-Invoke {"/bin/bash /usr/local/bin/glance-image-create.sh";};
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games

# Get the script path
SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`

# dry-run
DO_IT="${3}"

# First we check if all the commands we need are installed.
command_exists() {
  command -v "$1" >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo "I require $1 but it's not installed. Aborting."
    exit 1
  fi
}

for COMMAND in "nova" "glance" "dmidecode" "tr"; do
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
  if output=$(nova list --minimal | awk -F'|' '/\|/ && !/ID/{system("echo "$2"__"$3"")}'); then
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

      if [ "$DO_IT" = true ] ; then
        nova backup "${INSTANCE_UUID}" "${SNAPSHOT_NAME}" "${BACKUP_TYPE}" "${ROTATION}" 2> tmp_error.log
      else
        echo "DRY-RUN is enabled. In real a backup of the instance called ${SNAPSHOT_NAME} would've been done like that :
        nova backup ${INSTANCE_UUID} ${SNAPSHOT_NAME} ${BACKUP_TYPE} ${ROTATION}
        Add a third true arg to disable the dry run then do it !"
      fi
      if [[ "$?" != 0 ]]; then
        cat tmp_error.log >> nova_errors.log
      else
        echo "SUCCESS: Backup image created and pending upload."
      fi
    done

  else
    echo "NO INSTANCE FOUND"
  fi
}

launch_volumes_backups () {
  if output=$(nova volume-list | awk -F'|' '/\|/ && !/ID/{system("echo "$2"__"$4"")}'); then
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
      if [ "$DO_IT" = true ] ; then
        nova volume-snapshot-create "${VOLUME_UUID}" --display-name "${SNAPSHOT_NAME}" --force True 2> tmp_error.log
      else
        echo "DRY-RUN is enabled. In real a backup of the volume called ${SNAPSHOT_NAME} would've been done like that :
        nova volume-snapshot-create ${VOLUME_UUID} --display-name ${SNAPSHOT_NAME} --force True
        Add a third true arg to disable the dry run then do it !"
      fi
      if [[ "$?" != 0 ]]; then
        cat tmp_error.log >> nova_errors.log
      else
        echo "SUCCESS: Backup volume created and pending upload."
      fi

    done
  else
    echo "NO VOLUME FOUND"
  fi
}

send_errors_if_there_are () {
  if [ -f nova_errors.log ]; then
    echo -e "ERRORS:\n\n$(cat nova_errors.log)" | mail -s "Snapshot errors" -aFrom:Backup\<$EMAIL_FROM\> "$EMAIL_TO"
  fi
}

if [ -f nova_errors.log ]; then
  rm nova_errors.log
fi
launch_instances_backups
launch_volumes_backups
send_errors_if_there_are
$SCRIPTPATH/count_volume_snapshots.sh
