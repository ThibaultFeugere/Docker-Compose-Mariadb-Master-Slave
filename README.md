# TP6 


## 1. Créez une fichier Docker-compose.yml qui lance deux instances MariaDB

Contenu de Docker Compose :

```yaml
version:  '3.7'

services:
  master:
    image: mariadb:10.4
    restart: on-failure
    environment:
      MYSQL_ROOT_PASSWORD: password
    volumes:
      - ./master:/var/lib/mysql
      - ./backups:/backups
      - ./config/master.cnf:/etc/mysql/mariadb.conf.d/master.cnf
      - ./scripts:/scripts
    networks: 
      - internal

  slave:
    image: mariadb:10.4
    restart: on-failure
    environment:
      MYSQL_ROOT_PASSWORD: password
    volumes:
      - ./slave:/var/lib/mysql
      - ./backups:/backups
      - ./config/slave.cnf:/etc/mysql/mariadb.conf.d/slave.cnf
      - ./scripts:/scripts
    depends_on:
      - master
    networks: 
      - internal

networks:
  internal:
```

Je démarre les deux containers avec la commande : `docker-compose up -d` :

```bash
Creating network "tp6_internal" with the default driver
Creating tp6_master_1 ... done
Creating tp6_slave_1  ... done
```

On peut vérifier qu'ils fonctionnent avec `docker container ls` :

```bash
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
86092e898eb2        mariadb:10.4        "docker-entrypoint.s…"   4 seconds ago       Up 3 seconds        3306/tcp            tp6_slave_1
33b19a9b80c3        mariadb:10.4        "docker-entrypoint.s…"   5 seconds ago       Up 4 seconds        3306/tcp            tp6_master_1
```

## 2. Ajoutez les fichiers de configurations pour les serveurs Master et Slave

Comme on peut le voir dans les volumes la configuration du serveur Master est lié via : `- ./config/master.cnf:/etc/mysql/mariadb.conf.d/master.cnf`

Contenu de master.cnf :

```
[mariadb]
log-bin
server_id=1
log-basename=master
binlog-format=mixed
```

La configuration du serveur Slave est lié via : `- ./config/slave.cnf:/etc/mysql/mariadb.conf.d/slave.cnf`

Contenu de slave.cnf :

```
[mariadb]
log-bin
server_id=2
log-basename=slave
binlog-format=mixed
```

## 3. Créez un script pour ajouter l'utilisateur avec les droits de replication sur master

Le script en question est situé dans le dossier `scripts` et s'appelle `replicant.sql`.

Contenu de `replicant.sql` :

```sql
CREATE USER IF NOT EXISTS 'replicant'@'%' identified by 'replicant_password';

grant replication slave on *.* to replicant;

flush privileges;
```

Une fois mes deux instances levées, je l'exécute sur `master` avec la commande : `mysql -u root --password=password < scripts/replicant.sql`

On peut ensuite `unlock` les tables avec :

```
MariaDB [(none)]> UNLOCK TABLES;
Query OK, 0 rows affected (0.000 sec)
```

Pour vérifier que l'utilisateur est bien ajouté je vais vérifier dans la table `user` de la base de données `mysql`.

```
MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
3 rows in set (0.001 sec)
```

`use mysql;` puis `select * from user;` et on peut voir la ligne :

`replicant   | *E18EFDCD76D3AA50E5B448DFBEC3426C674E3053`

Une autre commande intéressante est : `SHOW MASTER STATUS;`

```
thibault@TPX1C:~/Documents/AdminBDD/tp6$ docker-compose exec master bash
root@33b19a9b80c3:/# mysql -u root -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 14
Server version: 10.4.15-MariaDB-1:10.4.15+maria~focal-log mariadb.org binary distribution

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> SHOW MASTER STATUS;
+-------------------+----------+--------------+------------------+
| File              | Position | Binlog_Do_DB | Binlog_Ignore_DB |
+-------------------+----------+--------------+------------------+
| master-bin.000005 |      1275|              |                  |
+-------------------+----------+--------------+------------------+
1 row in set (0.000 sec)

```

## 4. Assurez vous que les deux instances de base de données contiennent les mêmes données

On peut d'abord faire un `SHOW DATABASES;` sur les deux containers.

Master :

```
MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
3 rows in set (0.001 sec)
```

Slave :

```
MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
3 rows in set (0.000 sec)
```

Pour être encore plus sûr, je vais faire un dump sur `master` et `slave`.

