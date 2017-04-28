#!/bin/bash

DBID="$1"
BACKUP_DBUSER="$2"
BACKUP_MODE="$3"
BACKUP_LOCATION="$4"

HDBEXEC="hdbsql -d $DBID -U $BACKUP_DBUSER"
LOGFILE=$DIR_INSTANCE/backup.log

function log() {
    echo "$@" >> $LOGFILE
    echo "$@"
}

function do_backup() {
# capture the output for logging
    log "starting backup: $(date +"%Y-%m-%d %H:%M:%S")"
    BACKUP_CMD="backup ${BACKUPTYPE} using file ('$BACKUP_LOCATION','$BACKUPEX.$DBID')"
    log "cmd: ${BACKUP_CMD}"
    str="$(${HDBEXEC} -x ${BACKUP_CMD} 2>&1)"
    err=$?
    if [ $err -ne 0 ]; then
	log "${str}"
	log "FAILED backup: $(date +"%Y-%m-%d %H:%M:%S")"
	exit 1
    fi
}

function delete_old_backups() {
# select lastest successful backup
    log "delete_old_backups ..."
    SEL_CMD="SELECT BACKUP_ID,SYS_END_TIME FROM SYS.M_BACKUP_CATALOG where ENTRY_TYPE_NAME = 'complete data backup' and STATE_NAME = 'successful'"
    $HDBEXEC -x "$SEL_CMD" > BCK_ID.lst
    if [ $(wc -l < BCK_ID.lst) -gt 1 ]; then
    #read lastest backup_id
	BCK_ID="$(tail -1 BCK_ID.lst | cut -d "," -f1)"
	DEL_BACKUP_CMD="BACKUP CATALOG DELETE ALL BEFORE BACKUP_ID $BCK_ID COMPLETE"
	log ${DEL_BACKUP_CMD}
	str="$(${HDBEXEC} -x ${DEL_BACKUP_CMD} 2>&1)"
	err=$?
	if [ $err -ne 0 ]; then
	    log "delete old backups failed"
	    log "${str}"
	fi
    fi
}

usage()
{
  cat << EOF

Usage:
   Parameter 1: DB ID e.g. HD0
   Paremeter 2: DB User (needs BACKUP System Privileges and need a Keydbstore entry)
   Paremeter 3: Mode FULL|INC|DIFF
   Paremeter 4: Location of Backupfiles

   if a full-backup is successfull all older backups will be deleted

   example:
   ./hana_bck.sh HD0 SYSTEM FULL /usr/sap/HD0/HDB01/backup/data

EOF
}


if [  $# -ne 4 ] 
then 
    echo 
    echo "wrong number of parameters"
    usage
    exit 99
fi 

case ${BACKUP_MODE} in
    "FULL")
	BACKUPTYPE="DATA"
	BACKUPEX="FULL"
	do_backup
	delete_old_backups
	;;
    "INC")
	BACKUPTYPE="DATA INCREMENTAL"
	BACKUPEX="INC"
	do_backup
	;;
    "DIFF")
	BACKUPTYPE="DATA DIFFERENTIAL"
	BACKUPEX="DIFF"
	do_backup
	;;
    * )
	usage
	exit 99
	;;
esac

log "end backup: $(date +"%Y-%m-%d %H:%M:%S")"

