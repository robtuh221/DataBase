# Монитрование папки в отдельный рейд массив 
mkdir -p /mnt/database/
mkfs.ext4 /dev/sdb
mount -t ext4 /dev/sdc /mnt/database/
blkid /dev/sdb
nano /etc/fstab
UUID=1234-5678-9ABC-DEF0  /mnt/database/  ext4  defaults  0  2
# Что бы заинициализировать базу в отдельную папку нужно создать подпапку в которой будет лежать база
mkdir -p /mnt/database/pgdata
# раздем права на директорию
chown postgres:postgres -R /mnt/database/
chmod 777 -R /mnt/database/
# Инициализируем базу
sudo -u postgres /opt/pgpro/std-15/bin/initdb -D /mnt/database/pgdata

# Ставим Postgres PRO 
apt-get update
apt-get install wget

#### ETCD ####
wget https://git.altlinux.org/tasks/322021/build/100/x86_64/rpms/etcd-3.5.9-alt1.x86_64.rpm
apt-get install ./etcd-3.5.9-alt1.x86_64.rpm

# Создаем папку etcd и раздаем на нее права
mkdir -p /mnt/database/etcd 
chown postgres:postgres -R /mnt/database/etcd
chmod 777 -R /mnt/database/etcd

nano /lib/systemd/system/etcd.service

[Unit]
Description=etcd key-value store
Documentation=https://github.com/etcd-io/etcd
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/mnt/database/etcd
EnvironmentFile=-/etc/etcd/etcd.conf
User=etcd
ExecStart=/usr/sbin/etcd
Restart=always
RestartSec=10s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target


    cat <<EOF > /etc/etcd/etcd.conf
ETCD_NAME="pp_services_1"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.230.101:2379"
ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.230.101:2380"
ETCD_INITIAL_CLUSTER_TOKEN="cluster2U"
ETCD_INITIAL_CLUSTER="pp_services_1=http://192.168.230.101:2380,pp_services_2=http://192.168.230.102:2380,pp_services_3=http://192.168.230.103:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_DATA_DIR="/mnt/database/etcd"
ETCD_ELECTION_TIMEOUT="5000"
ETCD_HEARTBEAT_INTERVAL="1000"
EOF

