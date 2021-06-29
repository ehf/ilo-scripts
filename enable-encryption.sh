#!/bin/bash


## FYI:
## running this script will cause iLO to reboot

# example:
## ./enable-encryption.sh 10.10.10.10 ilo4
## ./enable-encryption.sh 10.10.10.20 ilo5
##


ilo_host="$1"
host_ilo_version="$2"
curl_config_home="$HOME/ilo"
curl_config=".curl_config"
JQ="$HOME/ilo/jq"
json_pkg_4='{ "Oem": { "Hp": { "EnforceAES3DESEncryption": true } } }'
json_pkg_5='{ "SecurityState": "HighSecurity" }'


case "${host_ilo_version}" in
        ilo5)
           sec_endpoint="SecurityService"
           sec_property=".SecurityState"
           json_pkg="${json_pkg_5}"
           ;;
        ilo4)
           sec_endpoint="NetworkService"
           sec_property=".Oem.Hp.EnforceAES3DESEncryption"
           json_pkg="${json_pkg_4}"
           ;;
        *)
           printf "invalid ilo version\n"
           exit 1
           ;;
esac

# confirm ilo version
host_firmware_version=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion)
host_firmware_version_check=$(echo "${host_firmware_version}" | awk -F\v '{print $1}' | tr -d '[:space:]')
if [[ "${host_ilo_version}" != "${host_firmware_version_check,,}" ]]; then
   printf "host_ilo_version argument does not match host_firmware_version_check on host iLO: ${host_firmware_version}\n"
   exit 1
fi


# don't enable if already enabled
encryption_status=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/${sec_endpoint}/ | ${JQ} -r ${sec_property})
if [[ "${encryption_status}" == "HighSecurity" ]] || [[ "${encryption_status}" == "true" ]] ; then
        printf "${ilo_host},${host_ilo_version},encryption_already_enabled,${encryption_status}\n"
        exit 0
fi


# enable encryption
curl -m 10 -k -s -K ${curl_config_home}/${curl_config} -H "Content-Type: application/json" -X PATCH  -d"$json_pkg" https://${ilo_host}/redfish/v1/Managers/1/${sec_endpoint}/ | ${JQ} .
exit 0




#--DONE



# ilo5
##curl -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/SecurityService/ | ${JQ} .SecurityState
#
# ilo4
##curl -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/NetworkService/ | ${JQ} .Oem.Hp.EnforceAES3DESEncryption
