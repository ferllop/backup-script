#!/bin/bash

backup_name=$1
source_directory=$2
database=$3
remote_backups_path=$4
dirnames_to_exclude=$5

config_filename="backup.conf"
if [[ -e "~/$config_filename" ]]; then
	source "~/$config_filename";
elif [[ -e "/etc/$config_filename" ]]; then
	source "/etc/$config_filename";
else
	echo >&2 "Please put $config_filename file into the home root of whom executes this script or in the /etc folder.";
	exit 1;
fi

fulldate=$(date +%Y%m%dT%H.%M.%S)   
db_backup_filename=${backup_name}_db_backup
dump_destination=$BACKUPS_LOCAL_PATH/$db_backup_filename.sql

if [[ ! -d "$BACKUPS_LOCAL_PATH/daily" ]]; then
	mkdir -p $BACKUPS_LOCAL_PATH/daily;
fi
if [[ ! -d "$BACKUPS_LOCAL_PATH/weekly" ]]; then
	mkdir -p $BACKUPS_LOCAL_PATH/weekly;
fi
if [[ ! -d "$BACKUPS_LOCAL_PATH/monthly" ]]; then
	mkdir -p $BACKUPS_LOCAL_PATH/monthly;
fi
if [[ ! -d "$BACKUPS_LOCAL_PATH/yearly" ]]; then
	mkdir -p $BACKUPS_LOCAL_PATH/yearly;
fi

###########################
#                         #
#    DATABASE BACKUP      #
#                         #
###########################
some_cp_error="false"
if [ "$database" != "none" ]; then
	if [[ $database =~ "docker#" ]]; then
		docker_data=$(echo $database | cut -d "#" -f 2)
		container=$(echo $docker_data | cut -d ":" -f 1)
		database=$(echo $docker_data | cut -d ":" -f 2)
		sudo docker exec $container mysqldump --user=$DATABASE_USER -p$DATABASE_PASSWORD --lock-tables -h localhost $database > $dump_destination
	else
		mysqldump --user=backup_user --lock-tables -h localhost $database > $dump_destination
	fi
	if [ $? -eq 0 ]; then
		xz --compress ${BACKUPS_LOCAL_PATH}/${db_backup_filename}.sql
		gpg --symmetric --pinentry-mode loopback --passphrase $GPG_KEY ${BACKUPS_LOCAL_PATH}/${db_backup_filename}.sql.xz

	    #DAILY
	    cp ${BACKUPS_LOCAL_PATH}/${db_backup_filename}.sql.xz.gpg ${BACKUPS_LOCAL_PATH}/daily/${db_backup_filename}_daily_$(date +%A).sql.xz.gpg
	    if [ $? -eq 0 ]; then
		    db_message="Daily_DB_OK"
	    else
		    db_message="Daily_DB_FAILED"
		    some_cp_error="true"
	    fi

	    #WEEKLY 5 backups
	    if [ "$(date +%A)" == "Monday" ]; then
		    cp ${BACKUPS_LOCAL_PATH}/${db_backup_filename}.sql.xz.gpg ${BACKUPS_LOCAL_PATH}/weekly/${db_backup_filename}_${fulldate}_weekly.sql.xz.gpg
		    if [ $? -eq 0 ]; then
			    find ${BACKUPS_LOCAL_PATH}/weekly/${db_backup_filename}_*_weekly.sql.xz.gpg -mtime +35 -exec rm {} \;
			    db_message="${db_message}, Weekly_DB_OK"
		    else
			    db_message="${db_message}, Weekly_DB_FAILED"
			    some_cp_error="true"
		    fi
	    fi

	    #MONTHLY 6 backups
	    if [ "$(date +%d)" == "01" ]; then
		    cp ${BACKUPS_LOCAL_PATH}/${db_backup_filename}.sql.xz.gpg ${BACKUPS_LOCAL_PATH}/monthly/${db_backup_filename}_monthly_$(date +%M).sql.xz.gpg
		    if [ $? -eq 0 ]; then
			    find ${BACKUPS_LOCAL_PATH}/monthly/${db_backup_filename}_monthly_*.sql.xz.gpg -mtime +183 -exec rm {} \;
			    db_message="${db_message}, Monthly_DB_OK"
		    else
			    db_message="${db_message}, Monthly_DB_FAILED"
			    some_cp_error="true"
		    fi
	    fi

	    #YEARLY 5 backups
	    if [ "$(date +%j)" == "001" ]; then
		    cp ${BACKUPS_LOCAL_PATH}/${db_backup_filename}.sql.xz.gpg ${BACKUPS_LOCAL_PATH}/yearly/${db_backup_filename}_yearly_$(date +%Y).sql.xz.gpg
		    if [ $? -eq 0 ]; then
			    find ${BACKUPS_LOCAL_PATH}/yearly/${db_backup_filename}_yearly_*.sql.xz.gpg -mtime +1825 -exec rm {} \;
			    db_message="${db_message}, Yearly_DB_OK"
		    else
			    db_message="${db_message}, Yearly_DB_FAILED"
			    some_cp_error="true"
		    fi
	    fi

	    rm ${BACKUPS_LOCAL_PATH}/$db_backup_filename.sql.xz
	    rm ${BACKUPS_LOCAL_PATH}/$db_backup_filename.sql.xz.gpg

    else 
	    if [ -e ${BACKUPS_LOCAL_PATH}/$db_backup_filename.sql ]; then
		    rm ${BACKUPS_LOCAL_PATH}/$db_backup_filename.sql
	    fi

	    db_message="DB_dump_FAILED"
	    some_cp_error="true"
    fi  
