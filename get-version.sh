#!/bin/bash

# get version of iLO firmware

# example:
# > ./get-version.sh 10.10.20.20
# 10.10.20.20,iLO 4 v2.77
# > ./get-version.sh 10.10.20.21
# 10.10.20.21,iLO 5 v2.33
# >
#

# ./get-version.sh <ilo-ip|ilo-hostname>


set -o errexit
set -o pipefail
set -o nounset

curl_config_home="$HOME/ilo"
JQ="$HOME/ilo/jq"
ilo_host="$1"

test -x ${JQ} || ( printf "${JQ} is not present\n" && exit 1 )

version=$(curl -m 10 -k -s -K ${curl_config_home}/.curl_config https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion)
printf "${ilo_host},${version}\n"

exit 0



#--DONE
