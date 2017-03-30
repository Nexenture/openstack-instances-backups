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

      #echo "name::${INSTANCE_NAME}///uuid::${INSTANCE_UUID}"

      # snapshot names will sort by date, instance_name and UUID.
      SNAPSHOT_NAME="snapshot-$(date "+%Y%m%d%H%M")-${BACKUP_TYPE}-${INSTANCE_NAME}"

      echo "INFO: Start OpenStack snapshot creation : ${INSTANCE_NAME}"

      nova backup "${INSTANCE_UUID}" "${SNAPSHOT_NAME}" "${BACKUP_TYPE}" "${ROTATION}"
      if [[ "$?" != 0 ]]; then
        echo -e "ERROR: nova image-create "${INSTANCE_UUID}" "${SNAPSHOT_NAME}" "${BACKUP_TYPE}" "${ROTATION}" failed. \n \n $(cat /root/nova_errors.log)" | mail -s "Snapshot error - Instance "${INSTANCE_NAME}"" -aFrom:Backup\<backup@nexenture.fr\> "backup@nexenture.fr"
        exit 1
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

      #echo "name::${VOLUME_NAME}///uuid::${VOLUME_UUID}"

      # snapshot names will sort by date, instance_name and UUID.
      SNAPSHOT_NAME="snapshot-$(date "+%Y%m%d%H%M")-${BACKUP_TYPE}-${VOLUME_NAME}"

      echo "INFO: Start OpenStack snapshot creation : ${VOLUME_NAME}"

      nova volume-snapshot-create "${VOLUME_UUID}" --display-name "${SNAPSHOT_NAME}" --force True
      if [[ "$?" != 0 ]]; then
        echo -e "ERROR: nova volume-snapshot-create "${VOLUME_UUID}" --display-name "${SNAPSHOT_NAME}" --force True failed \n \n $(cat /root/nova_errors.log)" | mail -s "Snapshot error - Volume \"DATA ${VOLUME_NAME}\"" -aFrom:Backup\<backup@nexenture.fr\> "backup@nexenture.fr"
        exit 1
      else
        echo "SUCCESS: Backup volume created and pending upload."
      fi
    done
  else
    echo "NO VOLUME FOUND"
  fi
}

launch_instances_backups
launch_volumes_backups
