#!/bin/bash

CMD=`basename $0`
printusage () {
	cat <<!EOF
USAGE: ${CMD} [-n <enb>] [-s <sam> [-f <snapshotFileName>]                              
EXAMPLE1: ${CMD} -n 1 #for NRT1 enb1
EXAMPLE2: ${CMD} -s 2 #for NRT2

# For SPRINT NRT Lab Use ONLY.
# This tool retrieves either:
#    for given <enb>, the current database.xml and names it <enb>.<timestamp>.xml
# or for given <sam>, the latest snapshot from the given <sam>
#                  or given <snapshotFileName> if -f option is used
# To be run on LINUX box 10.155.243.215
!EOF
}

if [ ${#} = 0 ]
then
	printusage; exit 1
fi

# For Sprint NRT
DIR="/Users/rahmed/Desktop"
CELL_DATA="$DIR/eNBdata"

if [ ! -s $CELL_DATA ]
then
	echo "Cell Data file $CELL_DATA does not exist, creating one..."
	cat <<!EOFx > $DIR/eNBdata

cell401;localhost
cell402;localhost

!EOFx
fi
#NRT1;enb1;NRT1 enb1;;61.54.0.2;;
#NRT1;enb2;NRT1 enb2;;61.54.0.10;;
#NRT2;enb3;NRT2 enb3;;61.54.0.6;;
#NRT2;enb4;NRT2 enb4;;61.54.0.14;;

TMP0="./tmp0.$CMD.$$"
TMP1="./tmp1.$CMD.$$"
TMP2="./tmp2.$CMD.$$"
TMP3="./tmp3.$CMD.$$"
trap "rm -f ${TMP0} ${TMP1} ${TMP2} ${TMP3}" 0 1 2 3 4 15

for i in ${*:-}
do
	case $1 in
	-s)	if [ "$2" = "" ]
		then
			printusage; exit 3
		fi
		case $2 in
		1)	SAMAIP=10.86.244.17;
			SAMSIP=10.86.244.28;
			;;
		2)	SAMAIP=10.86.244.39;
			SAMSIP=10.86.244.40;
		        ;;
		*)	echo "$0: with -s option, only 1 or 2 allowed";
			exit 4 ;;
		esac

   		/usr/bin/ping $SAMAIP -c 1 > /dev/null 2>&1
		if [ $? = 0 ]
		then
			SAMIP=$SAMAIP
		else
   			/usr/bin/ping $SAMSIP -c 1 > /dev/null 2>&1
			if [ $? != 0 ]
			then
				echo "Neither SAMs $SAMAIP or $SAMSIP are pinging"; exit 4
			fi
			SAMIP=$SAMSIP
		fi
		shift 2 ;;

	-f)	if [ "$2" = "" ]
		then
			printusage; exit 3
		fi
		if [ "$SAMIP" = "" ]
		then
			echo "$0: -f option to be used with -s option"
			printusage; exit 3
		fi
		SNAPFILE=$2
		echo retrieving $SNAPFILE ...
		shift 2 ;;

	-n)	if [ "$2" = "" ]
		then
			printusage; exit 3
		fi
		cell=cell$2
		IPLIST=`awk -F ";" '$2 == cell { print $2 }' cell=$cell $CELL_DATA`
                print IPLIST
		shift 2 ;;
	-i)	if [ "$2" = "" ]
		then
			printusage; exit 3
		fi
		IPLIST=$2
		shift 2 ;;
	-v)	VERBOSE="yes"; shift ;;
	--)	shift; break ;;
	esac
done

### SAM case

if [ "$SAMIP" != "" ]
then
	if [ "$SNAPFILE" = "" ]
	then
		cat <<!EOF0 > $TMP0
