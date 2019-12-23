Para desencriptar:
gpg --batch --passphrase "long%great_password" example-fs-file.tar.xz.gpg
Esto no borra el archivo encriptado si no que se crea uno nuevo desencriptado.

Para descomprimir archivo fs:
tar -xJvf example-fs-file.tar.xz
Esto descomprime en la ruta actual. Lo primero que se crea es un directorio madre de la web y dentro de él todo lo demás.

Para descomprimir archivo db:
xz -d example-db-file.sql.xz
