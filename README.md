To desencrypt
=============
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
mysq -u db_user_with_proper_privileges --password database_name < sql_dump_file
```