Sur `master` : `mysqldump -u root --password=password --all-databases > backups/test2.sql`

Sur `slave` : `mysqldump -u root --password=password --all-databases > backups/test1.sql`

```
root@33b19a9b80c3:/# ls -al backups/    
total 8072
drwxr-xr-x 2 root root    4096 Oct 18 13:49 .
drwxr-xr-x 1 root root    4096 Oct 18 13:28 ..
-rw-r--r-- 1 root root 4124817 Oct 18 13:48 test1.sql
-rw-r--r-- 1 root root 4124817 Oct 18 13:49 test2.sql
```

On peut voir que le poids est identique j'en déduis donc que le contenu est identique.

## 5. Démarrez le serveur master

Le serveur Master est démarré 

## 6. Ajoutez le master au slave

Via les anciennes commandes, nous avons les informations nécessaires pour ajouter le `master` au `slave`.

```sql
CHANGE MASTER TO MASTER_HOST="192.168.112.2", MASTER_USER='replicant', MASTER_PASSWORD='replicant_password', MASTER_PORT=3306, MASTER_LOG_FILE='master-bin.000005', MASTER_LOG_POS=1275, MASTER_CONNECT_RETRY=10;
Query OK, 0 rows affected (0.045 sec)

MariaDB [(none)]> START SLAVE;
Query OK, 0 rows affected (0.002 sec)
```

## 7. Démarrez et vérifiez l'état du slave

```sql
MariaDB [(none)]> START SLAVE;
Query OK, 0 rows affected (0.002 sec)
MariaDB [(none)]> SHOW SLAVE STATUS;
| Slave_IO_State | Master_Host   | Master_User | Master_Port | Connect_Retry | Master_Log_File    | Read_Master_Log_Pos | Relay_Log_File         | Relay_Log_Pos | Relay_Master_Log_File | Slave_IO_Running | Slave_SQL_Running | Replicate_Do_DB | Replicate_Ignore_DB | Replicate_Do_Table | Replicate_Ignore_Table | Replicate_Wild_Do_Table | Replicate_Wild_Ignore_Table | Last_Errno | Last_Error | Skip_Counter | Exec_Master_Log_Pos | Relay_Log_Space | Until_Condition | Until_Log_File | Until_Log_Pos | Master_SSL_Allowed | Master_SSL_CA_File | Master_SSL_CA_Path | Master_SSL_Cert | Master_SSL_Cipher | Master_SSL_Key | Seconds_Behind_Master | Master_SSL_Verify_Server_Cert | Last_IO_Errno | Last_IO_Error                                                                                                                     | Last_SQL_Errno | Last_SQL_Error | Replicate_Ignore_Server_Ids | Master_Server_Id | Master_SSL_Crl | Master_SSL_Crlpath | Using_Gtid | Gtid_IO_Pos | Replicate_Do_Domain_Ids | Replicate_Ignore_Domain_Ids | Parallel_Mode | SQL_Delay | SQL_Remaining_Delay | Slave_SQL_Running_State                                                     | Slave_DDL_Groups | Slave_Non_Transactional_Groups | Slave_Transactional_Groups |
|                | 192.168.112.2 | replicant   |        3306 |            10 | master1-bin.000005 |                1275 | slave-relay-bin.000001 |             4 | master1-bin.000005    | No               | Yes               |                 |                     |                    |                        |                         |                             |          0 |            |            0 |                1275 |             256 | None            |                |             0 | No                 |                    |                    |                 |                   |                |                  NULL | No                            |          1236 | Got fatal error 1236 from master when reading data from binary log: 'Could not find first log file name in binary log index file' |              0 |                |                             |                1 |                |                    | No         |             |                         |                             | conservative  |         0 |                NULL | Slave has read all relay log; waiting for the slave I/O thread to update it |                0 |                              0 |                          0 |
1 row in set (0.001 sec)
```

On démarre avec `START SLAVE;` et on regarde le status du `slave` avec `SHOW SLAVE STATUS;` (désolé pour la mise en forme dans le terminal car rend vraiment pas bien mais on voit quand même les informations importantes).

## 8. Créez une nouvelle base de données et une nouvelle table sur le serveur Master et vérifier que les données sont présentes sur le serveur slave

Contenu dans `data.sql`.

