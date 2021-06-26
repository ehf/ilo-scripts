#!/bin/bash

# example:
## ./update-ilo.sh <ilo-ip|ilo-hostname> ilo4 http://10.10.30.30/ilo4_277.bin
## ./update-ilo.sh <ilo-ip|ilo-hostname> ilo5 http://10.10.30.30/ilo5_148.bin
## ./update-ilo.sh <ilo-ip|ilo-hostname> ilo5 http://10.10.30.30/ilo5_233.bin


set -o errexit
set -o pipefail
set -o nounset


curl_config_home="$HOME/ilo"
JQ="$HOME/ilo/jq"
ilo_host="$1"
ilo_generation="$2"
ilo_firmware_location="$3"
json_ilo4_firmware="{ \"FirmwareURI\": \"${ilo_firmware_location}\", \"TPMOverrideFlag\": false }"
json_ilo5_firmware="{ \"ImageURI\": \"${ilo_firmware_location}\" }"

test -x ${JQ} || ( printf "${JQ} is not present\n" && exit 1 )


case ${ilo_generation} in
     ilo4)
        update_service_path="Managers/1/UpdateService"
        update_endpoint="HpiLOFirmwareUpdate.InstallFromURI"
        json_pkg=${json_ilo4_firmware}
        ;;
     ilo5)
        update_service_path="UpdateService"
        update_endpoint="UpdateService.SimpleUpdate"
        json_pkg=${json_ilo5_firmware}
        ;;
     *)
        printf "invalid ilo generation type (not 'ilo4' or 'ilo5')\n"
        exit 1
        ;;
esac

printf "updating ilo :: ${ilo_host} ... \n"
sleep 5
curl -m 10 -s -k -K ${curl_config_home}/.curl_config \
  -H "Content-Type: application/json" \
  -X POST \
  -d"${json_pkg}" \
  https://${ilo_host}/redfish/v1/${update_service_path}/Actions/${update_endpoint}/ | ${JQ} .

exit 0



#--DONE

##########

# ilo4
# https://${ilo_host}/redfish/v1/Managers/1/UpdateService/Actions/HpiLOFirmwareUpdate.InstallFromURI/ | ${JQ} .

# ilo5
# https://${ilo_host}/redfish/v1/UpdateService/Actions/UpdateService.SimpleUpdate/ | ${JQ} .

