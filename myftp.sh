#!/bin/sh 
# ftp script 
# ftpauto 
USER=`whoami` 
MYDATE=`date +%d/%m/%Y` 
THIS_HOST=`hostname -s` 
tracelog=/tmp/tracelog.$$ 

while :  
do 
  # loop forever 
  tput clear 
  cat <<MAYDAY 
  User: $USER             $MYDATE This host:     $THIS_HOST 
                   FTP RETRIEVAL SCRIPT 
                   ==================== 
                 Using the ID of anonymous 
  MAYDAY 
  echo -n "Enter the host you wish to access :" 
  read DEST_HOST 
  # is a hostname entered ??? 
  if [ "$DEST_HOST" = "" ] 
  then 
    echo "No destination host entered" >&2 
    exit 1 
  fi 
  # can we see the host ??? 
  echo "Wait..seeing if $DEST_HOST is out there.." 
  # use traceroute to test connectivity 
  traceroute $DEST_HOST > $tracelog 2>&1 

  if grep "unknown host" $tracelog >/dev/null 2> then 
    echo "Could not locate $DEST_HOST" 
    echo -n "Try another host? [y..n] :" 
    read ANS 
    case $ANS in 
    y|Y) ;; 
    *) break;; # get out of the forever loop 
    esac 
  else 
    echo "$THIS_HOST can see $DEST_HOST" 
    break # get out of the forever loop 
  fi 
done 

# the default is binary 
echo "What type of transfer /receive mode ?" 
echo " 1 : Binary" 
echo " 2 : ASCII" 
echo -n -e "\fYour choice [1..2] [1]:" 
read $TYPE 
case $TYPE in 
1) MODE=binary 
  ;; 
2) MODE=ascii 
  ;; 
*) MODE=binary 
  ;; 
esac 

echo -n " Enter the name of the file to retrieve :" 
read FILENAME 
if [ "$FILENAME" = "" ]; then 
  echo "No filename entered" >&2 
  exit 1 
fi 

# default is tmp 
echo -n -e "\f Enter the directory where the file is to be placed[/tmp] :" 
read DIREC 
cd $DIREC >/dev/null 2>&1 
# if we cannot cd to the directory then use tmp 
if [ "$DIREC" = "" ]; then 
  DIREC=/tmp 
fi 

if[$?!=0] 
then 
  echo "$DIREC does not exist placing the file in /tmp anyway" 
  DIREC=/tmp 
fi 

echo -e "\t\tHost to connect is: $DEST_HOST" 
echo -e "\t\tFile to get is : $FILENAME" 
echo -e "\t\tMode to use is : $MODE" 
echo -e "\t\tFile to be put in : $DIREC/$FILENAME.ftp" 
echo -e -n "\t\tReady to get file ‘y’ or ‘q’ to quit? [y..q] :" 
read ANS 
case $ANS in 
Y|y);; 
q|Q) exit 0;; 
*) exit 0 ;; 
esac 
echo "ftp.." 
ftp -i -n $DEST_HOST<<FTPIT 
user anonymous $USER@$THISHOST 
$MODE 
get $FILENAME $DIREC/$FILENAME.ftp 
quit 
FTPIT 
if [ -s $DIREC/$FILENAME.ftp ] 
then 
  echo "File is down" 
else 
  echo "Unable to locate $FILENAME.ftp" 
fi