#!/usr/bin/expect
spawn -noecho sftp samadmin@$SAMIP
expect {
"(yes/no)?" { send "yes\r"
        expect "Password:"
        send "newsys\r"
}
"Password:" { send "newsys\r" }}
expect "sftp> "
send "cd /opt/5620sam/server/nms/activation/snapshot_export\r"
expect "sftp>"
send "ls -rt\r"
expect "sftp>"
send "quit\r"
!EOF0
		chmod +x $TMP0
		SNAPFILE=`$TMP0 | grep snapshot | tail -1`
	fi	

	cat <<!EOF1 > $TMP1
#!/usr/bin/expect
spawn -noecho sftp samadmin@$SAMIP
expect {
"(yes/no)?" { send "yes\r"
        expect "Password:"
        send "newsys\r"
}
"Password:" { send "newsys\r" }}
expect "sftp> "
send "cd /opt/5620sam/server/nms/activation/snapshot_export\r"
expect "sftp>"
send "get $SNAPFILE\r"
expect "sftp>"
send "quit\r"
!EOF1

	chmod +x $TMP1
	$TMP1

	if [ ! -s $SNAPFILE ]
	then
		echo "$0: ERROR - unable to download $SNAPFILE"
		exit 5
	fi

	exit 0
fi


### ENB case

if [ "$cell" = "" ]
then
	printusage; exit 4
fi

if [ "$IPLIST" = "" ]
then
	echo eNodeB = $cell not found in $CELL_DATA
	exit 5
fi

for i in $IPLIST
do
	if [ -s $CELL_DATA ]
	then
		LINE=`awk -F ";" '$5 == IP { print }' IP=$i $CELL_DATA`
		CL=`echo $LINE | cut -f1 -d";"`
		ENB=`echo $LINE | cut -f2 -d";"`
		SITE=`echo $LINE | cut -f3 -d";"`
		CID=`echo $LINE | cut -f4 -d";"`
		IP=`echo $LINE | cut -f5 -d";"`
		FREQ=`echo $LINE | cut -f6 -d";"`
	else
		IP=$i
	fi
	TIME=`date +%y%m%d%H%M%S`

	/usr/bin/ping $IP -c 2 > /dev/null 2>&1
	if [ $? != 0 ]
	then
		echo "$ENB;$SITE $FREQ;$IP;N/R"
	else
		echo CL=$CL ENB=$ENB SITE=$SITE CID=$CID IP=$IP BAND=$FREQ

	cat <<!EOF2 > $TMP2
#!/usr/bin/expect
spawn -noecho ssh enb0dev@$IP
expect {
"(yes/no)?" { send "yes\r"
        expect "password:"
        send "Qwe*90op\r"
}
"password:" { send "Qwe*90op\r" }}
expect "> "
send "sh\r"
expect "eCCM-enb0dev-enb0dev>"
# Become ROOT to read database.xml file
send "su -\r"
expect "Password:"
send "#edcVfr4%t\r"
expect "eCCM-root-root>"
send "ls -l /data/db/active/mim \r"
expect "eCCM-root-root>"
send "cp /data/db/active/mim/database.xml /home/enb0xfer/$ENB.xml\r"
expect "eCCM-root-root>"
send "chmod 666 /home/enb0xfer/$ENB.xml\r"
expect "eCCM-root-root>"
send "exit\r"
expect "eCCM-enb0dev-enb0dev>"
send "exit\r"
expect "> "
send "exit\r"
!EOF2

	cat <<!EOF1 > $TMP1
#!/usr/bin/expect
spawn -noecho sftp enb0xfer@$IP
expect "password:"
send "&65UytJhg\r"
expect "sftp> "
send "get $ENB.xml\r"
expect "sftp> "
send "quit\r"
!EOF1

	chmod +x $TMP2 $TMP1
	if [ "$VERBOSE" = "yes" ]
	then
		$TMP2; $TMP1
	else
		($TMP2; $TMP1) | egrep "xml|^-"
	fi

	mv $ENB.xml $DIR/$ENB.$TIME.xml
	ls -l $DIR/$ENB.$TIME.xml
	fi
done

exit 0
