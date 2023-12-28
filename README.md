This bash script automatizes the backup of a folder and his content and a database.

Is primary written to be used with wordpress installations but if your project is composed of a folder with content and a mysql/mariadb database, it will work.

You will need to have installed in your system:
- gpg to encrypt.
- tar and xz to compress.
- rclone to upload to your cloud provider.
- curl to send telegram messages automatically with the final status of the backup.

I have a cron job for each website running every day at night and I receive a telegram message with the final status of each website backup.

This an example of a cron entry that runs everyday at 5:00 am and that writes final status to a log file:
```
00 5    *   *   *     bash /home/backup_user/backup-script/backup.sh savetheworld.com /home/backup_user/services/savetheworld-web/html docker#savetheworld_db_container_name:unguessable.db-password mega:/backups wp-includes,wp-admin,cache,node_modules,logs 2>&1 | sed "s/^/$(date) /" >> /var/log/savetheworld.backup.log
```

## About the database
You will need to provide the database user and password to perform de database dump. As this data will live in plain text in a config file, I encourage you to create a user with the minimal permission to do the dump. As an example, you can execute the next commands inside the mysql console (don't take this as a source of truth):
```
CREATE USER 'backup_user'@'%' IDENTIFIED BY 'super-unguessable.password';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'backup_user'@'%';
GRANT LOCK TABLES, SELECT ON `savetheworld-database`.* TO 'backup_user'@'%' IDENTIFIED BY 'super-unguessable.password';
```

## Configuration
The configuration data is centralized in backup.conf file that could be into the root of the home directory of the user who executes de script or in /etc folder.
Secure this file, for example allowing only the owner to read it:
```
chmod 400 /etc/backup.conf
```

There is a sample config file that you can copy and modify with your data.

At this time you have to config rclone four yourself. Mega is hardcoded to be used. If you use another cloud provider, modify the script. 

After the complaints...


# To backup

Assuming that:
- the linux user for the backups is backup_user.
- the script is /home/backup_user/backup-script/backup.sh
- the backup name will be savetheworld.backup
- the filesystem of the web is in /var/www/savetheworld/live (it can be a symlink)
- the database name is savetheworld_database
- we want to exclude the folders wp-includes, wp-admin, cache and node_modules
- we have a previously configured mega account in rclone.
- the backup files will be uploaded to the folder backups on Mega.

that was a lot of assumptions!!!

This is the complete command:
```
bash /home/backup_user/backup-script/backup.sh \
   savetheworld.backup \
   /var/www/savetheworld/live \
   savetheworld_database \
   mega:/backups \
   wp-includes,wp-admin,cache,node_modules
```

## About database
You can skip the database backup using "none" (without the quotes) as the database name.

## About files
You can skip the backup of the files using "none" (without the quooootes) as the root directory.

## About docker
If your database is into a docker container, the database name has to be "docker#container_name:database_name".

It's up to you to prepare the container to be accessed securely. 

If the root directory containing the files that you want to backup are into a docker container, you have to mount it into the docker host.

## About remote
You can skip the remote connection using "none" (without the quotes) as the remote name.


# To restore
First create and enter inside the directory where you want to put your project files and put there your two backup files.

To obtain two new desencrypted files:
```
gpg -d --pinentry-mode loopback --decrypt-files *.gpg
```

To decompress the filesystem of your project execute:
```
tar -xJvf *.tar.xz
```

To decompress the database dump file:
```
xz -d *.sql.xz
```

To dump the sql file into a mysql database **previously created**:
```
mysql -u db_user_with_proper_privileges --password database_name < sql_dump_file
```

