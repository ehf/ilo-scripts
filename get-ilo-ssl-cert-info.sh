#!/bin/bash

ilo_host="$1"
ilo_host_ssl_port='443'



check_for_required_utilities () {
    test -x /usr/bin/openssl  || ( printf "openssl not available\n" && exit 1 )
}


get_ssl_cert_signature_algorithm () {
   signature_algorithm=$(echo '' | openssl s_client -connect ${ilo_host}:${ilo_host_ssl_port} -servername ${ilo_host} 2>/dev/null | openssl x509 -noout -text | grep 'Signature Algorithm' | uniq | xargs)
}


get_ssl_cert_validity () {
   validity=$(echo '' | openssl s_client -host ${ilo_host} -port ${ilo_host_ssl_port} 2>/dev/null |  openssl x509 -noout -text | grep -A2 Validity | tail -n +2 | xargs | sed 's/Not After/,Not After/g' )
}


# run it
check_for_required_utilities
get_ssl_cert_signature_algorithm
get_ssl_cert_validity

# print collected config information
printf "${ilo_host},"
printf "${validity},"
printf "${signature_algorithm}"
printf "\n"

exit 0


#--DONE
