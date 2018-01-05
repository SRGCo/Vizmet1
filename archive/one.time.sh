

# 4-3-2017
#! /bin/bash
# Next line turns echo on
set -x



### FIRE UP MYSQL
mysql -v -uroot -ps3r3n1t33<<EOFMYSQL

### CHOOSE DATABASE

USE SRG_checks;

##### WRITE TO OUTFILE
	SELECT CheckDetail_Live.* INTO OUTFILE '/home/srg/db_files/incoming/CheckDetail_Live.out.csv' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' FROM CheckDetail_Live; 

# QUIT MYSQL
EOFMYSQL

##### PROCESS THE FILE
#### PREPEND HEADERS
cat /home/srg/db_files/headers/checkdetail.headers.csv /home/srg/db_files/incoming/CheckDetail_Live.out.csv > /home/srg/db_files/incoming/CheckDetail_Live.csv




