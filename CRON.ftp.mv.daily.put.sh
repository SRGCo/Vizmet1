#!/bin/bash
#echo on
set -x

#### LFTP

lftp -e 'set net:timeout 10;set ssl:verify-certificate no; set ftp:ssl-protect-data true;  mput -O /Paytronix/ /home/srg/db_files/incoming/px/*; bye' -u serenitee-pt,S3tm#XB4z! ftp.marketingvitals.com <<EOF

#### END SCRIPT
EOF








