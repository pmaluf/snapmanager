#!/bin/bash
#
# snapmanager.sh - MySQL backup via snapshot LVM or NETAPP
# Created: Paulo Victor Maluf - 01/2014
#
# Parameters:
#
#   snapmanager.sh --help
#
#    Parameter           Short Description                                                        Default
#    ------------------- ----- ------------------------------------------------------------------ --------------
#    --hostname             -H [REQUIRED] Hostname will be backuped                               localhost
#    --port                 -P [OPTIONAL] Port to connect to MySQL                                3306
#    --username             -u [OPTIONAL] MySQL username                                          backupmanager
#    --password             -p [OPTIONAL] MySQL password
#    --snap-name            -n [OPTIONAL] Label use for snapshot backup
#    --retention	    -r [OPTIONAL] How many snapshots will be retained			  7
#    --volume-name          -v [REQUIRED] Volume name or nfs path
#    --list                 -l [OPTIONAL] List snapshots
#    --type                 -t [REQUIRED] Snapshot type: NETAPP or LVM                            NETAPP
#    --netapp-server        -s [OPTIONAL] Netapp server
#    --skip-lock            -S [OPTIONAL] Skip Lock tables
#    --logical-backup       -L [OPTIONAL] Take a logical backup from snapshot volume.
#    --help                 -h [OPTIONAL] help
#
#   Ex.: snapmanager.sh [OPTIONS] --hostname <HOST> --volume-name <NFS/LVM>
#        snapmanager.sh --hostname mysql-1 --volume-name nfs_mysql_db_1
#        snapmanager.sh -v nfs_teste_linux -s netapp-db-1 -t NETAPP --list
#
# Changelog:
#
# Date       Author               Description
# ---------- ------------------- ----------------------------------------------------
#====================================================================================

# Global Variables
MYUSER="backupmanager"
MYPASS="<MYPASSWD>"
MYHOST="localhost"
MYSQL=`which mysql`
MYPORT=3306
SCRIPT_DIR=`pwd`
SCRIPT_NAME=`basename $1 | sed -e 's/\.sh$//'`
SCRIPT_LOGDIR="${SCRIPT_DIR}/logs"
SSH=`which ssh`
SSHUSER="<NETAPP_SSHPASSWORDLESS_USER>"
RETENTION=7

# Functions
f_help(){
 head -28 $0 | tail -27
 exit 0
}

log(){
 MSG=$1
 COLOR=$2
 if [ "${COLOR}." == "blue." ]
  then
     echo -ne "\e[34;1m${MSG}\e[m" | tee -a ${LOG}
  elif [ "${COLOR}." == "yellow." ]
    then
      echo -ne "\e[33;1m${MSG}\e[m" | tee -a ${LOG}
  elif [ "${COLOR}." == "green." ]
    then
      echo -ne "\e[32;1m${MSG}\e[m" | tee -a ${LOG}
  elif [ "${COLOR}." == "red." ]
    then
      echo -ne "\e[31;1m${MSG}\e[m" | tee -a ${LOG}
      sendmail ${MSG}
  else
    echo -ne "${MSG}" | tee -a ${LOG}
 fi
}

sendmail(){
MSG=$1
mail -s "[SNAPMANAGER][${MYHOST}] Falha ao executar o backup via snapshot" "${MAIL_LST}" << EOF
 Falha ao executar o backup via snapshot:

 ${MSG}

EOF
}

check_mysql_conn(){
 log "Checking MySQL connection... " blue
 ${MYSQL} -u${MYUSER} -p${MYPASS} -h ${MYHOST} -P ${MYPORT} -e "exit" > /dev/null 2>&1
 [ "$?." != "0." ] && { log "ERROR: Can't connect to MySQL! Please check your username and password.\n" red ;  exit 1 ;} || log "[ OK ]\n" green
}

check_ssh_conn(){
 log "Checking SSH connection... " blue
 ${SSH} ${SSHUSER}@${NETAPP_SERVER} exit > /dev/null 2>&1
 [ "$?." != "0." ] && { log "ERROR: Can't connect to NETAPP from ssh! Please check your credentials.\n" red ;  exit 1 ;} || log "[ OK ]\n" green
}