```
DROP DATABASE IF EXISTS teams;
CREATE DATABASE teams;
USE teams;
CREATE TABLE games
(
    id           VARCHAR(36) NOT NULL,
    match_date   DATETIME    NOT NULL,
    victory      BOOLEAN     NOT NULL,
    observations TEXT,
    PRIMARY KEY (id)
);
CREATE TABLE players
(
    id         VARCHAR(36)  NOT NULL,
    firstname  varchar(255) NOT NULL,
    lastname   varchar(255) NOT NULL,
    start_date DATE         NOT NULL,
    PRIMARY KEY (id)
);

INSERT INTO games VALUES (uuid(), '2020-12-02', 1, 'Exceptionnel');
INSERT INTO games VALUES (uuid(), '2022-12-02', 0, 'Decevant');
INSERT INTO games VALUES (uuid(), '2023-12-02', 1, 'Pas mal');

```

Sur `Master` et `Slave` :

```
MariaDB [teams]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| teams              |
+--------------------+
4 rows in set (0.000 sec)
```

```
MariaDB [teams]> select * from games;
+--------------------------------------+---------------------+---------+--------------+
| id                                   | match_date          | victory | observations |
+--------------------------------------+---------------------+---------+--------------+
| 67684391-1162-11eb-acce-0242c0a87002 | 2022-12-02 00:00:00 |       0 | Decevant     |
| e451f3f7-1161-11eb-acce-0242c0a87002 | 2020-12-02 00:00:00 |       1 | Exceptionnel |
| e453e670-1161-11eb-acce-0242c0a87002 | 2022-12-02 00:00:00 |       0 | Decevant     |
| e455352f-1161-11eb-acce-0242c0a87002 | 2023-12-02 00:00:00 |       1 | Pas mal      |
+--------------------------------------+---------------------+---------+--------------+
```


## Arborescence

Comme d'habitude une petite arborescence pour bien visualiser ce que j'ai mis par écrit.

```
thibault@TPX1C:~/Documents/AdminBDD/tp6$ tree
.
├── backups
│   ├── test1.sql
│   └── test2.sql
├── config
│   ├── master.cnf
│   └── slave.cnf
├── docker-compose.yml
├── FEUGERE_Thibault_TP6.md
├── maria
│   ├── aria_log.00000001
│   ├── aria_log_control
│   ├── ib_buffer_pool
│   ├── ibdata1
│   ├── ib_logfile0
│   ├── ib_logfile1
│   ├── master1-bin.000001
│   ├── master1-bin.000002
│   ├── master1-bin.index
│   ├── master1-bin.state
│   ├── master-bin.000001
│   ├── master-bin.000002
│   ├── master-bin.000003
│   ├── master-bin.000004
│   ├── master-bin.000005
│   ├── master-bin.index
│   ├── master-bin.state
│   ├── multi-master.info
│   ├── mysql [error opening dir]
│   ├── performance_schema [error opening dir]
│   ├── slave-bin.000001
│   ├── slave-bin.000002
│   ├── slave-bin.000003
│   ├── slave-bin.000004
│   ├── slave-bin.000005
│   ├── slave-bin.000006
│   ├── slave-bin.index
│   └── slave-bin.state
├── master
│   ├── aria_log.00000001
│   ├── aria_log_control
│   ├── ib_buffer_pool
│   ├── ibdata1
│   ├── ib_logfile0
│   ├── ib_logfile1
│   ├── ibtmp1
│   ├── master-bin.000001
│   ├── master-bin.000002
│   ├── master-bin.000003
│   ├── master-bin.000004
│   ├── master-bin.000005
│   ├── master-bin.index
│   ├── multi-master.info
│   ├── mysql [error opening dir]
│   ├── performance_schema [error opening dir]
│   └── teams [error opening dir]
├── scripts
│   ├── data.sql
│   └── replicant.sql
└── slave
    ├── aria_log.00000001
    ├── aria_log_control
    ├── ib_buffer_pool
    ├── ibdata1
    ├── ib_logfile0
    ├── ib_logfile1
    ├── ibtmp1
    ├── master.info
    ├── multi-master.info
    ├── mysql [error opening dir]
    ├── performance_schema [error opening dir]
    ├── relay-log.info
    ├── slave-bin.000001
    ├── slave-bin.000002
    ├── slave-bin.000003
    ├── slave-bin.000004
    ├── slave-bin.000005
    ├── slave-bin.index
    ├── slave-relay-bin.000001
    ├── slave-relay-bin.000002
    ├── slave-relay-bin.index
    └── teams [error opening dir]

14 directories, 67 files
```