systemctl enable etcd
rm -rf /var/lib/etcd/member/*
service etcd start
systemctl status etcd.service

etcdctl endpoint status --write-out=table
etcdctl member list --write-out=table
etcdctl cluster-health # для старой версии ETCD
etcdctl endpoint health # для новой

#### PsqlPRO ####

# добавляем репозиторий PRO
wget https://repo.postgrespro.ru/std/std-15/keys/pgpro-repo-add.sh
sh pgpro-repo-add.sh

apt-get install postgrespro-std-15
systemctl status postgrespro-std-15.service
systemctl disable postgrespro-std-15.service
rm -rf /var/lib/pgpro/std-15/data/*
ls -la /var/lib/pgpro/std-15/data/

#### Patroni ####

apt-get install patroni
systemctl edit --full --force patroni.service

[Unit]
Description=Runners to orchestrate a high-availability PostgreSQLPRO
After=network.target
ConditionPathExists=/etc/patroni/patroni.yml

[Service]
Type=simple

User=postgres
Group=postgres

# Read in configuration file if it exists, otherwise proceed
EnvironmentFile=-/etc/patroni_env.conf

# the default is the user's home directory, and if you want to change it, you must provide an absolute path.
# WorkingDirectory=/home/sameuser

# Pre-commands to start watchdog device
# Uncomment if watchdog is part of your patroni setup
#ExecStartPre=-/usr/bin/sudo /sbin/modprobe softdog
#ExecStartPre=-/usr/bin/sudo /bin/chown postgres /dev/watchdog

# Start the patroni process
ExecStart=/usr/bin/patroni /etc/patroni/patroni.yml

# Send HUP to reload from patroni.yml
ExecReload=/bin/kill -s HUP $MAINPID

# only kill the patroni process, not it's children, so it will gracefully stop postgres
KillMode=process

# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=60

# Do not restart the service if it crashes, we want to manually inspect database on failure
Restart=on-failure

[Install]
WantedBy=multi-user.target


systemctl daemon-reload
systemctl enable patroni
mkdir /etc/patroni
chmod 777 /etc/patroni
chown postgres:postgres /etc/patroni

    cat <<EOF > /etc/patroni/patroni.yml
scope: Cluster2U
name: patroni1
namespace: /service

restapi:
  listen: 0.0.0.0:8008
  connect_address: 192.168.230.101:8008
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  authentication:
#    username: patroni
#    password: cluster2U

etcd3:
  hosts: 192.168.230.101:2379,192.168.230.102:2379,192.168.230.103:2379

# shared_buffers: Память, выделенная под буферы PostgreSQL. Обычно рекомендуется около 25% от общей памяти.
# effective_cache_size: Память, доступная для кеширования данных операционной системы. Обычно устанавливается в 50-75% от общей памяти.
# work_mem: Память, выделенная под сортировку и хеширование в запросах. Рекомендуется значение от 1 до 2% от общей памяти на каждое CPU.
# maintenance_work_mem: Память для операций по обслуживанию, таких как вакуумирование и создание индексов. Обычно устанавливается на уровне 5-10% от общей памяти.
# max_worker_processes, max_parallel_workers, max_parallel_workers_per_gather: Количество параллельных процессов и рабочих процессов, которые могут выполняться одновременно.
bootstrap:
  method: initdb
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    master_start_timeout: 300
    synchronous_mode: true
    synchronous_mode_strict: false
    synchronous_node_count: 1
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        max_connections: 500
        superuser_reserved_connections: 5
        password_encryption: scram-sha-256
        max_locks_per_transaction: 512
        max_prepared_transactions: 0
        huge_pages: try
        shared_buffers: 4GB  # 25% от 16 GB
        effective_cache_size: 12GB  # 75% от 16 GB
        work_mem: 32MB  # 2% от 16 GB / 8 CPU
        maintenance_work_mem: 1GB  # 6.25% от 16 GB
        checkpoint_timeout: 15min
        checkpoint_completion_target: 0.9
        min_wal_size: 2GB
        max_wal_size: 8GB
        wal_buffers: 32MB
        default_statistics_target: 1000
        seq_page_cost: 1
        random_page_cost: 1.1
        effective_io_concurrency: 200
        synchronous_commit: on
        autovacuum: on
        autovacuum_max_workers: 5
        autovacuum_vacuum_scale_factor: 0.01
        autovacuum_analyze_scale_factor: 0.01
        autovacuum_vacuum_cost_limit: 500
        autovacuum_vacuum_cost_delay: 2
        autovacuum_naptime: 1s
        max_files_per_process: 4096
        archive_mode: on
        archive_timeout: 1800s
        archive_command: cd .
        wal_level: hot_standby
        wal_keep_size: 2GB
        max_wal_senders: 10
        max_replication_slots: 10
        hot_standby: on
        wal_log_hints: on
        wal_compression: on
        shared_preload_libraries: pg_stat_statements,auto_explain
        pg_stat_statements.max: 10000
        pg_stat_statements.track: all
        pg_stat_statements.track_utility: false
        pg_stat_statements.save: true
        auto_explain.log_min_duration: 10s
        auto_explain.log_analyze: true
        auto_explain.log_buffers: true
        auto_explain.log_timing: false
        auto_explain.log_triggers: true
        auto_explain.log_verbose: true
        auto_explain.log_nested_statements: true
        auto_explain.sample_rate: 0.01
        track_io_timing: on
        log_lock_waits: on
        log_temp_files: 0
        track_activities: on
        track_activity_query_size: 4096
        track_counts: on
        track_functions: all
        log_checkpoints: on
        logging_collector: on
        log_truncate_on_rotation: on
        log_rotation_age: 1d
        log_rotation_size: 0
        log_line_prefix: '%t [%p-%l] %r %q%u@%d '
        log_filename: postgresql-%a.log
        log_directory: /var/log/pgsql/
        hot_standby_feedback: on
        max_standby_streaming_delay: 30s
        wal_receiver_status_interval: 10s
        idle_in_transaction_session_timeout: 10min
        jit: off
        max_worker_processes: 16  # 2 * CPU
        max_parallel_workers: 8  # равен количеству CPU
        max_parallel_workers_per_gather: 4  # половина от количества CPU
        max_parallel_maintenance_workers: 4  # половина от количества CPU
        tcp_keepalives_count: 10
        tcp_keepalives_idle: 300
        tcp_keepalives_interval: 30

  initdb:  # List options to be passed on to initdb
    - encoding: UTF8
    - locale: ru_RU.UTF-8
    - data-checksums

#  post_init:
#    - psql -c "CREATE USER navigator WITH SUPERUSER PASSWORD 'password';"
#    - psql -c "GRANT ALL PRIVILEGES ON SCHEMA public TO navigator;"
#    - psql -c "CREATE DATABASE navigator_base;"
#    - psql -c "CREATE USER user2u WITH PASSWORD 'PiGiqaap00';"
#    - psql -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO user2u;"

  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
  # - host all all 192.168.113.200/32 md5
    - local   all             all                                     trust
    - local   replication     all                                     trust
    - host    replication     all             127.0.0.1/32            trust
    - host    replication     all             ::1/128                 trust
    - host replication replicator 127.0.0.1/32 scram-sha-256
    - local replication postgres    scram-sha-256
    - host all navigator 192.168.230.101/32 scram-sha-256
    - host all postgres 192.168.230.101/32 scram-sha-256
    - host all user2u 192.168.230.101/32 scram-sha-256
    - host all navigator 192.168.230.102/32 scram-sha-256
    - host all postgres 192.168.230.102/32 scram-sha-256
    - host all user2u 192.168.230.102/32 scram-sha-256
    - host all navigator 192.168.230.103/32 scram-sha-256
    - host all postgres 192.168.230.103/32 scram-sha-256
    - host all user2u 192.168.230.103/32 scram-sha-256
    - host replication replicator  localhost   scram-sha-256
    - host replication replicator 192.168.230.101/32 scram-sha-256
    - host replication replicator 192.168.230.102/32 scram-sha-256
    - host replication replicator 192.168.230.103/32 scram-sha-256

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.230.101:5432
  use_unix_socket: true
  data_dir: /mnt/database/pgdata/
  bin_dir: /usr/bin/
  config_dir: /mnt/database/pgdata/
  pgpass: /mnt/database/pgsql/.pgpass_patroni
  authentication:
    replication:
      username: replicator
      password: cluster2U
    superuser:
      username: postgres
      password: cluster2U
#    rewind:  # Has no effect on postgres 10 and lower
#      username: rewind_user
#      password: rewind_password
  parameters:
    unix_socket_directories: /tmp/


  remove_data_directory_on_rewind_failure: false
  remove_data_directory_on_diverged_timelines: false


  create_replica_methods:
    - basebackup
  basebackup:
    max-rate: '100M'
    checkpoint: 'fast'


watchdog:
  mode: automatic  # Allowed values: off, automatic, required
  device: /dev/watchdog  # Path to the watchdog device
  safety_margin: 5

tags:
  nosync: false
  noloadbalance: false
  nofailover: false
  clonefrom: false

  # specify a node to replicate from (cascading replication)
#  replicatefrom: (node name)

EOF

# После деалем директорию для записи WAL файлов 

# Чтобы настроить Patroni для записи WAL-файлов (журналов предзаписи) в отдельную директорию, нужно выполнить несколько шагов:

# Остановите Patroni: Прежде чем вносить изменения, остановите Patroni:
sudo systemctl stop patroni

# Создайте новую директорию для WAL-файлов: Создайте директорию, куда будут сохраняться WAL-файлы. Например:
mkdir -p /mnt/wal
# Делаем подпапку
mkdir -p /mnt/wal/wal
# Раздаем права на директорию
chown postgres:postgres -R /mnt/wal
chmod 700 -R /mnt/wal

# Переместите текущие WAL-файлы: Переместите существующие WAL-файлы в новую директорию. WAL-файлы обычно хранятся в поддиректории pg_wal в каталоге данных Patroni:
mv /mnt/database/pgdata/pg_wal/* /mnt/wal/wal

# Создайте символическую ссылку: Создайте символическую ссылку на новую директорию WAL:
ln -s /mnt/wal/wal /mnt/database/pgdata/pg_wal/

# сделать тоже самое для папки archive_directory
ln -s /mnt/wal/wal/archive_directory/ /mnt/database/pgdata/pg_wal/

# Запустите Patroni: После настройки снова запустите Patroni:
systemctl start patroni

# Теперь WAL-файлы будут записываться в новую директорию, а Patroni продолжит работать как обычно.

mkdir /var/log/pgsql
chmod 777 /var/log/pgsql
chown postgres:postgres /var/log/pgsql
systemctl start patroni
systemctl status patroni
patronictl -c /etc/patroni/patroni.yml list

#### Keepalived ####

apt-get install keepalived

    cat <<EOF > /etc/keepalived/keepalived.conf

! Configuration File for keepalived

global_defs {
   router_id ocp_vrrp
   enable_script_security
   script_user root
}

vrrp_script haproxy_check {
   script "/usr/libexec/keepalived/haproxy_check.sh"
   interval 2
   weight 2
}

vrrp_instance VI_1 {
   interface bond0
   virtual_router_id 50
   priority  100
   advert_int 2
   state  BACKUP
   virtual_ipaddress {
       10.51.1.100
   }
   track_script {
       haproxy_check
   }
   authentication {
      auth_type PASS
      auth_pass cluster2U
   }
}

EOF

systemctl enable keepalived
systemctl start keepalived
systemctl status keepalived
ip -br a

#### HaPROXY ####

apt-get install haproxy

  cat <<EOF > /etc/haproxy/haproxy.cfg
global
    maxconn 100000
    log /dev/log    local0
    log /dev/log    local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy-master.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user _haproxy
    group _haproxy
    daemon

defaults
    mode               tcp
    log                global
    retries            2
    timeout queue      5s
    timeout connect    5s
    timeout client     60m
    timeout server     60m
    timeout check      15s

listen stats
    mode http
    bind 10.51.1.101:7000
    stats enable
    stats uri /

listen master
    bind 10.51.1.100:5000
    maxconn 10000
    option tcplog
    option httpchk OPTIONS /primary
    http-check expect status 200
    default-server inter 3s fastinter 1s fall 3 rise 4 on-marked-down shutdown-sessions
 server PsqlPRO1 192.168.230.101:5432 check port 8008
 server PsqlPRO2 192.168.230.102:5432 check port 8008
 server PsqlPRO3 192.168.230.103:5432 check port 8008


listen replicas
    bind 10.51.1.100:5001
    maxconn 10000
    option tcplog
        option httpchk OPTIONS /replica?lag=100MB
        balance roundrobin
    http-check expect status 200
    default-server inter 3s fastinter 1s fall 3 rise 2 on-marked-down shutdown-sessions
 server PsqlPRO1 192.168.230.101:5432 check port 8008
 server PsqlPRO2 192.168.230.102:5432 check port 8008
 server PsqlPRO3 192.168.230.103:5432 check port 8008

listen replicas_sync
    bind 10.51.1.100:5002
    maxconn 10000
    option tcplog
        option httpchk OPTIONS /sync
        balance roundrobin
    http-check expect status 200
    default-server inter 3s fastinter 1s fall 3 rise 2 on-marked-down shutdown-sessions
 server PsqlPRO1 192.168.230.101:5432 check port 8008
 server PsqlPRO2 192.168.230.102:5432 check port 8008
 server PsqlPRO3 192.168.230.103:5432 check port 8008


listen replicas_async
    bind 10.51.1.100:5003
    maxconn 10000
    option tcplog
        option httpchk OPTIONS /async?lag=100MB
        balance roundrobin
    http-check expect status 200
    default-server inter 3s fastinter 1s fall 3 rise 2 on-marked-down shutdown-sessions
 server PsqlPRO1 192.168.230.101:5432 check port 8008
 server PsqlPRO2 192.168.230.102:5432 check port 8008
 server PsqlPRO3 192.168.230.103:5432 check port 8008

EOF

nano /etc/sysctl.conf
# добавить строчку 
net.ipv4.ip_nonlocal_bind=1
# После используем команду 
sysctl -p

systemctl enable haproxy.service
systemctl start haproxy.service
systemctl status haproxy.service

# проверяем работает ли HaPROXY на самом деле

psql -h 172.20.170.50 -p 5000 -U postgres -c "CREATE TABLE test_table1 (id INT, name TEXT);"