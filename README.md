# OpenStack automatic instances & volumes snapshots
Nova, OpenStack compute service is used for hosting and managing cloud computing systems.

Below we gonna see how to automate the backups of your volumes & instances

cf. tutorial
https://raymii.org/s/tutorials/OpenStack_Quick_and_automatic_instance_snapshot_backups.html

## Dependencies
### OpenStack Command lines tools

The script requires to have the command line tools dmidecode, wget & python-pip

```
# Ubuntu/Debian
apt-get install dmidecode wget python-pip3
pip3 install python-openstackclient
```

### Mail agent
To send the errors at the end of the script you need a message transfer agent on your unix server
On Debian you can try exim4 (please find the configuration of that package : http://www.deltasight.fr/utiliser-ovh-smarthost-exim4/)

## Configuration
### Credentials file
Firstable you need to create the file :

```
nano /root/.openstack_snapshotrc

export OS_AUTH_URL="https://identity.stack.cloudvps.com/v3"
export OS_PROJECT_NAME="PROJECT_UUID"
export OS_PROJECT_ID="PROJECT_UUID"
export OS_USER_DOMAIN_NAME="Default"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="default"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi
unset OS_TENANT_ID
unset OS_TENANT_NAME
export OS_USERNAME="USERNAME"
export OS_PASSWORD="PASSWORD"
export OS_REGION_NAME="REGION"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3
export LOG_EMAIL_FROM="FROM"
export LOG_EMAIL_TO="TO"
```
Please note that the last line `OS_REGION_NAME` is needed for **OVH Cloud**

Then you need to source it to apply the credentials :

```
source /root/.openstack_snapshotrc
```

### Install the scripts

git clone this repo then chmod 755 *.sh scripts

For example in your /home/user/ directory you can paste the `create_snapshot.sh` & `count_volume_snapshots.sh`

### Rotations configuration
About the rotations, the second parameter gonna program it.
For the volumes the `nova backup` command already has a native parameter, but for the instances the `count_volume_snapshots.sh` bash script is going to do the work !

### Try it with the dry run !
By default the dry run mode is disable. You need to add a third `--dry-run` argument to enable it and test the command :

```
# dry run mode
/home/user/create_snapshot.sh daily 7 --dry-run

# do it mode
/home/user/create_snapshot.sh daily 7
```
