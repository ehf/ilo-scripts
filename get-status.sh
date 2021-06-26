#!/bin/bash

#
# get progress of iLO firmware update
# run this periodically after issuing update-ilo.sh to monitor update progress
#

# example:
# > ./get-status.sh 10.10.10.10
# 10.10.10.10,IDLE,0
# >
#

# ./get-status.sh <ilo-ip|ilo-hostname>


set -o errexit
set -o pipefail
set -o nounset

curl_config_home="$HOME/ilo"
JQ="$HOME/ilo/jq"
ilo_host="$1"

test -x ${JQ} || ( printf "${JQ} is not present\n" && exit 1 )

host_firmware_version=$(curl -m 10 -k -s -K ${curl_config_home}/.curl_config https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion | xargs)

if [[ ${host_firmware_version} =~ "iLO 5" ]]; then
   progress_monitor=".Oem.Hpe.FlashProgressPercent"
   update_service_path="UpdateService"
elif [[ ${host_firmware_version} =~ "iLO 4" ]]; then
   progress_monitor='. | [.State, .ProgressPercent] | join(",")'
   update_service_path="Managers/1/UpdateService"
else
   printf "invalid host firmware version collected (not 'iLO 4' or 'iLO 5')\n"
   exit 1
fi

status=$(curl -m 10 -k -s -K ${curl_config_home}/.curl_config https://${ilo_host}/redfish/v1/${update_service_path}/ | ${JQ} -r "${progress_monitor}")
printf "${ilo_host},${status}\n"

exit 0


#--DONE
