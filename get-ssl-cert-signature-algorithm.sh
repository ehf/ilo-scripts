#!/bin/bash


# example:
## > ./get-ssl-cert-signature-algorithm.sh 10.10.10.10
## 10.10.10.10,Signature Algorithm: sha256WithRSAEncryption
## > ./get-ssl-cert-signature-algorithm.sh 10.10.10.20
## 10.10.10.20,Signature Algorithm: sha256WithRSAEncryption
## >
##



ilo_host="$1"

test -x /usr/bin/openssl  || ( printf "openssl not available\n" && exit 1 )

signature_algorithm=$(echo '' | openssl s_client -connect ${ilo_host}:443 -servername ${ilo_host} 2>/dev/null | openssl x509 -noout -text | grep 'Signature Algorithm' | uniq | xargs)
printf "${ilo_host},${signature_algorithm}\n"

exit 0
