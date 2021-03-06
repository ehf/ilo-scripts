#!/bin/bash


ilo_host="$1"
ilo_host_ssl_port='443'

test -x /usr/bin/openssl  || ( printf "openssl not available\n" && exit 1 )

validity=$(echo '' | openssl s_client -host ${ilo_host} -port ${ilo_host_ssl_port} 2>/dev/null |  openssl x509 -noout -text | grep -A2 Validity | tail -n +2 | xargs | sed 's/Not After/,Not After/g')
printf "${ilo_host},${validity}\n"

exit 0
