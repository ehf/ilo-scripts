#!/bin/bash

# example:
## > cat list-to-check-enc.txt | while read ip host ver; do ./get-all-ilo-security-config.sh $ip $host; done
## 10.10.10.20,ilo.host006.lab1.408.systems.com,,ProLiant XL170r Gen9,iLO 4 v2.78,true,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jul 2 17:50:26 2021 GMT ,Not After : Jul 1 17:50:26 2036 GMT
## 10.10.10.21,ilo.hostgpu002.lab1.408.systems.com,,ProLiant DL380 Gen10,iLO 5 v2.44,HighSecurity,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jul 2 17:45:44 2021 GMT ,Not After : Jul 1 17:45:44 2036 GMT
## 10.10.10.22,ilo.host123.lab1.408.systems.com,host123.lab1.408.systems.com,ProLiant BL460c Gen9,iLO 4 v2.77,true,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jun 28 21:18:22 2021 GMT ,Not After : Jun 27 21:18:22 2036 GMT
## 10.10.10.23,ilo.host126.lab1.408.systems.com,host126.lab1.408.systems.com,ProLiant BL460c Gen9,iLO 4 v2.77,true,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jun 19 00:20:37 2021 GMT ,Not After : Jun 18 00:20:37 2036 GMT
## 10.10.10.24,ilo.newhost.lab1.408.systems.com,,ProLiant BL460c Gen9,iLO 4 v2.77,true,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jun 28 20:40:06 2021 GMT ,Not After : Jun 27 20:40:06 2036 GMT
## 10.10.10.25,ilo.host147.lab1.408.systems.com,host147.lab1.408.systems.com,ProLiant BL460c Gen9,iLO 4 v2.77,true,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jul 2 17:27:10 2021 GMT ,Not After : Jul 1 17:27:10 2036 GMT
## 10.10.10.26,ilo.hostgpu001.lab1.408.systems.com,,ProLiant DL380 Gen10,iLO 5 v2.33,HighSecurity,Signature Algorithm: sha256WithRSAEncryption,Not Before: Jun 28 21:09:27 2021 GMT ,Not After : Jun 27 21:09:27 2036 GMT
## >
##


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

get_ilo_info () {
    host_firmware_version=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/Managers/1/ | ${JQ} -r .FirmwareVersion | xargs)
    host_system_info=$(curl -m 10 -k -s -K ${curl_config} https://${ilo_host}/redfish/v1/Systems/1/ | ${JQ} -r ' . | [.HostName, .Model] | join (",")' | xargs )
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
   validity=$(echo '' | openssl s_client -host ${ilo_host} -port ${ilo_host_ssl_port} 2>/dev/null |  openssl x509 -noout -text | grep -A2 Validity | tail -n +2 | xargs | sed 's/Not After/,Not After/g')
}



# run it
check_for_required_utilities
get_ilo_info
get_encryption
get_ssl_cert_signature_algorithm
get_ssl_cert_validity

# print collected config information
printf "${ilo_host},${ilo_dns_name},"
printf "${host_system_info},${host_firmware_version},"
printf "${encryption},"
printf "${signature_algorithm},"
printf "${validity}\n"

shopt -u extglob
exit 0

