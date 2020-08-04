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

# DBMS structure same with Slave DB server? 'y' or 'n'
# If you choice 'y',
# You don't need set "SLAVE CONFIGURATION" & "TABLESPACE LIST"
# It will be create as all same with Master DB server
SSHPORT=22
MSTSLVEQ=y

# Do you want old Slave data backup?  'y' or 'n'
# If you choice 'y',
# You need set "OLD SLAVE CONFIGURATION"
# It will be BACKUP to BACKUP_DIR( parameter value ) OLD DB server
BACKUP=n

# Set the log file
LOG_FILE=./bkbspark$(date +%Y%m%d%H%M%S).log

#######################---MASTER CONFIGURATION---########################
MST_DATA_DIR=/DATA
MST_DB_SPR_USR=postgres
MST_REP_USR=repuser
MST_REP_PWD=edb
#######################---SLAVE CONFIGURATION---#########################
SLV_SVC_USR=pg12
SLV_PORT=5432
SLV_DATA_DIR=/DATA
SLV_WAL_DIR=/WAL
SLV_ARCH_DIR=/ARCH
SLV_LOG_DIR=/DATA/log
#######################------TBS list START-------#######################
tbs2=/TBS/tbs2
tbs1=/TBS/tbs1
tbs4=/TBS/tbs4
tbs3=/TBS/tbs3
tbs5=/TBS/tbs5
#######################-------TBS list END--------#######################

######################---OLD SLAVE CONFIGURATION---######################
BACKUP_DIR=$SLV_DATA_DIR/../DATA_CPY
OSLV_DATA_DIR=/ARCHIVE/POSTGRES/DATA
OSLV_WAL_DIR=/ARCHIVE/POSTGRES/WAL
OSLV_ARCH_DIR=/ARCHIVE/POSTGRES/ARCHIVE
OSLV_LOG_DIR=/ARCHIVE/POSTGRES/LOG
#########################################################################

