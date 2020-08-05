###########################################################################
#                      Replication script ver.1.0.0                       #
###########################################################################
#                                                                         #
#          Copyright(c)2017 by parkbyunggyu. All right reserved.          #
#           If you have a some problem, please send me an email           #
#                        bkbspark0725@naver.com                           #
#               You must do not fix parameter's template                  #
#           If you do that, replication.sh occurs malfuction              #
#                                                                         #
#                           Apache License 2.0                            #
#                                                                         #
#Copyright 2017 parkbyunggyu                                              #
#                                                                         #
#Licensed under the Apache License, Version 2.0 (the "License");          #
#you may not use this file except in compliance with the License.	  #
#You may obtain a copy of the License at				  #
#									  #
#   http://www.apache.org/licenses/LICENSE-2.0				  #
#									  #
#Unless required by applicable law or agreed to in writing, software	  #
#distributed under the License is distributed on an "AS IS" BASIS,	  #
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. #
#See the License for the specific language governing permissions and	  #
#limitations under the License.						  #
###########################################################################

source ./parameter.sh
touch $LOG_FILE
printf "\n" &>>$LOG_FILE
echo "Master DB server inspection start!!!!!" &>>$LOG_FILE
function byebye()
{
	local LOG_FILE=$1
        echo "REPLICATION script will be stop. Bye Bye~^^*" &>>$LOG_FILE
        exit 0 
}
function hbabye()
{
	local UT=$1
	local TEMP3=$2
	local MST_REP_USR=$3
	local MST_DATA_DIR=$4
	local IP=$5
	local MST_SVC_USR=$6
	local LOG_FILE=$7
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	UT=`grep -n "host    replication     $MST_REP_USR          0.0.0.0/0               trust" $TEMP3/pg_hba.conf | cut -d':' -f1 |tail -n 1`
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	scp -P $SSHPORT $TEMP3/pg_hba.conf root@$IP:$MST_DATA_DIR/ &>/dev/null
	ssh -T -p $SSHPORT root@$IP chown $MST_SVC_USR. $MST_DATA_DIR
	rm -rf $TEMP3
	ssh -T -p $SSHPORT root@$IP su - $MST_SVC_USR -c \"pg_ctl -D $MST_DATA_DIR reload\" &>/dev/null
	byebye $LOG_FILE
}
function arch()
{
	local E=`ps -ef | grep post | grep startup` &>/dev/null
	local IP=$1
	local MST_SVC_USR=$2
	local MST_ARCH_DIR=$3
	local R=$4
	local TEMP=$5
	local SLV_ARCH_DIR=$6
	local SLV_SVC_USR=$7
	local LOG_FILE=$8
	R=$MST_ARCH_DIR/$R
	while
	[ "$E" == "" ]; 
	do
		T=`ssh -T -p $SSHPORT root@$IP su - $MST_SVC_USR -c \"find $MST_ARCH_DIR ! -newer $R &>/dev/null\"`
		T=`echo $T | sed "s/$TEMP/$(date +%Y%m%d%H%M%S)/"`
	        R=`echo $T | rev | cut -d' ' -f1 | rev`
	        ssh -T -p $SSHPORT root@$IP "chmod 700 -R $MST_ARCH_DIR"
	        Y=`echo "mv $T $MST_ARCH_DIR/$TEMP"`
	        ssh -T -p $SSHPORT root@$IP su - $MST_SVC_USR -c \" \`echo $Y\` &>/dev/null \"
		echo "Copy WAL file that created after pg_basebackup end, to restore directory" &>>$LOG_FILE
	    scp -P $SSHPORT root@$IP:$MST_ARCH_DIR/0000* $SLV_ARCH_DIR/  &>>$LOG_FILE
		ls $SLV_ARCH_DIR/* &>/dev/null
		if [ "$?" = "0" ]; then
			chmod -R 600 $SLV_ARCH_DIR/*
		fi
		chown -R $SLV_SVC_USR. $SLV_ARCH_DIR
		E=`ps -ef | grep post | grep startup` &>/dev/null
	done
        ssh -T -p $SSHPORT root@$IP su - $MST_SVC_USR -c \"mv $MST_ARCH_DIR/$TEMP/* $MST_ARCH_DIR/ &>/dev/null \"
        ssh -T -p $SSHPORT root@$IP "chmod \-R 600 $MST_ARCH_DIR/*"
        ssh -T -p $SSHPORT root@$IP "chmod 700 $MST_ARCH_DIR"
        ssh -T -p $SSHPORT root@$IP su - $MST_SVC_USR -c \"rm -rf $MST_ARCH_DIR/$TEMP/\"
}



#STEP.1 Master Inspection

#####################################################---VERIFICATION PART---#######################################################
printf "\n"
################################################---PING TEST TO MASTER OS SERVER---################################################

echo "Ping testing to Master OS Server..." &>>$LOG_FILE
ping $1 -c 4 &>>$LOG_FILE
if [ "$?" != "0" ];then
        echo "Can't not connect with MASTER OS server" &>>$LOG_FILE
        echo "Ping command dose not success.You should check the NETWORK." &>>$LOG_FILE
	byebye $LOG_FILE
else
        echo "Ping test is Success.....ok" &>>$LOG_FILE
fi
printf "\n" &>>$LOG_FILE

VER=`cat /etc/redhat-release | awk -F '.' '{print $1}' | awk '{print $NF}'`
if [ "$VER" = "7" ]; then
	NETTT=en
else
	NETTT=eth
fi
REAL_IP1=`ip addr | grep $NETTT | awk '{print $2}' | grep "/" | awk -F '/' '{print $1}' | grep -v $NETTT`
echo yes|sh "./sshUserSetup.sh" -user root -hosts "${REAL_IP1}:${SSHPORT} $2:${SSHPORT}" -noPromptPassphrase -advanced
echo yes|sh "./sshUserSetup.sh" -user $SLV_SVC_USR -hosts "${REAL_IP1}:${SSHPORT} $2:${SSHPORT}" -noPromptPassphrase -advanced

########################################---MASTER DB SERVER OWNER & AUTHORIZATION CHECK---#########################################

MST_SVC_USR=`ssh -T -p $SSHPORT root@$1 ls -ld $MST_DATA_DIR | awk '{print $3}'`
MST_ENGN_HOME=`ssh -T -p $SSHPORT root@$1 ps -ef | grep postgres | grep -w -v postgres: | grep bin |grep -w 1 | awk '{print $NF}'`
MST_ENGN_HOME=`echo ${MST_ENGN_HOME%/bin*}`

echo "Varification Master DBMS' owner and authorization..." &>>$LOG_FILE
BO=`ssh -T -p $SSHPORT root@$1 ls -ld $MST_ENGN_HOME/bin | awk '{print $3}'`
if [ "$BO" != "$MST_SVC_USR" ]; then
        echo "Master DBMS's engine \"bin\" directory owner is not \"$MST_SVC_USR\". " &>>$LOG_FILE
        echo "You should change to Master DBMS engine \"bin\" directory owner -> \"$MST_SVC_USR\". " &>>$LOG_FILE
	byebye $LOG_FILE
fi
DO=`ssh -T -p $SSHPORT root@$1 ls -ld $MST_DATA_DIR | awk '{print $3}'`
if [ "$DO" != "$MST_SVC_USR" ]; then
        echo "Master DBMS's DATA directory owner is not \"$MST_SVC_USR\". " &>>$LOG_FILE
        echo "You should change to Master DBMS's DATA directory owner -> \"$MST_SVC_USR\". " &>>$LOG_FILE
	byebye $LOG_FILE
fi
BG=`ssh -T -p $SSHPORT root@$1 ls -ld $MST_ENGN_HOME/bin | awk '{print $4}'`
BD=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c "groups" | sed -e "s/[[:space:]]/\n/g" | grep -w $BG`
TEMP=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c "groups"`
if [ "$BD" == "" ]; then
        echo "Master DBMS's DATA directory group is not \"$MST_SVC_USR's group\". " &>>$LOG_FILE
        echo "You should change to Master DBMS engine \"bin\" directory group one of them -> \"$TEMP\". " &>>$LOG_FILE
	byebye $LOG_FILE
fi
DG=`ssh -T -p $SSHPORT root@$1 ls -ld $MST_DATA_DIR | awk '{print $4}'`
BD=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c "groups" | sed -e "s/[[:space:]]/\n/g" | grep -w $DG`
TEMP=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c "groups"`
if [ "$BD" == "" ]; then
        echo "Master DBMS's DATA directory group is not \"$MST_SVC_USR's group\". " &>>$LOG_FILE
        echo "You should change to Master DBMS's DATA directory group one of them -> \"$TEMP\". " &>>$LOG_FILE
	byebye $LOG_FILE
fi
DATA_MODE=`ssh -T -p $SSHPORT root@$1 ls -ld $MST_DATA_DIR | awk '{print $1}'|cut -c 1-4`
if [ "$DATA_MODE" != "drwx" ]; then
        echo "You must change Master DATA directory Authorization to OWNER rwx (7)" &>>$LOG_FILE
        echo "There is Authorization --> \"$DATA_MODE\"" &>>$LOG_FILE
	byebye $LOG_FILE
fi
echo "Master's DBMS owner and authorization is well.....ok" &>>$LOG_FILE
printf "\n" &>>$LOG_FILE


###############################---------Master Database User enviorment configuration Check----------############################

echo "Master Database User enviorment configuration check..." &>>$LOG_FILE
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_ENGN_HOME/.bash_profile\" &>/dev/null
if [ $? -eq 0 ]; then
        B=y
else
        B=n
fi
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_ENGN_HOME/pg_env.sh\" &>/dev/null
if [ $? -eq 0 ]; then
        P1=y
else
        P1=n
fi
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_ENGN_HOME/pgplus_env.sh\" &>/dev/null
if [ $? -eq 0 ]; then
        P2=y
else
        P2=n
fi
if [ "$P2" == "n" ]; then
	MST_DB_NAME=postgres
elif [ "$P2" == "y" ]; then
	MST_DB_NAME=edb
fi
TEMP=/tmp/temp$(date +%Y%m%d%H%M%S)
mkdir $TEMP
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"mkdir $TEMP\"
if [ "$B" == "y" ]; then
        ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"cp .bash_profile $TEMP\"
        scp -P $SSHPORT root@$1:$TEMP/.bash_profile $TEMP &>/dev/null
        if [ "$P1" == "y" ]; then
cat >>$TEMP/.bash_profile << EOFF
source pg_env.sh
EOFF
        elif [ "$P2" == "y" ];then
cat >>$TEMP/.bash_profile << EOFF
source pgplus_env.sh
EOFF
        elif [ "$P1" == "n" -a "$P2" == "n" ]; then
cat >>$TEMP/.bash_profile << EOFF
export PATH=$MST_ENGN_HOME/bin:$PATH
export PGDATA=$MST_DATA_DIR
export PGDATABASE=$MST_DB_NAME
export PGUSER=$MST_DB_SPR_USR
export PGHOME=$MST_ENGN_HOME
export EDBHOME=$MST_ENGN_HOME
EOFF
        fi
elif [ "$B" == "n" ]; then
        cp /etc/skel/.* $TEMP/ &>/dev/null
        if [ "$P1" == "y" ]; then
cat >>$TEMP/.bash_profile << EOFF
source pg_env.sh
EOFF
        elif [ "$P2" == "y" ]; then
cat >>$TEMP/.bash_profile << EOFF
source pgplus_env.sh
EOFF
        elif [ "$P1" == "n" -a "$P2" == "n" ]; then
cat >>$TEMP/.bash_profile << EOFF
export PATH=$MST_ENGN_HOME/bin:$PATH
export PGDATA=$MST_DATA_DIR
export PGDATABASE=$MST_DB_NAME
export PGUSER=$MST_DB_SPR_USR
export PGHOME=$MST_ENGN_HOME
export EDBHOME=$MST_ENGN_HOME
EOFF
        fi
fi
scp -P $SSHPORT $TEMP/.bash_profile root@$1:$TEMP &>/dev/null
ssh -T -p $SSHPORT root@$1 "chown -R $MST_SVC_USR. $TEMP/.bash_profile"
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"mv $TEMP/.bash_profile ./ \"
rm -rf $TEMP
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"rm -rf $TEMP\"
echo "All enviroment configuration is well.....ok" &>>$LOG_FILE
printf "\n" &>>$LOG_FILE


###############################---------Master Database Status & MST_DATA_DIR parameter Check----------############################

echo "Master Database Server status check..." &>>$LOG_FILE
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"pg_ctl -D $MST_DATA_DIR status\" &>/dev/null
if [[ $? -eq 0 ]];then
	echo "Master Database is Operating. And parameter MST_DATA_DIR is OK.....ok" &>>$LOG_FILE
else
	echo "There is not Operating DB server( $MST_DATA_DIR ).....fail" &>>$LOG_FILE 
	echo "Check your MST_DATA_DIR parameter or Master DB sever's status." &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
	echo "You configuration is    : $MST_DATA_DIR" &>>$LOG_FILE
	byebye $LOG_FILE
fi
su - $SLV_SVC_USR -c "pg_ctl -D $OSLV_DATA_DIR status" &>/dev/null
if [[ $? -eq 0 ]];then
	OSLV="on"
	OSLV_PORT=`su - $SLV_SVC_USR -c "cat $OSLV_DATA_DIR/postmaster.pid" | head -n 4 | tail -n 1`
else
	OSLV="off"
fi
printf "\n" &>>$LOG_FILE




#STEP.2 Master Information Extract


#############################--------------------------- MST_PORT Extract -----------------------------#############################

echo "Master Database Server PORT check..." &>>$LOG_FILE
MST_PORT=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"cat $MST_DATA_DIR/postmaster.pid\" | head -n 4 | tail -n 1`
if [ $? -ne 0 ]; then
	echo "$MST_DATA_DIR/postmaster.pid is not exist please move postmaster.pid to $MST_DATA_DIR" &>>$LOG_FILE
	byebye $LOG_FILE
fi
if [ "$P1" == "n" -a "$P2" == "n" ]; then
	ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"echo 'export PGPORT='"$MST_PORT"'' \>\> .bash_profile\"
fi
echo "MST_PORT parameter is $MST_PORT.....ok" &>>$LOG_FILE

printf "\n" &>>$LOG_FILE


##############################---------Resistration replication user to Master's pg_hba.conf----------###########################

echo "Copy pg_hba.conf from Master server for Registraton replication user..." &>>$LOG_FILE
TEMP3=/tmp/temp3$(date +%Y%m%d%H%M%S)
mkdir $TEMP3
scp -P $SSHPORT root@$1:$MST_DATA_DIR/pg_hba.conf $TEMP3 &>/dev/null
UT=`grep -n "####################---bkbspark replication-start---######################" $TEMP3/pg_hba.conf | cut -d':' -f1`
if [ "$UT" == "" ]; then
	UT=0
elif [ $UT -gt 0 ]; then
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
	sed -i ''$UT'd' $TEMP3/pg_hba.conf
fi
UT=`grep -n "# TYPE  DATABASE        USER            ADDRESS                 METHOD" $TEMP3/pg_hba.conf | cut -d':' -f1`
UT=`expr $UT \+ 1`
sed -i ''$UT' i\local   all             '$MST_DB_SPR_USR'                                  trust\nhost    all             '$MST_REP_USR'         0.0.0.0/0               trust' $TEMP3/pg_hba.conf
cat >>$TEMP3/pg_hba.conf << EOFF
host    replication     $MST_REP_USR          0.0.0.0/0               trust
host    replication     $MST_REP_USR          ::1/128                 trust
EOFF
scp -P $SSHPORT $TEMP3/pg_hba.conf root@$1:$MST_DATA_DIR/ &>/dev/null
ssh -T -p $SSHPORT root@$1 "chown $MST_SVC_USR. $MST_DATA_DIR"
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"pg_ctl -D $MST_DATA_DIR reload\" &>/dev/null
if [[ $? -eq 0 ]];then
        echo "Registration for replication user success in Master's pg_hba.conf.....ok" &>>$LOG_FILE
else
        echo "Registration for replication user failed in Master's pg_hba.conf.....fail" &>>$LOG_FILE
        echo "You must check Master DB server status of Master DBserver's pg_hba.conf file" &>>$LOG_FILE
	hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
fi
printf "\n" &>>$LOG_FILE


#####################################--------------Create replication User---------------#######################################

echo "Create DB replication User..." &>>$LOG_FILE
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"createuser -l --replication -p $MST_PORT -U $MST_DB_SPR_USR $MST_REP_USR\" &>>$LOG_FILE
if [[ $? -eq 0 ]];then
    echo "Create New Replication DB user OK.....ok" &>>$LOG_FILE
	ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -p $MST_PORT -U $MST_DB_SPR_USR -c "'alter user $MST_REP_USR password '\''edb'\'';'"\" &>/dev/null
else
    echo "There is Imossible Create replication user....." &>>$LOG_FILE
	ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -p $MST_PORT -U $MST_DB_SPR_USR -c "'alter user $MST_REP_USR with replication login;'"\" &>/dev/null 
	if [ $? -ne 0 ]; then
		echo "There is impossible create user as superuser please check your DB super user parameter \"MST_DB_SPR_USR\" in parameter.sh.....fail" &>>$LOG_FILE
		hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
	fi
	ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -p $MST_PORT -U $MST_DB_SPR_USR -c "'alter user $MST_REP_USR password '\''$MST_REP_PWD'\'';'"\" &>/dev/null
	if [ $? -ne 0 ]; then
		echo "There is impossible create user as superuser please check your DB super user parameter \"MST_DB_SPR_USR\" in parameter.sh.....fail" &>>$LOG_FILE
		hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
	fi
	echo "But replication user is already exsist.....ok" &>>$LOG_FILE
fi
HS=`ssh -p $SSHPORT root@$1 su - $MST_SVC_USR -c "psql\ -t\ -c\ \"show\ hot_standby\"" | head -n 1 | sed 's/ //g'`
AM=`ssh -p $SSHPORT root@$1 su - $MST_SVC_USR -c "psql\ -t\ -c\ \"show\ archive_mode\"" | head -n 1 | sed 's/ //g'`
if [ "$HS" == "off" ]; then
        echo "The hot_standby parameter is set to off in the master database. It must be set to on to enable replication.....fail" &>>$LOG_FILE
        byebye $LOG_FILE
fi
if [ "$AM" == "off" ]; then
        echo "The archive_mode parameter is set to off in the master database. It must be set to on to enable replication.....fail" &>>$LOG_FILE
        byebye $LOG_FILE
fi
printf "\n" &>>$LOG_FILE


#####################################-------------DB connection verification------------#######################################

echo "Testing connect to DB server...." &>>$LOG_FILE
VRSN=`su - $SLV_SVC_USR -c "psql -V"|awk '{print $NF}'|awk -F '.' '{print $1}'`
if [ "9" -gt "$VRSN" ]; then
	REXL=xlog
	LOGD=pg_log
else
	REXL=wal
	LOGD=log
fi
su - $SLV_SVC_USR -c "psql -U $MST_REP_USR -h $1 -p $MST_PORT -c 'select version();'&>/dev/null"
if [[ $? -ne 0 ]];then
        echo "Can't not connect with MASTER DBserver" &>>$LOG_FILE
        echo "There is four reason" &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
        echo "1. First. OS Firewall or Port exception is not considered" &>>$LOG_FILE
        echo "2. Secound. Maybe listen_addresses parameter in \"postgresql.conf\" dose not allowed to this server" &>>$LOG_FILE
        echo "3. Third. Replication User \"$REP_USER\" is not allowed connection check your Master \"pg_hba.conf\" file" &>>$LOG_FILE
        echo "4. Last. Check your Database Port number. And fix 188 line replication.sh script" &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
        echo "You should think Above reason." &>>$LOG_FILE
	hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
else
        echo "Connection DB server using "psql" is success.....ok" &>>$LOG_FILE
fi
printf "\n" &>>$LOG_FILE


########################################---------MST_WAL_DIR parameter Extract----------########################################

echo "Master Database Server's WAL directory check..." &>>$LOG_FILE
W=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_DATA_DIR/pg_${REXL} \" |cut -c 1`
if [ "$W" == "d" ]; then
        MST_WAL_DIR=`ssh -T -p $SSHPORT root@$1 su - $MST_SVS_USR -c \"cd $MST_DATA_DIR/pg_${REXL} \&\& pwd \"`
        echo "Master WAL is Directory \"$MST_WAL_DIR\".....ok" &>>$LOG_FILE
	WS=1
elif [ "$W" == "l" ]; then
        MST_WAL_DIR=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_DATA_DIR/pg_${REXL}\" | awk '{print $11}'`
        echo "Master WAL is Link file \"pg_${REXL} -> $MST_WAL_DIR\".....ok" &>>$LOG_FILE
else
        echo "Can't find WAL directory, You should check Master's WAL directory is really exisit." &>>$LOG_FILE
	hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
fi
printf "\n" &>>$LOG_FILE


##############################################---------MST_LOG_DIR parameter Extract----------##################################################

echo "Master Database Server's LOG directory check..." &>>$LOG_FILE
C=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -U $MST_DB_SPR_USR -t -c \'show logging_collector\;\' \" |cut -c 2-;`
L=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -U $MST_DB_SPR_USR -t -c \'show log_directory\;\' \" |cut -c 2-;`
if [ "$C" == "on" ]; then
        if [ "$L" == "$LOGD" ]; then
                LL=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_DATA_DIR/$LOGD \" |cut -c 1`
                if [ "$LL" == "d" ]; then
                        MST_LOG_DIR="$MST_DATA_DIR/$L"
                        echo "Master LOG is Directory file $MST_LOG_DIR.....ok" &>>$LOG_FILE
                elif [ "$LL" == "l" ]; then
                        MST_LOG_DIR=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"ls -ld $MST_DATA_DIR/$LOGD\" | awk '{print $11}'`
                        echo "Master LOG is Link file \"$LOGD -> $MST_LOG_DIR\".....ok" &>>$LOG_FILE
                else
                        echo "LOG directory is NOT exist Check your Master DB server's LOG directory" &>>$LOG_FILE
			hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
                fi
        else
                MST_LOG_DIR=$L
                echo "Master LOG is Link file \"$LOGD -> $MST_LOG_DIR\".....ok" &>>$LOG_FILE
        fi
elif [ "$C" == "off" ]; then
        MST_LOG_DIR=off
        echo "Master DB server's logging_collector is off.....ok" &>>$LOG_FILE
fi

printf "\n" &>>$LOG_FILE


#########################################---------ARCHIVE DIRECTORY Check---------####################################################
echo "Master Database Server's ARCHIVE directory check..." &>>$LOG_FILE
C=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -U $MST_DB_SPR_USR -t -c \'show archive_mode\;\' \" |cut -c 2-;`
L=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"psql -U $MST_DB_SPR_USR -t -c \'show archive_command\;\' \" |cut -c 2-;`
if [ "$C" == "on" ]; then
        D=`echo ${L##*cp %p}`
        if [ "$D" == "$L" ]; then
                MST_ARCH_DIR=command
                echo "Master Archive mode is \"on\" but it is not archiving." &>>$LOG_FILE
                echo "Because Archive command is \"$L\".....ok" &>>$LOG_FILE
        else
                L=`echo ${D%%&&*}`
                L=`echo ${L%% *}`
                L=`echo ${L%/*}`
                if [ "$D" != "/" ]; then
                        MST_ARCH_DIR=$L
                        echo "Master DB server's ARCHIVE directoy is \"$L\".....ok" &>>$LOG_FILE
                fi
        fi
elif [ "$C" == "off" ]; then
        MST_ARCH_DIR=off
        echo "Master DB server's archive_mode is off.....ok" &>>$LOG_FILE
fi


printf "\n" &>>$LOG_FILE


#####################################---------MASTER TABLESPACE MATCHED VERIFICATION---------################################################

if [ "$MSTSLVEQ" == "n" ]; then
	echo "Tablespace list Parameter matched with Master DB server check..." &>>$LOG_FILE
	numb=1
	DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh | sed -e 's;^.*=;;'`
	while [ "$DIR_NAME" != "#######################------TBS list START-------#######################" ]
	do
	        numb=`expr $numb \+ 1`
	        DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh`
	done
	numb=`expr $numb \+ 1`
	DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh | sed -e 's;^.*=;;'`
	RC=0
	while [ "$DIR_NAME" != "#######################-------TBS list END--------#######################" ]
	do
	        DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh`
		if [ "$DIR_NAME" != "#######################-------TBS list END--------#######################" ]; then
			L=`expr length "$DIR_NAME"`
		        if [ $L -gt 0 ]; then
	                        eval declare p${numb}=${DIR_NAME%%=*}
	                        eval declare y${numb}=${DIR_NAME##*=}
				TEMP2=temp2$(date +%Y%m%d%H%M%S).sh
	                        touch ./$TEMP2.sh
	                        echo "G=0" >> $TEMP2.sh
	                        ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"oid2name -s -p $MST_PORT\" |awk '{print "if [ \"$p'$numb'\" == \""$2"\" ]; then G=`expr $G \\+ 1`; fi"}'| grep -v pg_default | grep -v pg_global | tail -n +4 >> ./$TEMP2.sh
	                        source ./$TEMP2.sh
	                        if [ "$G" -ne 1 ]; then
	                                echo "You maybe set TBS parameter more than Master DB server's TBS counts" &>>$LOG_FILE
	                                echo "Or you may set TBS parameter wrong match with Master's TBS - Suspicious parameter set : \"${DIR_NAME%%=*}\"" &>>$LOG_FILE
	                                printf "\n" &>>$LOG_FILE
	                                echo "Please Check TBS list in parameter.sh" &>>$LOG_FILE
					hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
	                        fi
	                        rm -rf ./$TEMP2.sh
	                        RC=`expr $RC \+ 1`
	                        eval declare t${RC}=\$p$numb
	                        eval declare r${RC}=\$y$numb
	                        numbp=$numb
			fi
		fi
	        numb=`expr $numb \+ 1`
	done
	RR=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"oid2name -s -p $MST_PORT\" |awk '{print $2}'| grep -v pg_default | grep -v pg_global | tail -n +4 | grep -c ''`
	if [ $RR -gt $RC ]; then
		echo "You maybe set TBS parameter less than Master DB server's TBS counts" &>>$LOG_FILE
		printf "\n" &>>$LOG_FILE
		echo "Please Check TBS list in parameter.sh" &>>$LOG_FILE
		hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
	fi
	for ((i=1;i<=$RC;i++)); 
	do
	CC=0
		for ((j=1;j<=$RC;j++));
		do
			if [ "`eval echo '$t'${i}`" == "`eval echo '$t'${j}`" ]; then
				CC=`expr $CC \+ 1`
			fi
			if [ $CC -ge 2 ]; then
				eval echo "You should check TBS parameter, maybe overlap \( \$t${i} \) tablespace values "
        	                echo "Please Check TBS list in parameter.sh" &>>$LOG_FILE
				hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
			fi
		done 
	done
	for ((i=1;i<=$RC;i++)); 
	do
	CC=0
		for ((j=1;j<=$RC;j++));
		do
			if [ "`eval echo '$r'${i}`" == "`eval echo '$r'${j}`" ]; then
				CC=`expr $CC \+ 1`
			fi
			if [ $CC -ge 2 ]; then
				eval echo "You should check TBS parameter, maybe overlap \( \$r${i} \) tablespace values "
	                        echo "Please Check TBS list in parameter.sh" &>>$LOG_FILE
				hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
			fi
		done 
	done
	echo "All matched TBS list with Master's TBS.....ok" &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
fi


###############################---------BACKUP check---------#####################################

BACKUP_DIR=$BACKUP_DIR/BACKUP$(date +%Y%m%d%H%M%S)
if [ $BACKUP == y ];then
	echo "Parameter BACKUP's value is \"y\" - OLD Slave data will be Backuped to $BACKUP_DIR" &>>$LOG_FILE
elif [ $BACKUP == n ];then
	echo "Parameter BACKUP's value is \"n\" - OLD Slave data will be Removed" &>>$LOG_FILE
else
        echo "You must check the BACKUP parameter, It is not \"y\" or \"n\"." &>>$LOG_FILE
	hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
fi


#############################---------MSTSLVEQ check---------###################################

if [ "$MSTSLVEQ" == "y" ]; then
	echo "Parameter MSTSVLEQ's value is \"y\" - New Slave' DB structure will be same with Master DB server." &>>$LOG_FILE
	printf "\n"
	SLV_DATA_DIR=$MST_DATA_DIR
	SLV_WAL_DIR=$MST_WAL_DIR
        SLV_PORT=$MST_PORT
	SLV_ARCH_DIR=$MST_ARCH_DIR
	SLV_LOG_DIR=$MST_LOG_DIR
elif [ "$MSTSLVEQ" == "n" ]; then
	echo "Parameter MSTSVLEQ's value is \"n\" - New Slave' DB structure will be diffirent with Master DB server." &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
else
        echo "You must check the MSTSLVEQ parameter, It is not \"y\" or \"n\"." &>>$LOG_FILE
	hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
fi


###############################################################################################



#STEP.3 Master & Slave information Print

echo "Master Inspect is END & Starting SLAVE replication to  below list!!!..." &>>$LOG_FILE
printf "\n" &>>$LOG_FILE
printf "\n" &>>$LOG_FILE
echo "------------------------MASTER------------------------" &>>$LOG_FILE
echo "Master OS DB user : $MST_SVC_USR" &>>$LOG_FILE
echo "Master Engine DIR : $MST_ENGN_HOME" &>>$LOG_FILE
echo "Master Port Number: $MST_PORT" &>>$LOG_FILE
echo "Master DATA DIR   : $MST_DATA_DIR" &>>$LOG_FILE
echo "Master WAL DIR    : $MST_WAL_DIR" &>>$LOG_FILE
echo "Master Archive DIR: $MST_ARCH_DIR" &>>$LOG_FILE
echo "Master LOG DIR    : $MST_LOG_DIR" &>>$LOG_FILE
echo "------------------------------------------------------" &>>$LOG_FILE
printf "\n" &>>$LOG_FILE
echo "-------------------------SLAVE------------------------" &>>$LOG_FILE
echo "SLAVE OS DB user  : $SLV_SVC_USR" &>>$LOG_FILE
echo "SLAVE Port Number : $SLV_PORT" &>>$LOG_FILE
echo "SLAVE DATA DIR    : $SLV_DATA_DIR" &>>$LOG_FILE
echo "SLAVE WAL DIR     : $SLV_WAL_DIR" &>>$LOG_FILE
echo "SLAVE ARCHIVE DIR : $SLV_ARCH_DIR" &>>$LOG_FILE
echo "SLAVE LOG DIR     : $SLV_LOG_DIR" &>>$LOG_FILE
echo "------------------------------------------------------" &>>$LOG_FILE
printf "\n" &>>$LOG_FILE
echo "-----------------------OLD SLAVE----------------------" &>>$LOG_FILE
echo "OLD SLAVE Port Number : $OSLV_PORT" &>>$LOG_FILE
echo "OLD SLAVE DATA DIR    : $OSLV_DATA_DIR" &>>$LOG_FILE
echo "OLD SLAVE WAL DIR     : $OSLV_WAL_DIR" &>>$LOG_FILE
echo "OLD SLAVE ARCHIVE DIR : $OSLV_ARCH_DIR" &>>$LOG_FILE
echo "OLD SLAVE LOG DIR     : $OSLV_LOG_DIR" &>>$LOG_FILE
echo "------------------------------------------------------" &>>$LOG_FILE
printf "\n" &>>$LOG_FILE
echo "Replication start..." &>>$LOG_FILE
printf "\n" &>>$LOG_FILE


#---------------------------------------------------  Replication Start  --------------------------------------------------#



#STEP.4 Old Slave Backup

if [ "$OSLV" == "on" ]; then
	echo "OLD SLAVE DATA is shutdown..." &>>$LOG_FILE
	su - $SLV_SVC_USR -c "pg_ctl -D $OSLV_DATA_DIR stop -mf -w" $>/dev/null
fi
if [ "$BACKUP" == "y" ];then
	if [ -d "$BACKUP_DIR/DATA/" ]; then
	        if [ "`du -sk $BACKUP_DIR/DATA/ | awk '{print $1}'`" -gt "4" ];then
			echo "Sorry You Must empty DATA Backup Directory." &>>$LOG_FILE
			hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
		fi
	else
		su - $SLV_SVC_USR -c "mkdir -p $BACKUP_DIR/DATA"
	fi

	if [ -d "$BACKUP_DIR/TBS/" ]; then
		if [ "`du -sk $BACKUP_DIR/TBS/ | awk '{print $1}'`" -gt "4" ];then
                        echo "Sorry You Must empty TBS Backup Directory." &>>$LOG_FILE
			hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
		fi
	else
		su - $SLV_SVC_USR -c "mkdir -p $BACKUP_DIR/TBS"
	fi

	if [ -d "$BACKUP_DIR/WAL/" ]; then
		if [ "`du -sk $BACKUP_DIR/WAL/ | awk '{print $1}'`" -gt "4" ];then
                        echo "Sorry You Must empty WAL Backup Directory." &>>$LOG_FILE
			hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
		fi
	else
		su - $SLV_SVC_USR -c "mkdir -p $BACKUP_DIR/WAL"
	fi

	if [ -d "$BACKUP_DIR/ARCH/" ]; then
		if [ "`du -sk $BACKUP_DIR/ARCH/ | awk '{print $1}'`" -gt "4" ];then
                        echo "Sorry You Must empty ARCH Backup Directory." &>>$LOG_FILE
			hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
		fi
	else
		su - $SLV_SVC_USR -c "mkdir -p $BACKUP_DIR/ARCH"
	fi

	if [ -d "$BACKUP_DIR/LOG/" ]; then
		if [ "`du -sk $BACKUP_DIR/LOG/ | awk '{print $1}'`" -gt "4" ];then
                        echo "Sorry You Must empty LOG Backup Directory." &>>$LOG_FILE
			hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
		fi
	else
		su - $SLV_SVC_USR -c "mkdir -p $BACKUP_DIR/LOG"
	fi

	SIZE=`df -kP $BACKUP_DIR | tail -1 |awk '{print $4}'`
	#echo $SIZE
	if [ "$SIZE" == "" ]; then
		SIZE=0
	fi
	#echo $SIZE
	DATAS=`du -sk $OSLV_DATA_DIR |awk '{print $1}'`
	if [ "$DATAS" == "" ]; then
		DATAS=0
	fi
	#echo $DATAS
	WALS=`du -sk $OSLV_WAL_DIR |awk '{print $1}'`
	if [ "$WALS" == "" ]; then
		WALS=0
	fi
	#echo $WALS
	ARCHS=`du -sk $OSLV_ARCH_DIR |awk '{print $1}'`
	if [ "$ARCHS" == "" ]; then
		ARCHS=0
	fi
	#echo $ARCHS
	LOGS=`du -sk $OSLV_LOG_DIR |awk '{print $1}'`
	if [ "$LOGS" == "" ]; then
		LOGS=0
	fi
	#echo $LOGS
	TBSS=`expr 0 \`du -sk $OSLV_DATA_DIR/pg_tblspc/* |awk '{print" '\+' "$1}'\``
	if [ "$TBSS" == "" ]; then
		TBSS=0
	fi
	#echo $TBSS
	SIZES=`expr $DATAS \+ $TBSS \+ $WALS \+ $ARCHS \+ $LOGS`
	#echo $SIZES
	#echo $SIZE
	if [ $SIZES -gt $SIZE ]; then
		echo "Old slave BACKUP storage not enough space. Please empty BACKUP storage space." &>>$LOG_FILE
		hbabye $UT $TEMP3 $MST_REP_USR $MST_DATA_DIR $1 $MST_SVC_USR $LOG_FILE
	fi
	
	chown -R $SLV_SVC_USR. $BACKUP_DIR
	if [ "$OSLV_DATA_DIR" == "" ]; then
		OSLV_DATA_DIR=/OLD_SLV_DB$(date +%Y%m%d%H%M%S)/DATA
		mkdir -p $OSLV_DATA_DIR
	fi

	if [ "$OSLV_WAL_DIR" == "" ]; then
		OSLV_WAL_DIR=/OLD_SLV_DB$(date +%Y%m%d%H%M%S)/WAL
		mkdir -p $OSLV_WAL_DIR
	fi

	if [ "$OSLV_ARCH_DIR" == "" ]; then
		OSLV_ARCH_DIR=/OLD_SLV_DB$(date +%Y%m%d%H%M%S)/ARCH
		mkdir -p $OSLV_ARCH_DIR
	fi
	if [ "$OSLV_LOG_DIR" == "" ]; then
		OSLV_LOG_DIR=/OLD_SLV_DB$(date +%Y%m%d%H%M%S)/LOG
		mkdir -p $OSLV_LOG_DIR
	fi

	su - $SLV_SVC_USR -c "`ls -l $OSLV_DATA_DIR/pg_tblspc/|awk '{print "cp -a "$11" '$BACKUP_DIR'/TBS/"}' | tail -n +2`" &>/dev/null
	if [ $? -eq 0 ]; then
		su - $SLV_SVC_USR -c "`ls -l $OSLV_DATA_DIR/pg_tblspc/|awk '{print "rm -rf "$11}' | tail -n +2`" &>/dev/null
	fi 

	su - $SLV_SVC_USR -c "cp -a $OSLV_WAL_DIR/0000* $OSLV_WAL_DIR/archive_status $BACKUP_DIR/WAL/" &>/dev/null
	if [ $? -eq 0 ]; then
		su - $SLV_SVC_USR -c "rm -rf $OSLV_WAL_DIR/0000* $OSLV_WAL_DIR/archive_status" &>/dev/null
	fi 

	su - $SLV_SVC_USR -c "cp -a $OSLV_LOG_DIR/*.log $BACKUP_DIR/LOG/" &>/dev/null
	if [ $? -eq 0 ]; then
		su - $SLV_SVC_USR -c "rm -rf $OSLV_LOG_DIR/*.log" &>/dev/null
	fi 

	su - $SLV_SVC_USR -c "cp -a $OSLV_ARCH_DIR/0000* $BACKUP_DIR/ARCH/" &>/dev/null
	if [ $? -eq 0 ]; then
		su - $SLV_SVC_USR -c "rm -rf $OSLV_ARCH_DIR/0000*" &>/dev/null
	fi 

	su - $SLV_SVC_USR -c "cp -a $OSLV_DATA_DIR/PG_VERSION $OSLV_DATA_DIR/base $OSLV_DATA_DIR/global $OSLV_DATA_DIR/pg_commit_ts $OSLV_DATA_DIR/pg_hba.conf $OSLV_DATA_DIR/logical $OSLV_DATA_DIR/pg_notify $OSLV_DATA_DIR/pg_serial $OSLV_DATA_DIR/pg_stat $OSLV_DATA_DIR/pg_subtrans $OSLV_DATA_DIR/pg_twophase $OSLV_DATA_DIR/postgresql.auto.conf $OSLV_DATA_DIR/postmaster.opts $OSLV_DATA_DIR/backup_label.old $OSLV_DATA_DIR/pg_clog $OSLV_DATA_DIR/pg_dynshmem $OSLV_DATA_DIR/pg_ident.conf $OSLV_DATA_DIR/pg_multixact $OSLV_DATA_DIR/pg_replslot $OSLV_DATA_DIR/pg_snapshots $OSLV_DATA_DIR/pg_stat_tmp $OSLV_DATA_DIR/pg_tblspc $OSLV_DATA_DIR/postgresql.conf $OSLV_DATA_DIR/recovery.conf $BACKUP_DIR/DATA/" &>/dev/null
	if [ $? -eq 0 ]; then
		su - $SLV_SVC_USR -c "rm -rf $OSLV_DATA_DIR/PG_VERSION $OSLV_DATA_DIR/base $OSLV_DATA_DIR/global $OSLV_DATA_DIR/pg_commit_ts $OSLV_DATA_DIR/pg_hba.conf $OSLV_DATA_DIR/logical $OSLV_DATA_DIR/pg_notify $OSLV_DATA_DIR/pg_serial $OSLV_DATA_DIR/pg_stat $OSLV_DATA_DIR/pg_subtrans $OSLV_DATA_DIR/pg_twophase $OSLV_DATA_DIR/postgresql.auto.conf $OSLV_DATA_DIR/postmaster.opts $OSLV_DATA_DIR/backup_label.old $OSLV_DATA_DIR/pg_clog $OSLV_DATA_DIR/pg_dynshmem $OSLV_DATA_DIR/pg_ident.conf $OSLV_DATA_DIR/pg_multixact $OSLV_DATA_DIR/pg_replslot $OSLV_DATA_DIR/pg_snapshots $OSLV_DATA_DIR/pg_stat_tmp $OSLV_DATA_DIR/pg_tblspc $OSLV_DATA_DIR/postgresql.conf $OSLV_DATA_DIR/recovery.conf $OSLV_DATA_DIR/pg_${REXL}" &>/dev/null
	fi 
elif [ $BACKUP == n ]; then
	echo "You choice that DO not Backup Old DATA" &>>$LOG_FILE
fi
su - $SLV_SVC_USR -c "rm -rf $OSLV_LOG_DIR" &>/dev/null
su - $SLV_SVC_USR -c "rm -rf $OSLV_WAL_DIR" &>/dev/null
su - $SLV_SVC_USR -c "rm -rf $OSLV_ARCH_DIR" &>/dev/null
su - $SLV_SVC_USR -c "rm -rf $OSLV_DATA_DIR" &>/dev/null



#STEP.5 Slave DATA, WAL Enviroment Struct

TEMP4=/tmp/DB_LSTNFND$(date +%Y%m%d%H%M%S)
mkdir -p $TEMP4/DATA
mkdir -p $TEMP4/WAL
cp -a $SLV_DATA_DIR/lost+found $TEMP4/DATA &>/dev/null
cp -a $SLV_WAL_DIR/lost+found $TEMP4/WAL &>/dev/null
rm -rf $SLV_DATA_DIR/lost+found &>/dev/null
rm -rf $SLV_WAL_DIR/lost+found &>/dev/null
rm -rf $SLV_DATA_DIR &>/dev/null
rm -rf $SLV_WAL_DIR &>/dev/null
mkdir -p $SLV_DATA_DIR
mkdir -p $SLV_WAL_DIR
chmod 700 $SLV_DATA_DIR
chmod 700 $SLV_WAL_DIR
chown -R $SLV_SVC_USR. $SLV_DATA_DIR
chown -R $SLV_SVC_USR. $SLV_WAL_DIR
if [ "$MSTSLVEQ" == "y" ]; then
	YAHO=`ssh -T -p $SSHPORT root@$1 ls -l $MST_DATA_DIR/pg_tblspc/|awk '{print "-T "$11"="$11}' | tail -n +2`
	TEMP=/tmp/temp$(date +%Y%m%d%H%M%S).sh
	ssh -T -p $SSHPORT root@$1 ls -l $MST_DATA_DIR/pg_tblspc/|awk '{print "rm -rf "$11}' | tail -n +2 >> $TEMP
	ssh -T -p $SSHPORT root@$1 ls -l $MST_DATA_DIR/pg_tblspc/|awk '{print "mkdir -p "$11}' | tail -n +2 >> $TEMP
	ssh -T -p $SSHPORT root@$1 ls -l $MST_DATA_DIR/pg_tblspc/|awk '{print "chown -R '$SLV_SVC_USR'. "$11}' | tail -n +2 >> $TEMP
	bash $TEMP
	rm -rf $TEMP
	YAHO=`echo $YAHO`
elif [ "$MSTSLVEQ" == "n" ]; then
	numb=1
	DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh`
	while [ "$DIR_NAME" != "#######################------TBS list START-------#######################" ]
	do
		numb=`expr $numb \+ 1`
		DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh | sed -e 's;^.*=;;'`
	done
	numb=`expr $numb \+ 1`
	TBLSTR=`sed -n ''$numb', '$numb'p' parameter.sh`
	TBLSTT=" "
	DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh | sed -e 's;^.*=;;'`
	while [ "$DIR_NAME" != "#######################-------TBS list END--------#######################" ]
	do
	        L=`expr length "$DIR_NAME"`
	        if [ $L -gt 5 ]; then
			rm -rf $DIR_NAME
                        mkdir -p $DIR_NAME
                        chown -R $SLV_SVC_USR. $DIR_NAME
	                TBLSTT=$TBLSTT" -T $"$TBLSTR
	        fi
	        DIR_NAME=`sed -n ''$numb', '$numb'p' parameter.sh | sed -e 's;^.*=;;'`
	        TBLSTR=`sed -n ''$numb', '$numb'p' parameter.sh`
	        numb=`expr $numb \+ 1`
	done
	TEMP=/tmp/temp$(date +%Y%m%d%H%M%S).sh
	touch $TEMP
cat > $TEMP <<EOFF
`ssh -T -p $SSHPORT root@$1 ls -l $MST_DATA_DIR/pg_tblspc/|awk '{print "p"$(NF-2)"="$NF}' | tail -n +2`
`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"oid2name -s -p $MST_PORT\" |awk '{print $2"=$p"$1}'| grep -v pg_default | grep -v pg_global | tail -n +4`
YAHO="`echo $TBLSTT`"
EOFF
	source $TEMP
fi
if [ "12" -gt "$VRSN" ]; then
	Y=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"find $MST_ENGN_HOME -name recovery.conf*\"`
	ssh -T -p $SSHPORT root@$1 cp $Y $MST_DATA_DIR/recovery.conf
	ssh -T -p $SSHPORT root@$1 "chown -R $MST_SVC_USR. $MST_DATA_DIR/recovery.conf"
fi



#STEP.6 pg_basebackup

ST=`date +%s`
STS=`date`
echo "================================================" &>>$LOG_FILE
echo "Start time : $STS" &>>$LOG_FILE
rm -rf $SLV_DATA_DIR/*
if [ "$WS" == "1" ]; then
	XLOGDIR=""
else
	XLOGDIR="--${REXL}dir $SLV_WAL_DIR"
fi
su - $SLV_SVC_USR -c "pg_basebackup $YAHO -h $1 -p $MST_PORT -P -D $SLV_DATA_DIR -X stream --${REXL}dir $SLV_WAL_DIR -U $MST_REP_USR"
ET=`date +%s`
ETS=`date` 
EST=`echo $ET $ST | awk '{print $1-$2}'`
HT=`echo $EST| awk '{print $1/3600}'`
MT=`echo $EST $HT| awk '{print ($1/60)-($2*60)}'` 
sT=`echo $EST $EST | awk '{print $1-(($2/60)*60)}'`
echo "End time   : $ETS" &>>$LOG_FILE
echo "Total time : ${HT}hour ${MT}minute ${sT}secound" &>>$LOG_FILE
echo "================================================" &>>$LOG_FILE
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"rm -rf $MST_DATA_DIR/recovery.conf\"
rm -rf $TEMP
cp -a $TEMP4/DATA/* $SLV_DATA_DIR &>/dev/null
cp -a $TEMP4/WAL/* $SLV_WAL_DIR &>/dev/null
chmod 700 $SLV_WAL_DIR/0000*



#STEP.7 Slave LOG & ARCHIVE Enviroment Structure

if [ "$SLV_LOG_DIR" != "off" ]; then
	echo "logging_collector = on" >> $SLV_DATA_DIR/postgresql.conf
	echo "log_directory = '$SLV_LOG_DIR'" >> $SLV_DATA_DIR/postgresql.conf
	if [ "$SLV_LOG_DIR" == "$SLV_DATA_DIR/${LOGD}" -a "$SLV_LOG_DIR" = "$LOGD" ]; then
		rm -rf $SLV_DATA_DIR/${LOGD}
		mkdir -p $SLV_DATA_DIR/${LOGD}
		chown -R $SLV_SVC_USR. $SLV_DATA_DIR/${LOGD}
	else 
		mkdir -p $TEMP4/LOG
		cp -a $SLV_LOG_DIR/lost+found $TEMP4/LOG &>/dev/null
		rm -rf $SLV_LOG_DIR/lost+found &>/dev/null
		rm -rf $SLV_LOG_DIR &>/dev/null
		rm -rf $SLV_DATA_DIR/${LOGD}
		mkdir -p $SLV_LOG_DIR
		chmod -R 700 $SLV_LOG_DIR
		chown -R $SLV_SVC_USR. $SLV_LOG_DIR
		ln -s $SLV_LOG_DIR $SLV_DATA_DIR/${LOGD}
		cp -a $TEMP4/LOG/* $SLV_LOG_DIR &>/dev/null
	fi
elif [ "$SLV_LOG_DIR" == "off" ]; then
	echo "logging_collector = off" >> $SLV_DATA_DIR/postgresql.conf
fi

if [ "$SLV_ARCH_DIR" != "off" ]; then
	mkdir -p $TEMP4/ARCH
	cp -a $SLV_ARCH_DIR/lost+found $TEMP4/ARCH &>/dev/null
	rm -rf $SLV_ARCH_DIR &>/dev/null
	mkdir -p $SLV_ARCH_DIR
	chmod -R 700 $SLV_ARCH_DIR
	chown -R $SLV_SVC_USR. $SLV_ARCH_DIR
	echo "archive_command = 'cp %p $SLV_ARCH_DIR/%f'" >> $SLV_DATA_DIR/postgresql.conf
	su - $SLV_SVC_USR -c "mv $SLV_WAL_DIR/0000* $SLV_ARCH_DIR/"
	ls $SLV_ARCH_DIR/* &>/dev/null
	if [ "$?" = "0" ]; then
		chmod 600 $SLV_ARCH_DIR/*
	fi
elif [ "$SLV_ARCH_DIR" == "off" ]; then
	$SLV_ARCH_DIR=$SLV_WAL_DIR
	echo "archive_mode = off" >> $SLV_DATA_DIR/postgresql.conf
fi
echo "port = $SLV_PORT" >> $SLV_DATA_DIR/postgresql.conf


if [ "12" -gt "$VRSN" ]; then
	echo "standby_mode = on" >> $SLV_DATA_DIR/recovery.conf
	echo "primary_conninfo = 'host=$1 port=$MST_PORT user=$MST_REP_USR password=$MST_REP_PWD'">> $SLV_DATA_DIR/recovery.conf
	$SLV_ARCH_DIR
	echo "restore_command='cp $SLV_ARCH_DIR/%f %p'">> $SLV_DATA_DIR/recovery.conf
	echo "trigger_file='$SLV_DATA_DIR/trigger.pg.5444'">> $SLV_DATA_DIR/recovery.conf
	echo "recovery_target_timeline = 'latest'">> $SLV_DATA_DIR/recovery.conf
else
	echo "primary_conninfo = 'host=$1 port=$MST_PORT user=$MST_REP_USR password=$MST_REP_PWD'">> $SLV_DATA_DIR/postgresql.conf
	echo "restore_command='cp $SLV_ARCH_DIR/%f %p'">> $SLV_DATA_DIR/postgresql.conf
	echo "promote_trigger_file='$SLV_DATA_DIR/trigger.pg.5444'">> $SLV_DATA_DIR/postgresql.conf
	echo "recovery_target_timeline = 'latest'">> $SLV_DATA_DIR/postgresql.conf
	touch $SLV_DATA_DIR/standby.signal
fi
chown -R $SLV_SVC_USR. $SLV_DATA_DIR

 
 
#STEP.8 WAL file move

R=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \" ls -rtl $MST_ARCH_DIR/*backup \| tail -n 1\" | awk '{print $NF}'`
R=`ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"cat $R\" | head -n 2 | tail -n 1 |rev|cut -d' ' -f1 |rev`
R=`echo ${R%)*}`
TEMP=ARCH$(date +%Y%m%d%H%M%S)
ssh -T -p $SSHPORT root@$1 "mkdir -p $MST_ARCH_DIR/$TEMP"
ssh -T -p $SSHPORT root@$1 "chown -R $MST_SVC_USR. $MST_ARCH_DIR/$TEMP"
ssh -T -p $SSHPORT root@$1 "chmod 700 -R $MST_ARCH_DIR"
#arch $1 $MST_SVC_USR $MST_ARCH_DIR $R $TEMP $SLV_ARCH_DIR $SLV_SVC_USR $LOG_FILE &
cp -a $TEMP4/ARCH/* $SLV_ARCH_DIR &>/dev/null
rm -rf $TEMP4
sleep 10
su - $SLV_SVC_USR -c "rm -rf $SLV_DATA_DIR/recovery.done"



#STEP.9 Slave startup

su - $SLV_SVC_USR -c "pg_ctl start -D $SLV_DATA_DIR -w" &>/dev/null
sleep 10



#STEP.10 Slave Replication Verivication

ps -ef | grep `ps -ef |grep postgres | grep $SLV_DATA_DIR | awk '{print $2}'` &>>$LOG_FILE
N=`su - $SLV_SVC_USR -c "psql -p $SLV_PORT -U $MST_DB_SPR_USR -t -c 'select pg_is_in_recovery();'" | rev | cut -c 1`
if [ "$N" == "t" ]; then
	printf "\n" &>>$LOG_FILE
	echo "Replication is Success!!!" &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
elif [ "$N" == "f" ]; then
	printf "\n" &>>$LOG_FILE
	echo "Replication is Fail....." &>>$LOG_FILE
	printf "\n" &>>$LOG_FILE
fi



#STEP.11 Master DB orgnize

sed -i ''$UT'd' $TEMP3/pg_hba.conf
sed -i ''$UT'd' $TEMP3/pg_hba.conf
UT=`grep -n "host    replication     $MST_REP_USR          0.0.0.0/0               trust" $TEMP3/pg_hba.conf | cut -d':' -f1 |tail -n 1`
sed -i ''$UT'd' $TEMP3/pg_hba.conf
sed -i ''$UT'd' $TEMP3/pg_hba.conf
cat >>$TEMP3/pg_hba.conf << EOFF
####################---bkbspark replication-start---######################
host    replication     $MST_REP_USR          0.0.0.0/0               md5
host    replication     $MST_REP_USR          ::1/128                 md5
#####################----bkbspark replication-end----#####################
EOFF
scp -P $SSHPORT $TEMP3/pg_hba.conf root@$1:$MST_DATA_DIR/ &>/dev/null
cp $TEMP3/pg_hba.conf $SLV_DATA_DIR/ &>/dev/null
ssh -T -p $SSHPORT root@$1 "chown $MST_SVC_USR. $MST_DATA_DIR"
chown $SLV_SVC_USR. $SLV_DATA_DIR
rm -rf $TEMP3
ssh -T -p $SSHPORT root@$1 su - $MST_SVC_USR -c \"pg_ctl -D $MST_DATA_DIR reload\" &>/dev/null
su - $SLV_SVC_USR -c \"pg_ctl -D $SLV_DATA_DIR reload\" &>/dev/null
UT=`grep -n "OSLV_DATA_DIR" ./parameter.sh | cut -d':' -f1 |tail -n 1`
sed -i ''$UT'd' ./parameter.sh
sed -i ''$UT'd' ./parameter.sh
sed -i ''$UT'd' ./parameter.sh
sed -i ''$UT'd' ./parameter.sh
sed -i ''$UT' i\OSLV_DATA_DIR='$SLV_DATA_DIR'\nOSLV_WAL_DIR='$SLV_WAL_DIR'\nOSLV_ARCH_DIR='$SLV_ARCH_DIR'\nOSLV_LOG_DIR='$SLV_LOG_DIR'' ./parameter.sh
exit 0
