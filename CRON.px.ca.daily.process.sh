#! //bin/bash
# LOG IT TO SYSLOG

############################################################################################
################## FIX THIS SCRIPT SO IT DOES ITS WORK IN A NON PRODUCTION DIRECTORY !!!!!
############################################################################################

exec 1> >(logger -s -t $(basename $0)) 2>&1

#UNCOMMENT NEXT FOR VERBOSE
# set -x

## REMOVE HEADERS AND MERGE (IF NECCESSARY) INCOMING CARD ACTIVITY CSVs
## INTO SINGLE CARD ACTIVITY FILE IN DB_FILES
for file in /home/srg/db_files/incoming/px/CardActivity*.csv
do
    tail -n+3 "$file"  >> /home/srg/db_files/CardActivity.csv
done

## MySQL IN VERBOSE MODE
mysql -uroot -ps3r3n1t33<<EOFMYSQL

## SELECT DB
USE SRG_px;

# Delete Temp table if it exists
	DROP TABLE IF EXISTS CardActivity_Temp;

# Create a empty copy of CardActivity table from CardActivityStructure table
        CREATE TABLE CardActivity_Temp AS (SELECT * FROM CardActivity_Structure WHERE 1=0);

# Load the data from the latest file into the (temp) CardActivity table
       Load data local infile '/home/srg/db_files/CardActivity.csv' into table CardActivity_Temp fields terminated by ',' lines terminated by '\n';

# Create POSkey field
	ALTER TABLE CardActivity_Temp ADD LocationID INT( 3 ) first;
	UPDATE CardActivity_Temp set LocationID = (SELECT ID from locations WHERE locations.PXID = CardActivity_Temp.StoreNumber);

# UPDATE THE DOB TO VARCHAR
	ALTER TABLE CardActivity_Temp modify TransactionDate VARCHAR(40);
	ALTER TABLE CardActivity_Temp ADD COLUMN TransactionTime VARCHAR(10) AFTER TransactionDate;
	UPDATE CardActivity_Temp SET TransactionTime = RIGHT(TransactionDate, 5);
	UPDATE CardActivity_Temp SET TransactionDate = LEFT(TransactionDate,10);

# PUT TransactionDate INTO SQL FORMAT
        UPDATE CardActivity_Temp SET TransactionDate= STR_TO_DATE(TransactionDate, '%Y-%m-%d') WHERE STR_TO_DATE(TransactionDate, '%Y-%m-%d') IS NOT NULL;

# Change TransactionDate field to type date
	ALTER TABLE CardActivity_Temp CHANGE TransactionDate TransactionDate DATE;

# Create POSkey field
	ALTER TABLE CardActivity_Temp ADD POSkey VARCHAR( 255 ) first;

# Create excel date field
	ALTER TABLE CardActivity_Temp ADD Exceldate INT(100) NOT NULL AFTER LocationID;

# Update excel date field
	 UPDATE CardActivity_Temp set Exceldate = (((unix_timestamp(TransactionDate) / 86400) + 25569) + (-5/24));

# Update POSkey field (location + TransactionDate[excel format][no decimal] + checknumber)
	 UPDATE CardActivity_Temp set POSkey = CONCAT_WS('', LocationID, Exceldate, CheckNo);

# ADD the RowID field but do not populate it (it will get auto increment when it is selected into CardActivitylive)
          ALTER TABLE CardActivity_Temp ADD COLUMN RowID int(11) AFTER POSkey;

########### UPDATE THE CardActivitylive table
          INSERT INTO CardActivity_Live SELECT * FROM CardActivity_Temp;

############# CLEAN UP THE PAYTRONIX CHECKNUMBERS WHICH HAVE BEEN TRUNCATED ########################
################## BEFORE UBER JOIN WITH CHECK DETAIL
# QUIT MYSQL
EOFMYSQL

mysql -uroot -ps3r3n1t33 -DSRG_checks -N -e "SELECT RIGHT(CheckNumber, 4), DOB, LocationID FROM CheckDetail_Live WHERE CheckDetail_Live.CheckNumber like '100%'" | while read -r CheckNumber DOB LocationID;
do
echo $CheckNumber $DOB $LocationID
mysql -uroot -ps3r3n1t33 -DSRG_px -N -e "UPDATE CardActivity_Live SET CheckNo=CONCAT('100',CheckNo) WHERE CheckNo = '$CheckNumber' AND TransactionDate = '$DOB' AND LocationID = '$LocationID' AND char_length(CheckNo) < '6'"
done

