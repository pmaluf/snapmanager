# snapmanager.sh

This script take a backup of MySQL Database doing a snapshot of the NFS volume on NetApp.

## Notice

This script was tested in:

* Linux
  * OS Distribution: CentOS release 6.5 (Final)
  * MySQL > 5.5

## Prerequisities

* Create an user on NetApp with vol_snapshot privilege and setup the SSH passwordless authentication. 

Change it the SSHUSER variable on snapmanager.sh 
```
SSHUSER="<NETAPP_SSHPASSWORDLESS_USER>"
```

* Create an user on MySQL Database with RELOAD and SUPER privileges. 
```
mysql> GRANT RELOAD, SUPER ON *.* TO 'backupmanager'@'%' IDENTIFIED BY "<MYPASSWORD>"; 
mysql> flush privileges;
```

## How to use it

```
#
# snapmanager.sh - MySQL backup via snapshot LVM or NETAPP
# Created: Paulo Victor Maluf - 01/2014
#
# Parameters:
#
#   snapmanager.sh --help
#
#    Parameter           Short Description                                                        Default
#    ------------------- ----- ------------------------------------------------------------------ --------------
#    --hostname             -H [REQUIRED] Hostname will be backuped                               localhost
#    --port                 -P [OPTIONAL] Port to connect to MySQL                                3306
#    --username             -u [OPTIONAL] MySQL username                                          backupmanager
#    --password             -p [OPTIONAL] MySQL password
#    --snap-name            -n [OPTIONAL] Label use for snapshot backup
#    --retention	    -r [OPTIONAL] How many snapshots will be retained			  7
#    --volume-name          -v [REQUIRED] Volume name or nfs path
#    --list                 -l [OPTIONAL] List snapshots
#    --type                 -t [REQUIRED] Snapshot type: NETAPP or LVM                            NETAPP
#    --netapp-server        -s [OPTIONAL] Netapp server
#    --skip-lock            -S [OPTIONAL] Skip Lock tables
#    --logical-backup       -L [OPTIONAL] Take a logical backup from snapshot volume.
#    --help                 -h [OPTIONAL] help
#
#   Ex.: snapmanager.sh [OPTIONS] --hostname <HOST> --volume-name <NFS/LVM>
#        snapmanager.sh --hostname mysql-db-1 --volume-name nfs_mysql_db_1
#        snapmanager.sh -v nfs_teste_linux -s netapp-db-1 -t NETAPP --list
```

* Take backup of BINLOG with the --skip-lock option: 
```
$ snapmanager.sh -v nfs_db_mysql_1_binlog -s netapp-1 -H mysql-db-1 -t NETAPP --skip-lock -r 48

Snapshot Name: nfs_db_mysql_1_binlog-060716191201
Checking MySQL connection... [ OK ]
Checking SSH connection... [ OK ]
Checking netapp volume...[ OK ]
Flush logs for binlog rotate...[ OK ]
Synchronize data on disk with memory...[ OK ]
Creating snapshot...[ OK ]
Purging old snapshots based on retention policy of 48 snapshots.
Purge snapshot: nfs_db_mysql_1_binlog-040716200001 [ OK ]

```
* Take a consistent backup of database with temporary read-only lock: 
```
snapmanager.sh -v nfs_db_mysql_1_data -s netapp-1 -H mysql-db-1 -t NETAPP -r 30
Snapshot Name: nfs_radius_db_mysql_1_data-060716191356
Checking MySQL connection... [ OK ]
Checking SSH connection... [ OK ]
Checking netapp volume...[ OK ]
Locking tables with read only mode...[ OK ]
Flush logs for binlog rotate...[ OK ]
Synchronize data on disk with memory...[ OK ]
Creating snapshot...[ OK ]
Unlocking MySQL tables...[ OK ]
Purging old snapshots based on retention policy of 30 snapshots.
Purge snapshot: nfs_db_mysql_1_data-070616000001 [ OK ]
```

