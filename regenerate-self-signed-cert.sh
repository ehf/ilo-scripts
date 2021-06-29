#!/bin/bash


## FYI:
## running this script will cause iLO to reboot as part of cert regeneration process


# example:
## > ./regenerate-self-signed-cert.sh 10.10.10.10
## AUTHORIZED with given password. PROCEEDING...
## {
##   "Messages": [
##     {
##       "MessageID": "iLO.0.10.ImportCertSuccessfuliLOResetinProgress"
##     }
##   ],
##   "Type": "ExtendedError.1.0.0",
##   "error": {
##     "@Message.ExtendedInfo": [
##       {
##         "MessageID": "iLO.0.10.ImportCertSuccessfuliLOResetinProgress"
##       }
##     ],
##     "code": "iLO.0.10.ExtendedInfo",
##     "message": "See @Message.ExtendedInfo for more information."
##   }
## }
## >
##



#set -o errexit
set -o pipefail
set -o nounset


curl_config_home="$HOME/ilo"
curl_config=".curl_config"
JQ="$HOME/ilo/jq"
ilo_host="$1"

test -x ${JQ} || ( printf "${JQ} is not present\n" && exit 1 )


host_ilo_status=$(curl -m 10 -k -s -K ${curl_config_home}/${curl_config} -w "%{http_code}" https://${ilo_host}/redfish/v1/Managers/1/ -o /dev/null)
case "${host_ilo_status}" in
        401)
           printf "${ilo_host},UNAUTHORIZED with given password\n"
           exit 1
           ;;
        200)
           printf "AUTHORIZED with given password. PROCEEDING...\n"
           ;;
        000)
           printf "${ilo_host},TIMEOUT or INVALID iLO with given password\n"
           exit 1
           ;;
        *)
           printf "${ilo_host},UNKNOWN CONNECTION STATE\n"
           exit 1
           ;;
esac


# force regeneration of self-signed SSL certificate ; ilo will reboot
curl -m 10 -k -s -K ${curl_config_home}/${curl_config} -X DELETE https://${ilo_host}/redfish/v1/Managers/1/SecurityService/HttpsCert/ | ${JQ} .




#--DONE