mysql -uroot -ps3r3n1t33<<EOFMYSQL

# Update POSkey field (location + TransactionDate[excel format][no decimal] + checknumber)
	 UPDATE CardActivity_Live set POSkey = CONCAT_WS('', LocationID, Exceldate, CheckNo);

########### EMPTY THE 'squashed' TABLE to READY FOR RELOAD
TRUNCATE TABLE CardActivity_squashed;

############## SQUASH AND INSERT DATA FROM LIVE CardActivity ###############
INSERT INTO SRG_px.CardActivity_squashed
SELECT
DISTINCT(POSKey), LocationID, CardNumber, CardTemplate, TransactionDate,

SUM(LifetimeSpendAccrued),SUM(LifetimeSpendRedeemed),MAX(LifetimeSpendBalance),
SUM(3000BonusPointsAccrued),SUM(3000BonusPointsRedeemed),MAX(3000BonusPointsBalance),
SUM(CoffeesBoughtAccrued),SUM(CoffeesBoughtRedeemed),MAX(CoffeesBoughtBalance),
SUM(AddCoffeeAccrued),SUM(AddCoffeeRedeemed),MAX(AddCoffeeBalance),
SUM(HappyBellyCoffeeAccrued),SUM(HappyBellyCoffeeRedeemed),MAX(HappyBellyCoffeeBalance),
SUM(LTObucksAccrued),SUM(LTObucksRedeemed),MAX(LTObucksBalance),
SUM(CheckSubtotalAccrued),SUM(CheckSubtotalRedeemed),MAX(CheckSubtotalBalance),
SUM(DollarsSpentAccrued),SUM(DollarsSpentRedeemed),MAX(DollarsSpentBalance),
SUM(KidsMenuTrackingAccrued),SUM(KidsMenuTrackingRedeemed),MAX(KidsMenuTrackingBalance),
SUM(BeerTrackingAccrued),SUM(BeerTrackingRedeemed),MAX(BeerTrackingBalance),
SUM(SushiTrackingAccrued),SUM(SushiTrackingRedeemed),MAX(SushiTrackingBalance),
SUM(WineTrackingAccrued),SUM(WineTrackingRedeemed),MAX(WineTrackingBalance),
SUM(StoreRegisteredAccrued),SUM(StoreRegisteredRedeemed),MAX(StoreRegisteredBalance),
SUM(SereniteePointsAccrued),SUM(SereniteePointsRedeemed),MAX(SereniteePointsBalance),
SUM(LifetimePointsAccrued),SUM(LifetimePointsRedeemed),MAX(LifetimePointsBalance),
SUM(100PointsIncrementAccrued),SUM(100PointsIncrementRedeemed),MAX(100PointsIncrementBalance),
SUM(FreeAppAccrued),SUM(FreeAppRedeemed),MAX(FreeAppBalance),
SUM(FreeEntreeAccrued),SUM(FreeEntreeRedeemed),MAX(FreeEntreeBalance),
SUM(FreeDessertAccrued),SUM(FreeDessertRedeemed),MAX(FreeDessertBalance),
SUM(FreePizzaAccrued),SUM(FreePizzaRedeemed),MAX(FreePizzaBalance),
SUM(FreeSushiAccrued),SUM(FreeSushiRedeemed),MAX(FreeSushiBalance),
SUM(5500PointsAccrued),SUM(5500PointsRedeemed),MAX(5500PointsBalance),
SUM(3500PointsAccrued),SUM(3500PointsRedeemed),MAX(3500PointsBalance),
SUM(2500PointsAccrued),SUM(2500PointsRedeemed),MAX(2500PointsBalance),
SUM(1Kpts5bksAccrued),SUM(1Kpts5bksRedeemed),MAX(1Kpts5bksBalance), 
MAX(VisitsAccrued),SUM(VisitsRedeemed),MAX(VisitsBalance), 
SUM(TWKTripAccrued),SUM(TWKTripRedeemed),MAX(TWKTripBalance),
SUM(SpotTripAccrued),SUM(SpotTripRedeemed),MAX(SpotTripBalance),
SUM(MagsTripAccrued),SUM(MagsTripRedeemed),MAX(MagsTripBalance),
SUM(OpusTripAccrued),SUM(OpusTripRedeemed),MAX(OpusTripBalance),
SUM(WalnutTripAccrued),SUM(WalnutTripRedeemed),MAX(WalnutTripBalance),
SUM(HaleTripAccrued),SUM(HaleTripRedeemed),MAX(HaleTripBalance),
SUM(CalasTripAccrued),SUM(CalasTripRedeemed),MAX(CalasTripBalance),
SUM(LatTripAccrued),SUM(LatTripRedeemed),MAX(LatTripBalance),
SUM(HBTripAccrued),SUM(HBTripRedeemed),MAX(HBTripBalance),
SUM(SereniteebucksAccrued),SUM(SereniteebucksRedeemed),MAX(SereniteebucksBalance),
SUM(BandCompbucksAccrued),SUM(BandCompbucksRedeemed),MAX(BandCompbucksBalance),
SUM(GreenDollarsAccrued),SUM(GreenDollarsRedeemed),MAX(GreenDollarsBalance),
SUM(GreenLATAppAccrued),SUM(GreenLATAppRedeemed),MAX(GreenLATAppBalance),
SUM(GreenALCAppAccrued),SUM(GreenALCAppRedeemed),MAX(GreenALCAppBalance),
SUM(GreenOPUSAppAccrued),SUM(GreenOPUSAppRedeemed),MAX(GreenOPUSAppBalance),
SUM(GreenCALAppAccrued),SUM(GreenCALAppRedeemed),MAX(GreenCALAppBalance),
SUM(GreenSPOTAppAccrued),SUM(GreenSPOTAppRedeemed),MAX(GreenSPOTAppBalance),
SUM(GreenHALEAppAccrued),SUM(GreenHALEAppRedeemed),MAX(GreenHALEAppBalance),
SUM(GreenWINCAppAccrued),SUM(GreenWINCAppRedeemed),MAX(GreenWINCAppBalance),
SUM(GreenMAGsAppAccrued),SUM(GreenMAGsAppRedeemed),MAX(GreenMAGsAppBalance),
SUM(GreenWALAppAccrued),SUM(GreenWALAppRedeemed),MAX(GreenWALAppBalance),
SUM(CompbucksAccrued),SUM(CompbucksRedeemed),MAX(CompbucksBalance),
SUM(SereniteeGiftCardAccrued),SUM(SereniteeGiftCardRedeemed),MAX(SereniteeGiftCardBalance),
SUM(NewsletterAccrued),SUM(NewsletterRedeemed),MAX(NewsletterBalance),
SUM(SVDiscountTrackingAccrued),SUM(SVDiscountTrackingRedeemed),MAX(SVDiscountTrackingBalance)

