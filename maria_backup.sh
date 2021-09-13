#!/bin/bash

# Stephen Williams
# 27/01/2021
# 02/03/2021 - Added ability to backup all user grants

# Runs once a day via Systemd timers to backup all DB's on this server

error_detected(){
        # Used to send an email should the script detect an error dumping DB's or generating grants
        /usr/sbin/sendmail technical@hostinguk.net </root/smtp/error.txt
}

BACKUP_DIR="/backup/dumps"

TIMESTAMP=$(date +%F)

DAILY="${BACKUP_DIR}/${TIMESTAMP}"

LOG_FILE="/var/log/mariadb_backups/backup_task.log"

if [ ! -d "$DAILY" ]; then
        mkdir "$DAILY"
fi

## Backup our databases and users

echo -e "\n========== OPENING LOG FILE ${TIMESTAMP}: $(date +%R) ==========\n" >> $LOG_FILE

for DATABASE in $(mysql -uroot -pPASSWORD -e 'show databases;' -s --skip-column-names | grep -Ev "information_schema|performance_schema"); do

        echo -e "${TIMESTAMP}: $(date +%R)\t${DATABASE}: Processing" >> $LOG_FILE

        if mysqldump -uroot -p{PASSWORD} --routines --events --quick --single-transaction --databases "$DATABASE" | gzip >"${DAILY}/${DATABASE}.gz"; then
                echo -e "${TIMESTAMP}: $(date +%R)\t${DATABASE}: Complete\n" >> $LOG_FILE
        else
                echo -e "${TIMESTAMP}: $(date +%R)\t${DATABASE}: ERROR ENCOUNTERED\n" >> $LOG_FILE
                error_detected
        fi
done

# Backup user grants

echo -e "\n\t DUMPING GRANTS..." >> $LOG_FILE

if pt-show-grants -uroot -p{PASSWORD} > "${DAILY}/all_user_grants.sql"; then
        echo -e "${TIMESTAMP}: $(date +%R)\t GRANTS DUMPED SUCCESSFULLY!\n" >> $LOG_FILE

else
        echo -e "${TIMESTAMP}: $(date +%R)\t GRANTS DUMP ERROR!\n" >> $LOG_FILE
        error_detected
fi

echo -e "\n========== CLOSING LOG FILE ${TIMESTAMP}: $(date +%R) ==========\n" >> $LOG_FILE

# Remove DB backups older than 13 days.

find $BACKUP_DIR -maxdepth 1 -type d -mtime +13 -exec rm -rf {} \;

exit 0
