This bash script automatizes the backup of a folder and his content and a database.

Is primary written to be used with wordpress installations but if your project is composed of a folder with content and a mysql/mariadb database, it will work.

You will need to have installed in your system:
- gpg to encrypt.
- tar and xz to compress.
- rclone to upload to your cloud provider.
- curl to send telegram messages automatically with the final status of the backup.

I have a cron job for each website running every day at night and I receive a telegram message with the status of each website backup.

There are hardcoded data that in the future will in an external config file.

There are user config files for the credentials of mysql and telegram, that will be moved to the general config file.

I'm concerned about the security issues. So I have to know the best way to deal with this.

At this time you have to config rclone four yourself. Mega is hardcoded to be used. If you use another cloud provider, modify the script. 

After the complaints...


# To backup

Assuming that:
- the linux user for the backups is backer.
- the script is /home/backer/backup-script/backup.sh
- the backup name will be savetheworld.backup
- the filesystem of the web is in /var/www/savetheworld/live (it can be a symlink)
- the database name is savetheworld_database
- we want to exclude the folders wp-includes, wp-admin, cache and node_modules
- we have a previously configured mega account in rclone.
- the backup files will be uploaded to the folder backups on Mega.

that was a lot of assumptions!!!

This is the complete command:
```
bash /home/backer/backup-script/backup.sh savetheworld.backup /var/www/savetheworld/live savetheworld_database mega:/backups wp-includes,wp-admin,cache,node_modules
```

## About database
You can skip the database backup using "none" (without the quotes) as the database name.

# About files
You can skip the backup of the files using "none" (without the quooootes) as the root directory.

## About docker
If your database is into a docker container, the database name has to be "docker#container_name:database_name".

It's up to you to prepare the container to be accessed securely. 

If the root directory containing the files that you want to backup are into a docker container, you have to mount it into the docker host.

## About remote
If you can skip the remote connection using "none" (without the quotes) as the remote name.


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