FROM CardActivity_Live

WHERE LocationID IS NOT NULL AND CardTemplate = 'Serenitee Loyalty'  AND CheckNo <> '9999999'
AND (TransactionType = 'Accrual / Redemption' OR TransactionType = 'Activate')

GROUP by POSKey, LocationID, CardNumber, CardTemplate, TransactionDate;

###################### DELETE RECORDS CAUSING DUPE POSkey-s #####

DELETE CardActivity_squashed 
FROM CardActivity_squashed 
INNER JOIN (
	SELECT MAX(CardNumber) as MainCardNumber, POSkey
		FROM CardActivity_squashed
			GROUP BY POSkey
			HAVING COUNT(*) > 1) duplic on duplic.POSkey = CardActivity_squashed.POSkey
		WHERE CardActivity_squashed.CardNumber < duplic.MainCardNumber;

# QUIT MYSQL
EOFMYSQL

# uber join needs headers

# cat /home/srg/db_files/headers/px.ca.squashed.headers.csv /home/srg/db_files/px.ca.squashed.csv > /home/srg/db_files/outfiles/px.ca.squashed.wheaders.csv


#TURN ECHO ON AGAIN
set -x

# DELETE THE WORKING COPY OF CardActivity and px.ca.squashed
rm -f /home/srg/db_files/CardActivity.csv
#rm -f /home/srg/db_files/px.ca.squashed.csv

# ARCHIVE THE DOWNLOADED PAYTRONIX FILES
mv /home/srg/db_files/incoming/px/*.csv /home/srg/db_files/incoming/px/archive




 