fi


#######################
#                     #
#     FILES BACKUP    #
#                     #
#######################

if [ "$source_directory" != "none" ]
then

	#Prepare exclude string
	arr=($(echo "$dirnames_to_exclude" | tr ',' '\n'))
	exclude=""
	for i in ${arr[@]}
	do
		exclude="${exclude} --exclude=${i} "
	done
	exclude="$(echo -e "${exclude}" | sed -e 's/[[:space:]]*$//')"
	fs_backup_filename=${backup_name}_fs_backup

	#the source_directory can be a symlink and I prefer to work with real path
	real_source_directory=$(readlink -f ${source_directory})

	tar -C ${real_source_directory} -cJf ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz ${exclude} .

	if [ $? -eq 0 ]
	then
		gpg --symmetric --pinentry-mode loopback --passphrase $GPG_KEY ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz

	    #DAILY
	    cp ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz.gpg ${BACKUPS_LOCAL_PATH}/daily/${fs_backup_filename}_daily_$(date +%A).tar.xz.gpg
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
		    cp ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz.gpg ${BACKUPS_LOCAL_PATH}/weekly/${fs_backup_filename}_${fulldate}_weekly.tar.xz.gpg
		    if [ $? -eq 0 ] 
		    then
			    find ${BACKUPS_LOCAL_PATH}/weekly/${fs_backup_filename}_*_weekly.tar.xz.gpg -mtime +35 -exec rm {} \;
			    fs_message="${fs_message}, Weekly_FS_OK"
		    else
			    fs_message="${fs_message}, Weekly_FS_FAILED"
			    some_cp_error="true"
			    fi
			    fi

	    #MONTHLY 6 backups
	    if [ "$(date +%d)" == "01" ]
	    then
		    cp ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz.gpg ${BACKUPS_LOCAL_PATH}/monthly/${fs_backup_filename}_monthly_$(date +%M).tar.xz.gpg
		    if [ $? -eq 0 ] 
		    then
			    find ${BACKUPS_LOCAL_PATH}/monthly/${fs_backup_filename}_monthly_*.tar.xz.gpg -mtime +183 -exec rm {} \;
			    fs_message="${fs_message}, Monthly_FS_OK"
		    else
			    fs_message="${fs_message}, Monthly_FS_FAILED"
			    some_cp_error="true"
			    fi
			    fi

	    #YEARLY 5 backups
	    if [ "$(date +%j)" == "001" ]
	    then
		    cp ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz.gpg ${BACKUPS_LOCAL_PATH}/yearly/${fs_backup_filename}_yearly_$(date +%Y).tar.xz.gpg
		    if [ $? -eq 0 ] 
		    then
			    find ${BACKUPS_LOCAL_PATH}/yearly/${fs_backup_filename}_yearly_*.tar.xz.gpg -mtime +1825 -exec rm {} \;
			    fs_message="${fs_message}, Yearly_FS_OK"
		    else
			    fs_message="${fs_message}, Yearly_FS_FAILED"
			    some_cp_error="true"
		    fi
	    fi

	    rm ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz
	    rm ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz.gpg

	else 
	    if [ -e ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz ] 
	    then
		    rm ${BACKUPS_LOCAL_PATH}/${fs_backup_filename}.tar.xz
	    fi
	    files_message="FS_TAR_FAILED"
	    some_cp_error="true"
	fi
    fi
#REMOTE SYNC
if [ "$some_cp_error" == "false" ] && [ "$remote_backups_path" != "none" ]
then
    rclone sync ${BACKUPS_LOCAL_PATH} ${remote_backups_path} -P --mega-hard-delete 1> /dev/null
    if [ $? -eq 0 ]
    then
            rclone dedupe --dedupe-mode newest mega:/backups
	    remote_message="Remote_SYNC_OK"
	    some_remote_sync_error="false"
    else
	    remote_message="Remote_SYNC_FAILED"
	    some_remote_sync_error="true"
    fi
fi

URL=https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage
full_final_message="${backup_name} backup: ${db_message} and ${fs_message}. ${remote_message}"
curl -s -X POST $URL -d chat_id=$TELEGRAM_CHANNEL -d text="$full_final_message" > /dev/null 2>&1

if [ "$some_cp_error" == "true" ] || [ "$some_remote_sync_error" == "true" ]
then 
    echo "$full_final_message" >&2
else
    echo "$full_final_message"
fi
