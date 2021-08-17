#!/bin/bash


# example:
# > ./collect-info-new.sh ilo.host01.408.systems
# 10.10.20.21,ilo.host01.408.systems,,,ProLiant DL380 Gen10,iLO 5 v2.33,,,pw_1
# > ./collect-info-new.sh ilo.host02.408.systems
# 10.10.20.22,ilo.host02.408.systems,ILO2A234005CD.,,ProLiant XL170r Gen9,iLO 4 v2.78,,,pw_1
# >
#

exec 2>/dev/null

set -o errexit
set -o pipefail
set -o nounset


curl_config_home="$HOME/ilo"
JQ="${curl_config_home}/jq"
ilo_host="$1"
curl_config=".curl_config"
host_ilo_pw="pw_1"
host_ilo_ip=$(dig +short ${ilo_host})

test -x ${JQ} || ( printf "${JQ} is not present\n" && exit 1 )


host_ilo_status=$(curl -m 5 -k -s -K ${curl_config_home}/${curl_config} -w "%{http_code}" https://${ilo_host}/redfish/v1/Managers/1/ -o /dev/null)

case "${host_ilo_status}" in
        401)
           curl_config="${curl_config}_2"
           host_ilo_pw="pw_2"
           ;;
        404)
           curl_config="${curl_config}"
           host_ilo_pw="pw_conn_refused"
           printf "${ilo_host},,,,,,,,${host_ilo_pw},\n"
           ;;
        200)
           curl_config="${curl_config}"
           host_ilo_pw="pw_1"
           ;;
        000)
           curl_config="${curl_config}"
           host_ilo_pw="pw_timeout"
           printf "${ilo_host},,,,,,,,${host_ilo_pw},\n"
           exit 1
           ;;
        *)
           curl_config="${curl_config}"
           host_ilo_pw="pw_1"
           ;;

esac


host_firmware_version=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion | xargs)
host_ilo_fqdn=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/EthernetInterfaces/ | ${JQ} -r '.Items[0].FQDN // empty' | xargs)
host_system_info=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Systems/1/ | ${JQ} -r ' . | [.HostName, .Model] | join (",")' | xargs )
powerstate=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Systems/1/ | ${JQ} -r .PowerState)

if [[ ${host_firmware_version} =~ "iLO 5" ]]; then
    redfish_oem="Hpe"
elif [[ ${host_firmware_version} =~ "iLO 4" ]]; then
    redfish_oem="Hp"
else
    printf "invalid host firmware version collected (not 'iLO 4' or 'iLO 5')\n"
    exit 1
fi

host_ilo_health_status=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r --arg v "${redfish_oem}" '.Oem[$v].iLOSelfTestResults[] | select(.Status=="Degraded") | .Status, .Notes' | xargs)
host_manager_type_status=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} https://${ilo_host}/redfish/v1/ | ${JQ} -r --arg v "${redfish_oem}" '.Oem[$v].Manager[].IPManager // empty | .ManagerProductName, .ManagerUrl.xref' | xargs )



printf "${host_ilo_ip},${ilo_host},${host_ilo_fqdn},${host_system_info},${host_firmware_version},${host_manager_type_status},${host_ilo_health_status},${host_ilo_pw},${powerstate}\n"

exit 0


#--DONE
