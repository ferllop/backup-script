#!/bin/bash
web=$1
database=$2
remote_backups_path=$3
dirnames_to_exclude=$4

#prepare exclude string for files backup
arr=($(echo "$dirnames_to_exclude" | tr ',' '\n'))
exclude=""
for i in ${arr[@]}
do
    exclude="${exclude} --exclude=${i} "
done
exclude="$(echo -e "${exclude}" | sed -e 's/[[:space:]]*$//')"

fulldate=$(date +%Y%m%dT%H.%M.%S)   

backups_path=/home/backup_user/backups
db_backup_filename=${web}_db_backup
mysqldump --user=backup_user --lock-tables --databases ${database} -h localhost > ${backups_path}/${db_backup_filename}.sql
if [ $? -eq 0 ] 
then
    some_cp_error="false"
    gzip ${backups_path}/${db_backup_filename}.sql

    #DAILY
    cp ${backups_path}/${db_backup_filename}.sql.gz ${backups_path}/daily/${db_backup_filename}_daily_$(date +%A).sql.gz
        if [ $? -eq 0 ] 
        then
            db_message="Daily_DB_OK"
        else
            db_message="Daily_DB_FAILED"
            some_cp_error="true"
        fi

    #WEEKLY 5 backups
    if [ "$(date +%A)" == "Monday" ]
    then
        cp ${backups_path}/${db_backup_filename}.sql.gz ${backups_path}/weekly/${db_backup_filename}_${fulldate}_weekly.sql.gz
        if [ $? -eq 0 ] 
        then
            find ${backups_path}/weekly/${db_backup_filename}_*_weekly.sql.gz -mtime +35 -exec rm {} \;
            db_message="${db_message}, Weekly_DB_OK"
        else
            db_message="${db_message}, Weekly_DB_FAILED"
            some_cp_error="true"
        fi
    fi

    #MONTHLY 6 backups
    if [ "$(date +%d)" == "01" ]
    then
        cp ${backups_path}/${db_backup_filename}.sql.gz ${backups_path}/monthly/${db_backup_filename}_monthly_$(date +%M).sql.gz
        if [ $? -eq 0 ] 
        then
            find ${backups_path}/monthly/${db_backup_filename}_monthly_*.sql.gz -mtime +178 -exec rm {} \;
          db_message="${db_message}, Monthly_DB_OK"
        else
            db_message="${db_message}, Monthly_DB_FAILED"
            some_cp_error="true"
        fi
    fi

    #YEARLY 5 backups
    if [ "$(date +%j)" == "001" ]
    then
        cp ${backups_path}/${db_backup_filename}.sql.gz ${backups_path}/yearly/${db_backup_filename}_yearly_$(date +%Y).sql.gz
        if [ $? -eq 0 ] 
        then
            find ${backups_path}/yearly/${db_backup_filename}_yearly_*.sql.gz -mtime +1825 -exec rm {} \;
          db_message="${db_message}, Yearly_DB_OK"
        else
            db_message="${db_message}, Yearly_DB_FAILED"
            some_cp_error="true"
        fi
    fi

    rm ${backups_path}/$db_backup_filename.sql.gz
    
else 
    if [ -e ${backups_path}/$db_backup_filename.sql ]
    then
        rm ${backups_path}/$db_backup_filename.sql
    fi
    db_message="DB_dump_FAILED"
    some_cp_error="true"
fi  


fs_backup_filename=${web}_fs_backup
tar -C /var/www -cvJf ${backups_path}/${fs_backup_filename}.tar.xz ${exclude} ${web}
gpg --symmetric --pinentry-mode loopback --passphrase-file ~/.gpg_key ${backups_path}/${fs_backup_filename}.tar.xz

if [ $? -eq 0 ] 
then
    #DAILY
    cp ${backups_path}/${fs_backup_filename}.tar.xz.gpg ${backups_path}/daily/${fs_backup_filename}_daily_$(date +%A).tar.xz.gpg
        if [ $? -eq 0 ] 
        then
            fs_message="Daily_FS_OK"
        else
            fs_message="Daily_FS_FAILED"
            some_cp_error="true"
        fi

    #WEEKLY 5 backups
    if [ "$(date +%A)" == "Monday" ]
    then
        cp ${backups_path}/${fs_backup_filename}.tar.xz.gpg ${backups_path}/weekly/${fs_backup_filename}_${fulldate}_weekly.tar.xz.gpg
        if [ $? -eq 0 ] 
        then
            find ${backups_path}/weekly/${fs_backup_filename}_*_weekly.tar.xz.gpg -mtime +35 -exec rm {} \;
            fs_message="${fs_message}, Weekly_FS_OK"
        else
            fs_message="${fs_message}, Weekly_FS_FAILED"
            some_cp_error="true"
        fi
    fi
 
    #MONTHLY 6 backups
    if [ "$(date +%d)" == "01" ]
    then
        cp ${backups_path}/${fs_backup_filename}.tar.xz.gpg ${backups_path}/monthly/${fs_backup_filename}_monthly_$(date +%M).tar.xz.gpg
        if [ $? -eq 0 ] 
        then
            find ${backups_path}/monthly/${fs_backup_filename}_monthly_*.tar.xz.gpg -mtime +178 -exec rm {} \;
            fs_message="${fs_message}, Monthly_FS_OK"
        else
            fs_message="${fs_message}, Monthly_FS_FAILED"
            some_cp_error="true"
        fi
    fi

    #YEARLY 5 backups
    if [ "$(date +%j)" == "001" ]
    then
        cp ${backups_path}/${fs_backup_filename}.tar.xz.gpg ${backups_path}/yearly/${fs_backup_filename}_yearly_$(date +%Y).tar.xz.gpg
        if [ $? -eq 0 ] 
        then
            find ${backups_path}/yearly/${fs_backup_filename}_yearly_*.tar.xz.gpg -mtime +1825 -exec rm {} \;
            fs_message="${fs_message}, Yearly_FS_OK"
        else
            fs_message="${fs_message}, Yearly_FS_FAILED"
            some_cp_error="true"
        fi
    fi


    rm ${backups_path}/${fs_backup_filename}.tar.xz
    rm ${backups_path}/${fs_backup_filename}.tar.xz.gpg

else 
    if [ -e ${backups_path}/${fs_backup_filename}.tar.xz.gpg ] 
    then
        rm ${backups_path}/${fs_backup_filename}.tar.xz
        rm ${backups_path}/${fs_backup_filename}.tar.xz.gpg
    fi
    files_message="FS_TAR_FAILED"
    some_cp_error="true"
fi

#REMOTE SYNC
if [ "$some_cp_error" = "false" ]
then
    rclone sync ${backups_path} ${remote_backups_path} -P --mega-hard-delete
    if [ $? -eq 0 ]
    then
        remote_message="Remote_SYNC_OK"
    else
        remote_message="Remote_SYNC_FAILED"
    fi
fi

source /home/backup_user/.telegram_keys   
URL=https://api.telegram.org/bot$TOKEN/sendMessage
curl -s -X POST $URL -d chat_id=$CHANNEL -d text="${web} backup: ${db_message} and ${fs_message}. ${remote_message}" >/dev/null 2>&1
