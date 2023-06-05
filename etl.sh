#!/bin/bash
#Name: Seth DeWalt
#Date: 12/10/2022
#Assignment: Semster Project

#Error Handling
set -o errexit
set -o pipefail


#Check parameters are correct
if (( $# != 3 )); then
    echo "Usage: $0 server userId file" ; exit 1
fi

#Declare Variables
server="$1"
userId="$2"
src_file_path="$3"
src_file_compressed="$(basename $src_file_path)"
src_file_extracted="" #will be overwritten
coder="Seth DeWalt"

function rm_temps() {
    read -p "Delete all files but reports? (Y/n): "
    if [[ $REPLY = [Yy] ]]; then
         #rm *.tmp
         rm -f *.bz2
         rm -f *.csv
         rm -f *.tmp
         
         echo "Deleted all files but reports"
         exit 0
             fi
}

#1) Import file from remote_srv folder and copy it
scp $userId@$server:$src_file_path remote_srv/
cp remote_srv/*.csv.bz2 .  #copying to current directory
printf "1) Importing testfile: $src_file_compressed -- complete\n"

# 2) Extract contents of downloaded file
bunzip2 $src_file_compressed # extracting file
src_file_extracted="${src_file_compressed%.*}" 
printf "2) Unzip file $src_file_extracted -- complete\n"

#3) remove the header from the file
tail -n +2 "$src_file_extracted" > "01_rm_header.tmp"
printf "3) Removed header from file -- complete\n"

#4) Convert all text to lower case
tr '[:upper:]' '[:lower:]' < "01_rm_header.tmp" > "02_conv_lower.tmp"
printf "4) Converted all text to lowercase -- complete\n"

#5) Converting gender column to match the standard
awk 'BEGIN {FS=","; OFS = ","} {
    if ($5=="1") {$5 = "f"; print}
    else if ($5=="0") {$5 = "m"; print}
    else if ($5=="male") {$5 = "m"; print}
    else if ($5=="female") {$5 = "f"; print}
    else {$5 = "u"; print}
 }' < "02_conv_lower.tmp" > "03_gender.tmp"
printf "5) Converted gender column to m/f/u standard -- complete\n"

#6) Filter out all records that do not contain state
    #printing files without state to exceptions to exceptions
awk 'BEGIN {FS=","; OFS = ","} {
    if ($12=="") {print}
    else if ($12=="NA") {print}
    if ($6=="") {print}
    }' < "03_gender.tmp" > "exceptions.csv"
    #deleting lines where match is found and moving to filtered states temp
awk 'NR==FNR{a[$0];next}!($0 in a)' exceptions.csv 03_gender.tmp > "04_filtered_states.tmp"
printf "6) Filtered out all records not containing a state -- complete\n"

#7) Removing dollar sign from file
tr -d '$' <  "04_filtered_states.tmp" > "05_filter_dollar_sign.tmp"
printf "7) Removing $ sign from purchase_amt field -- complete\n"

#8) Sorting transaction files
sort -k1 < 05_filter_dollar_sign.tmp > transaction.csv
printf "8) Sorting transaction file -- complete\n"

#9a) Creating summary from transactions.csv
awk 'BEGIN {FS=","; OFS = ","} {
    totals[$1]+=$6
    state[$1]=$12
    zip[$1]=$13
    lname[$1]=$3
    fname[$1]=$2
    }
    END { 
    for (i in totals) 
        {print i","state[i]","zip[i]","lname[i]","fname[i]","totals[i]} 
    }' < transaction.csv > 06_filter_dups.tmp
printf "9a) Generating a summary -- complete\n"

#9b) Sorting based on state, zip lastname and then firstname
sort -t ',' -k2,2 -rnk3,3 -k4,4 -k5,5 06_filter_dups.tmp > summary.csv
printf "9b) Sorting based on state, zip lastname and then firstname -- complete\n"

#10a) Creating Transaction report

#selecting data from transactions
awk -v _coder="$coder" 'BEGIN {FS=",";OFS","} {
    $12=toupper($12)
    trans[$12]+=1 }
END {
    for (i in trans)
        {printf  i","trans[i]"\n"}
}' < "transaction.csv" > 09_un-s-f_transactions.tmp

#sorting data
sort -t ',' -rnk2,2 -k1,1 09_un-s-f_transactions.tmp > 10_un-s-f_transactions.tmp

#printing filtered and sorted transactions into correct format
awk  -v _coder="$coder" 'BEGIN {FS=",";OFS","
    printf "%s %s\n", "Report by:", _coder
    printf "%s\n\n", "Transaction Count Report"
    printf "%-7s %s\n", "State", "Transaction Count"}
    {
        printf "%-7s %-7s\n", $1, $2}' < 10_un-s-f_transactions.tmp > transaction.rpt
printf "10a) Transaction report -- complete\n"

#10b) Creating Purchase report
awk -v _coder="$coder" 'BEGIN {FS=",";OFS","} {
    $12=toupper($12)
    $5=toupper($5)
    a[$12","$5]+=$6 }
END {
    for(i in a)
        {printf "%s,%.4f\n", i,a[i]}
    }' < "transaction.csv" > 07_un-s-f_purchases.tmp #un-s-f stands for unsorted and unformatted

#sorting raw purchases data
sort -t ',' -rnk3,3 -k1,1 -k2,2 07_un-s-f_purchases.tmp > 08_un-f_purchases.tmp

#printing filtered and sorted purchases into correct format
awk -v _coder="$coder" 'BEGIN {FS=",";OFS","
    printf "%s %s\n", "Report by:", _coder
    printf "%s\n\n", "Purchase Summary Report"
    printf "%-7s %-9s %s\n", "State", "Gender", "Report"}

    {printf "%-7s %-7s %10.2f\n", $1, $2, $3}' < 08_un-f_purchases.tmp > purchase.rpt

printf "10b) Purchase Report -- complete\n"
rm_temps
