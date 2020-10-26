CREATE USER IF NOT EXISTS 'replicant'@'%' identified by 'replicant_password';

grant replication slave on *.* to replicant;

flush privileges;