check_netapp_vol(){
 log "Checking netapp volume..." blue
 CHK=`${SSH} ${NETAPP_SERVER} snap list ${VOLUME_NAME} 2>&1 | grep 'does not exist' | wc -l`
 [ "${CHK}." != "0." ] && { log "ERROR: Volume: ${VOLUME_NAME} does not exists in NETAPP Server.\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

lock_mysql(){
 log "Locking tables with read only mode..." blue
 ${MYSQL} -u${MYUSER} -p${MYPASS} -h ${MYHOST} -P ${MYPORT} -e "flush tables with read lock" > /dev/null 2>&1
 [ "$?." != "0." ] && { log "ERROR: Flush tables failed!\n" red ; exit 1 ; } || log "[ OK ]\n" green
}

flush_mysql(){
 log "Flush logs for binlog rotate..." blue
 ${MYSQL} -u${MYUSER} -p${MYPASS} -h ${MYHOST} -P ${MYPORT} -e "flush logs" > /dev/null 2>&1
 [ "$?." != "0." ] && log "ERROR: Flush logs failed!\n" red || log "[ OK ]\n" green
}

unlock_mysql(){
 log "Unlocking MySQL tables..." blue
 ${MYSQL} -u${MYUSER} -p${MYPASS} -h ${MYHOST} -P ${MYPORT} -e "unlock tables" > /dev/null 2>&1
 [ "$?." != "0." ] && { log "ERROR: Unlock tables failed!\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

sync_fs(){
 log "Synchronize data on disk with memory..." blue
 sync
 [ "$?." != "0." ] && { log "ERROR: Sync failed!\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

snap_netapp(){
 log "Creating snapshot..." blue
 ${SSH} ${SSHUSER}@${NETAPP_SERVER} snap create ${VOLUME_NAME} ${SNAP_NAME} > /dev/null 2>&1
 [ "$?." != "0." ] && { log "ERROR: Snapshot failed!\n" red ; exit 1 ;} || log "[ OK ]\n" green
}

purge_snapshots(){
 log "Purging old snapshots based on retention policy of ${RETENTION} snapshots.\n" yellow
 SNAPSHOTS=(`${SSH} ${SSHUSER}@${NETAPP_SERVER} snap list -n ${VOLUME_NAME} | awk '{ print $4}' | grep -v "^$"`)
 COUNT=$((${#SNAPSHOTS[@]}-1))
 while [ ${COUNT} -ge ${RETENTION} ]
 do
   log "Purge snapshot: ${SNAPSHOTS[${COUNT}]} "
   ${SSH} ${SSHUSER}@${NETAPP_SERVER} snap delete ${VOLUME_NAME} ${SNAPSHOTS[${COUNT}]} > /dev/null 2>&1
   [ "$?." != "0." ] && { log "ERROR: Purge failed!\n" red ; exit 1 ;} || log "[ OK ]\n" green
   let COUNT--
 done
}

snap_netapp_list(){
 check_ssh_conn
 check_netapp_vol
 log "Listing snapshots... \n" green
 ${SSH} ${SSHUSER}@${NETAPP_SERVER} snap list ${VOLUME_NAME}
 exit 0
}

snap_lvm(){
 exit
}

# Parameters
for arg
do
    delim=""
    case "$arg" in
    #translate --gnu-long-options to -g (short options)
      --hostname)        args="${args}-H ";;
      --port)            args="${args}-P ";;
      --username)        args="${args}-u ";;
      --password)        args="${args}-p ";;
      --snap-name)       args="${args}-n ";;
      --retention)       args="${args}-r ";;
      --volume-name)     args="${args}-v ";;
      --type)            args="${args}-t ";;
      --server)          args="${args}-s ";;
      --skip-lock)       args="${args}-S ";;
      --logical-backup)  args="${args}-L ";;
      --list)            args="${args}-l ";;
      --help)            args="${args}-h ";;
      #pass through anything else
      *) [[ "${arg:0:1}" == "-" ]] || delim="\""
         args="${args}${delim}${arg}${delim} ";;
    esac
done

eval set -- $args

while getopts ":hH:p:P:u:n:r:lLv:Ss:t:s:" PARAMETRO
do
    case $PARAMETRO in
        h) f_help;;
        H) MYHOST=${OPTARG[@]};;
        P) MYPORT=${OPTARG[@]};;
        u) MYUSER=${OPTARG[@]};;
        p) MYPASS=${OPTARG[@]};;
        n) SNAP_NAME=${OPTARG[@]};;
        r) RETENTION=${OPTARG[@]};;
        v) VOLUME_NAME=${OPTARG[@]};;
        t) SNAP_TYPE=${OPTARG[@]};;
        s) NETAPP_SERVER=${OPTARG[@]};;
        S) SKIP_LOCK="Y";;
        l) snap_netapp_list ;;
        L) LOGICAL_BACKUP="Y";;
        :) echo "Option -$OPTARG requires an argument."; exit 1;;
        *) echo $OPTARG is an unrecognized option ; echo $USAGE; exit 1;;
    esac
done

[ "$1" ] || f_help

#########################
# Main                  #
#########################
[ ${SNAP_NAME} ] || SNAP_NAME="${VOLUME_NAME}-`date +%d%m%y%H%M%S`"

LOG="${SCRIPT_LOGDIR}/${MYHOST/\.*/}.log"

if [ "${SNAP_TYPE}." == "NETAPP." ]
 then
   log "Snapshot Name: " blue
   log "${SNAP_NAME}\n"
   check_mysql_conn
   check_ssh_conn
   check_netapp_vol
   [ "${SKIP_LOCK}." == "Y." ] || lock_mysql
   flush_mysql
   sync_fs
   snap_netapp
   [ "${SKIP_LOCK}." == "Y." ] || unlock_mysql
   purge_snapshots
 elif [ "${SNAP_TYPE}." == "LVM." ]
  then
   log "Sorry, LVM is not support...\n" yellow ; exit 1
 else
  log "ERROR: ${SNAP_TYPE} is unrecognized snapshot type! Please select NETAPP or LVM..\n" red ; exit 1
fi
