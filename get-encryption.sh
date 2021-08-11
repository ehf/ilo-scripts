#!/bin/bash

# ilo4
## curl -K ${curl_config_home}/${curl_config} -k -s https://${ilo_host}/redfish/v1/Managers/1/SecurityService/ | ${JQ} .SecurityState
#
# ilo5
## curl -K ${curl_config_home}/${curl_config} -k -s https://${ilo_host}/redfish/v1/Managers/1/NetworkService/ | ${JQ} .Oem.Hp.EnforceAES3DESEncryption




exec 2>/dev/null

curl_config_home="$HOME/ilo"
JQ="${curl_config_home}/jq"
ilo_host="$1"
curl_config=".curl_config"

test -x ${JQ} || ( printf "${JQ} is not present\n" && exit 1 )


host_firmware_version=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion | xargs)
host_system_info=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Systems/1/ | ${JQ} -r ' . | [.HostName, .Model] | join (",")' | xargs )




shopt -s extglob
case "${host_firmware_version}" in
        "iLO 4 v2."[0-9]+([0-9]) )
           sec_endpoint="NetworkService"
           sec_property=".Oem.Hp.EnforceAES3DESEncryption"
           ;;
        "iLO 5 v2."[0-9]+([0-9]) )
           sec_endpoint="SecurityService"
           sec_property=".SecurityState"
           ;;
        *)
           echo "unable to collect iLO version"
           shopt -u extglob
           exit 1
           ;;
esac


encryption=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/${sec_endpoint}/ | ${JQ} -r ${sec_property})
printf "${ilo_host},${host_system_info},${host_firmware_version},${encryption}\n"

exit 0
