#!/bin/bash
#echo on
set -x

#### SFTP
	sftp -o "IdentityFile=/home/srg/.ssh/id_rsa" -oport=8022 m279@ftp.prod.paytronix.com<< EOF

#### LOCAL DIRECTORY FOR INCOMING FILES
	lcd /home/srg/db_files/incoming/px

### grab all the files from remote host, these will be csvs
### put them into incoming local directory
	mget *.csv

### delete the files from remote host
 	rm *.csv

#### END SCRIPT
EOF




