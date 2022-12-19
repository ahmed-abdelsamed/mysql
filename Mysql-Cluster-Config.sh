{https://www.digitalocean.com/community/tutorials/how-to-create-a-multi-node-mysql-cluster-on-ubuntu-18-04}
ssh copy id
ipv6 disable

vi /etc/sysctl.d/70-ipv6.conf

net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

sysctl --load /etc/sysctl.d/70-ipv6.conf
ip a | grep inet6

sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
cat /etc/selinux/config | grep SELINUX=

systemctl disable firewalld
systemctl stop firewalld
----------------------------------------------
### Step 1 — Installing and Configuring the Cluster Manager

https://dev.mysql.com/downloads/cluster/

(mysql-cluster-community-management-server-8.0.31-1.el8.x86_64.rpm)

cd ~
wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0.31/mysql-cluster-community-management-server-8.0.31-1.el8.x86_64.rpm


 rpm -ivh mysql-cluster-community-management-server-8.0.31-1.el8.x86_64.rpm

sudo mkdir /var/lib/mysql-cluster

sudo nano /var/lib/mysql-cluster/config.ini
'
[ndbd default]
# Options affecting ndbd processes on all data nodes:
NoOfReplicas=2	# Number of replicas

[ndb_mgmd]
# Management process options:
hostname=mysql-mgm.home.lab  # Hostname of the manager
datadir=/var/lib/mysql-cluster 	# Directory for the log files

[ndbd]
hostname=mysql-data-1.home.lab # Hostname/IP of the first data node
NodeId=2			# Node ID for this data node
datadir=/usr/local/mysql/data	# Remote directory for the data files

[ndbd]
hostname=mysql-data-2.home.lab # Hostname/IP of the second data node
NodeId=3			# Node ID for this data node
datadir=/usr/local/mysql/data	# Remote directory for the data files

[mysqld]
# SQL node options:
hostname=mysql-mgm.home.lab # In our case the MySQL server/client is on the same Droplet as the cluster manager

'

sudo ndb_mgmd -f /var/lib/mysql-cluster/config.ini

sudo pkill -f ndb_mgmd

sudo nano /etc/systemd/system/ndb_mgmd.service
'
[Unit]
Description=MySQL NDB Cluster Management Server
After=network.target auditd.service

[Service]
Type=forking
ExecStart=/usr/sbin/ndb_mgmd -f /var/lib/mysql-cluster/config.ini
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.targe
'

sudo systemctl daemon-reload
sudo systemctl enable ndb_mgmd
sudo systemctl start ndb_mgmd
------------------------
### Step 2 — Installing and Configuring the Data Nodes

(mysql-cluster-community-data-node-8.0.31-1.el8.x86_64.rpm)

cd ~
wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster-community-data-node-8.0.31-1.el8.x86_64.rpm
sudo rpm -ivh  mysql-cluster-community-data-node-8.0.31-1.el8.x86_64.rpm

sudo nano /etc/my.cnf
'
[mysql_cluster]
# Options for NDB Cluster processes:
ndb-connectstring=mysql-mgm.home.lab  # location of cluster manage
'
sudo mkdir -p /usr/local/mysql/data
sudo ndbd

sudo pkill -f ndbd

sudo nano /etc/systemd/system/ndbd.service
'
[Unit]
Description=MySQL NDB Data Node Daemon
After=network.target auditd.service

[Service]
Type=forking
ExecStart=/usr/sbin/ndbd
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
'
sudo systemctl daemon-reload
sudo systemctl enable ndbd
sudo systemctl start ndbd
sudo systemctl status ndbd
-----------------------------------------
### Step 3 — Configuring and Starting the MySQL Server and Clien
https://dev.mysql.com/downloads/cluster/
cd ~
wget https://dev.mysql.com/get/Downloads/MySQL-Cluster-8.0/mysql-cluster8.0.3-1rhel8.amd64.rpm-bundle.tar

mkdir install
tar -xvf mysql-cluster8.0.3-1rhel8.amd64.rpm-bundle.tar -C install/

sudo rpm -ivh mysql-common_ver.rhel_amd64.deb
sudo rpm -ivh mysql-cluster-community-client_ver.rhel8_amd64.rpm
sudo rpm -ivh mysql-client_8.0rhel_amd64.rpm
sudo rpm -ivh mysql-cluster-community-server_8.0_amd64.rpm

sudo dpkg -i mysql-server_8 rhel8_amd64.rpm

sudo nano /etc/mysql/my.cnf
append

. . .
[mysqld]
# Options for mysqld process:
ndbcluster                      # run NDB storage engine

[mysql_cluster]
# Options for NDB Cluster processes:
ndb-connectstring=mysql-mgm.home.lab  # location of management server

----------------------
sudo systemctl restart mysql
sudo systemctl enable mysql
----------------------------------
### Step 4 — Verifying MySQL Cluster Installation

mysql -u root -p
mysql>  SHOW ENGINE NDB STATUS \G


'
Output

*************************** 1. row ***************************
  Type: ndbcluster
  Name: connection
Status: cluster_node_id=4, connected_host=198.51.100.2, connected_port=1186, number_of_data_nodes=2, number_of_ready_data_nodes=2, connect_count=0
. . .
'

## Open the Cluster management console, ndb_mgm using the command:
ndb_mgm

'
Output
-- NDB Cluster -- Management Client --
ndb_mgm>
'

ndb_mgm> SHOW

'
Output
Connected to Management Server at: 198.51.100.2:1186
Cluster Configuration
---------------------
[ndbd(NDB)] 2 node(s)
id=2    @198.51.100.0  (mysql-5.7.22 ndb-7.6.6, Nodegroup: 0, *)
id=3    @198.51.100.1  (mysql-5.7.22 ndb-7.6.6, Nodegroup: 0)

[ndb_mgmd(MGM)] 1 node(s)
id=1    @198.51.100.2  (mysql-5.7.22 ndb-7.6.6)

[mysqld(API)]   1 node(s)
id=4    @198.51.100.2  (mysql-5.7.22 ndb-7.6.6)
'