* List all snapshots
```
$ ./snapmanager.sh -v nfs_db_mysql_1 -s netapp-1 -H mysql-db-1 -t NETAPP --list
Checking SSH connection... [ OK ]
Checking netapp volume...[ OK ]
Listing snapshots...
Volume nfs_db_mysql_1
working...

  %/used       %/total  date          name
----------  ----------  ------------  --------
  2% ( 2%)    1% ( 1%)  Jul 06 00:05  nfs_db_mysql_1-060716000401
  5% ( 3%)    2% ( 1%)  Jul 05 00:06  nfs_db_mysql_1-050716000401
  7% ( 2%)    3% ( 1%)  Jul 04 00:05  nfs_db_mysql_1-040716000401
  9% ( 2%)    4% ( 1%)  Jul 03 00:05  nfs_db_mysql_1-030716000401
 11% ( 3%)    6% ( 1%)  Jul 02 00:05  nfs_db_mysql_1-020716000401
 13% ( 2%)    7% ( 1%)  Jul 01 00:09  nfs_db_mysql_1-010716000401
 14% ( 2%)    8% ( 1%)  Jun 30 00:05  nfs_db_mysql_1-300616000401
 16% ( 3%)    9% ( 1%)  Jun 29 00:05  nfs_db_mysql_1-290616000401
 18% ( 2%)   10% ( 1%)  Jun 28 00:05  nfs_db_mysql_1-280616000401
 19% ( 2%)   11% ( 1%)  Jun 27 00:05  nfs_db_mysql_1-270616000401
 21% ( 2%)   12% ( 1%)  Jun 26 00:05  nfs_db_mysql_1-260616000401
 22% ( 2%)   13% ( 1%)  Jun 25 00:05  nfs_db_mysql_1-250616000401
 24% ( 2%)   14% ( 1%)  Jun 24 00:05  nfs_db_mysql_1-240616000401
 24% ( 1%)   15% ( 1%)  Jun 23 00:14  nfs_db_mysql_1-230616000401
 26% ( 3%)   16% ( 1%)  Jun 22 00:05  nfs_db_mysql_1-220616000401
 28% ( 5%)   18% ( 2%)  Jun 21 00:05  nfs_db_mysql_1-210616000401
 30% ( 2%)   19% ( 1%)  Jun 20 00:05  nfs_db_mysql_1-200616000401
 31% ( 2%)   20% ( 1%)  Jun 19 00:05  nfs_db_mysql_1-190616000401
 32% ( 3%)   22% ( 1%)  Jun 18 00:05  nfs_db_mysql_1-180616000401
 33% ( 3%)   23% ( 1%)  Jun 17 00:05  nfs_db_mysql_1-170616000401
 35% ( 3%)   24% ( 1%)  Jun 16 00:05  nfs_db_mysql_1-160616000401
 36% ( 3%)   25% ( 1%)  Jun 15 00:05  nfs_db_mysql_1-150616000401
 37% ( 2%)   26% ( 1%)  Jun 14 00:05  nfs_db_mysql_1-140616000401
 38% ( 2%)   27% ( 1%)  Jun 13 00:05  nfs_db_mysql_1-130616000401
 38% ( 2%)   28% ( 1%)  Jun 12 00:05  nfs_db_mysql_1-120616000401
 39% ( 2%)   30% ( 1%)  Jun 11 00:05  nfs_db_mysql_1-110616000401
 40% ( 2%)   31% ( 1%)  Jun 10 00:05  nfs_db_mysql_1-100616000401
 41% ( 2%)   32% ( 1%)  Jun 09 00:05  nfs_db_mysql_1-090616000401
 42% ( 2%)   33% ( 1%)  Jun 08 00:04  nfs_db_mysql_1-080616000401
 43% ( 3%)   34% ( 1%)  Jun 07 00:05  nfs_db_mysql_1-070616000402
```

* Schedule the backup on crontab or cron.d: 

Example:
```
# Backup Snapshot BINLOG
0 * * * * /u00/scripts/generic/snapmanager/snapmanager.sh -v nfs_db_mysql_1_binlog -s netapp-1 -H mysql-1 -t NETAPP --skip-lock -r 48 > /dev/null 2>&1

# Backup Snapshot DB
0 0 * * * /u00/scripts/generic/snapmanager/snapmanager.sh -v nfs_db_mysql_1_data -s netapp-2 -H mysql-1 -t NETAPP -r 30  > /dev/null 2>&1
```

## License

This project is licensed under the MIT License - see the [License.md](License.md) file for details
