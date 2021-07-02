#!/bin/bash

# example:
## > cat list-to-check-enc.txt | while read ip host ver; do ./get-all-ilo-security-config.sh $ip $host; done
## 10.10.10.21,,host139.lab1.example.com,ProLiant BL660c Gen9,iLO 4 v2.77,false,Signature Algorithm: sha1WithRSAEncryption,Not Before: Jan 21 05:33:42 2016 GMT ,Not After : Jan 20 05:33:42 2031 GMT,,200,,pw_1
## 10.10.10.22,,host140.lab1.example.com,ProLiant BL660c Gen9,iLO 4 v2.77,false,Signature Algorithm: sha1WithRSAEncryption,Not Before: Jan 21 04:15:23 2016 GMT ,Not After : Jan 20 04:15:23 2031 GMT,,200,,pw_1
## 10.10.10.23,,host141.lab1.example.com,ProLiant BL460c Gen9,iLO 4 v2.60,false,Signature Algorithm: sha1WithRSAEncryption,Not Before: Jan 12 06:19:40 2016 GMT ,Not After : Jan 11 06:19:40 2031 GMT,,200,,pw_1
## 10.10.10.24,,host142.lab1.example.com,ProLiant BL460c Gen9,iLO 4 v2.77,false,Signature Algorithm: sha1WithRSAEncryption,Not Before: Jan 12 06:18:37 2016 GMT ,Not After : Jan 11 06:18:37 2031 GMT,,200,,pw_1
## 10.10.10.25,,host143.lab1.example.com,ProLiant BL460c Gen9,iLO 4 v2.77,false,Signature Algorithm: sha1WithRSAEncryption,Not Before: Jan 12 08:23:47 2016 GMT ,Not After : Jan 11 08:23:47 2031 GMT,,200,,pw_1
## 10.10.10.26,,,,,,,,,,404,invalid host firmware version collected (not 'iLO 4' or 'iLO 5'),pw_unknown
## 10.10.10.27,,,,,,,,,,404,invalid host firmware version collected (not 'iLO 4' or 'iLO 5'),pw_unknown
## 10.10.10.32,,,,,,,,,,404,invalid host firmware version collected (not 'iLO 4' or 'iLO 5'),pw_unknown
## >
##

exec 2>/dev/null

ilo_host="$1"
ilo_host_ssl_port='443'
ilo_dns_name="$2"
curl_config_home="$HOME/ilo"
curl_config="${curl_config_home}/.curl_config"
JQ="$HOME/bin/jq"

shopt -s extglob


check_for_required_utilities () {
    test -x /usr/bin/openssl  || ( printf "openssl not available\n" && exit 1 )
    test -x ${JQ} || ( printf "${JQ} not available\n" && exit 1 )
}


check_ilo_conn () {
   host_ilo_conn_status=$(curl -m 10 -k -s -K ${curl_config} -w "%{http_code}" https://${ilo_host}/redfish/v1/Managers/1/ -o /dev/null)
   case "${host_ilo_conn_status}" in
        401)
           curl_config="${curl_config}_2"
           host_ilo_pw="pw_2"
           ;;
        200)
           curl_config="${curl_config}"
           host_ilo_pw="pw_1"
           ;;
        000)
           curl_config="${curl_config}"
           host_ilo_pw="pw_timeout"
           ;;
        *)
           curl_config="${curl_config}"
           host_ilo_pw="pw_unknown"
           ;;
   esac
}



get_ilo_info () {
    host_firmware_version=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion | xargs)
    if [[ ${host_firmware_version} =~ "iLO 5" ]]; then
       redfish_oem="Hpe"
    elif [[ ${host_firmware_version} =~ "iLO 4" ]]; then
       redfish_oem="Hp"
    else
       printf "${ilo_host},,,,,,,,,,${host_ilo_conn_status},invalid host firmware version collected (not 'iLO 4' or 'iLO 5'),${host_ilo_pw}\n"
       exit 1
    fi

    host_system_info=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/Systems/1/ | ${JQ} -r ' . | [.HostName, .Model] | join (",")' | xargs)
    host_ilo_health_status=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r --arg v "${redfish_oem}" '.Oem[$v].iLOSelfTestResults[] | select(.Status=="Degraded") | .Status, .Notes' | xargs)
    host_manager_type_status=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/ | ${JQ} -r --arg v "${redfish_oem}" '.Oem[$v].Manager[].IPManager // empty | .ManagerProductName, .ManagerUrl.xref' | xargs )
}


get_encryption () {
   case "${host_firmware_version}" in
        "iLO 4 v2."[0-9]+([0-9]) )
           local sec_endpoint="NetworkService"
           local sec_property=".Oem.Hp.EnforceAES3DESEncryption"
           ;;
        "iLO 5 v2."[0-9]+([0-9]) )
           local sec_endpoint="SecurityService"
           local sec_property=".SecurityState"
           ;;
        *)
           echo "unable to collect iLO version"
           shopt -u extglob
           exit 1
           ;;
   esac

   encryption=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/Managers/1/${sec_endpoint}/ | ${JQ} -r ${sec_property})
}



get_ssl_cert_signature_algorithm () {
   signature_algorithm=$(echo '' | openssl s_client -connect ${ilo_host}:${ilo_host_ssl_port} -servername ${ilo_host} 2>/dev/null | openssl x509 -noout -text | grep 'Signature Algorithm' | uniq | xargs)
}


get_ssl_cert_validity () {
   validity=$(echo '' | openssl s_client -host ${ilo_host} -port ${ilo_host_ssl_port} 2>/dev/null |  openssl x509 -noout -text | grep -A2 Validity | tail -n +2 | xargs | sed 's/Not After/,Not After/g' )
}



# run it
check_for_required_utilities
check_ilo_conn
get_ilo_info
get_encryption
get_ssl_cert_signature_algorithm
get_ssl_cert_validity

# print collected config information
printf "${ilo_host},"
printf "${ilo_dns_name},"
printf "${host_system_info},"
printf "${host_firmware_version},"
printf "${encryption},"
printf "${signature_algorithm},"
printf "${validity},"
printf "${host_manager_type_status},"
printf "${host_ilo_conn_status},"
printf "${host_ilo_health_status},"
printf "${host_ilo_pw}\n"

shopt -u extglob
exit 0


#--DONE
