#To desencrypt
First create and enter inside de directory where you want to put your project files.
Put there your two backup files.

To create the desencrypted the files:
```
gpg --batch --pinentry-mode loopback --decrypt-files *.gpg
```


To decompress the filesystem of your project execute:
```
tar -xJvf *.tar.xz
```

To decompress the database dump file:
```
xz -d *.sql.xz
```

To dump the sql file into a mysql database previously created:
```
mysq -u user_with_proper_privileges --password database_name < sql_dump_file
```

