### Сборка СУБД Postgres Pro Enterprise Manager на ALT Linux server 10 
# Добавляем новый репозиторий 
wget https://repo.postgrespro.ru/ppem/ppem/keys/pgpro-repo-add.sh

chmod +x pgpro-repo-add.sh

sh pgpro-repo-add.sh

# После создания файла заходим в него и меняем ссылки 
nano /etc/apt/sources.list.d/postgrespro-std-15.list
# Repositiory for 'PostgresPro Standard 15'
rpm http://repo.postgrespro.ru/std/std-15/altlinux/10 x86_64 pgpro
rpm http://repo.postgrespro.ru/ppem/ppem/altlinux/10/ noarch pgpro

apt-get update
##### Ставим постгрес про 
wget --user (Ключ лиензии) --password='' https://repo.postgrespro.ru/ent/ent-16/keys/pgpro-repo-add.sh
sh pgpro-repo-add.sh
apt-get install postgrespro-ent-16

###############################################################################################
### Если Альт будет ругаться на репозиторий то вместо https поставить http и обновить пакеты ##
###############################################################################################

### Настройка аутентификации 

Заходим в data dir базы и меняем настройки файла pg_hba.conf

# "local" is for Unix domain socket connections only
local   all             all                                                  trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust

##### Скачиваем pgpro-manager 

apt-get install pgpro-manager

nano /etc/pgpro-manager.conf

[repository]

host =  /tmp
port =  5432
dbname = pgpro_manager_repo
dbuser = pgpro_manager
max_connections = 2
# password = secret
# define an absolute or relative path. Relative will be added to {pgdata}, e.g. for default value: /var/lib/pgpro/ent-14/cfs_compressed
cfs_tablespace = cfs_compressed
# app_name = ppem-repo
monitoring_rotation_enabled = True
monitoring_rotation_period = 8
notifications_rotation_enabled = True
notifications_rotation_period = 2
logs_rotation_enabled = True
logs_rotation_period = 32
[system]
pid=/run/pgpro-manager/manager.pid
[plugins]
enabled = instance_objects,  core, simple_auth, menu, instance_manage, instance_monitoring, manager_admin, pg_probackup, pgpro_scheduler, plugins, instances_log, pg_stat_statements, pg_query_state, conf_preset, pgpro_pwr
search_path = ee_manager/plugins
repo = /usr/share/pgpro-manager/plugins/store
install_path = /usr/share/pgpro-manager/plugins/installed
install_js_path = /usr/share/pgpro-manager/static/plugins/installed

[web]
; listen host
host = 0.0.0.0
; listen port
port = 8877
server_auth = dfdf0e435423HIGLDksdsad
; enable web gui application
web_app = on
; path to web gui application files
web_app_path = /usr/share/pgpro-manager/web-app
# Access-Control-Allow-Origin Response Header value
# omit it or set to 'none' to remove it
access_control_allow_origin = *
;  enable swagger json page
swagger = off
;  enable pages with swagger UI
swagger-ui = off
;ssl_cert = /etc/ssl/certs/pgpro-manager-web.pem
;ssl_key  = /etc/ssl/private/pgpro-manager-web.pem

[agent]

ca_cert = /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem

# specify logging settings
# rotating - True/False
# rotating_size -size to rotate log file in B( by default), MB, GB, TB
# https://docs.python.org/3/library/logging.handlers.html#logging.handlers.RotatingFileHandler
# format - https://docs.python.org/3/library/logging.html#logrecord-attributes, use %% instead of %
[log]
file = /var/log/pgpro-manager/pgpro-manager.log
level = DEBUG
format = %%(asctime)s:[%%(levelname)s]: %%(message)s
rotating = True
rotating_size = 1GB
rotating_count = 10

[cron]
storage_dir = /var/spool/ppem-cron
conf_file_dir = /etc/cron.d
conf_file_name = ppem-tasks.crontab

[services]
log_collector = on
instances_info = on
monitoring = on
rotation = on
cron_log_collector = on

[retention]
# keep at least this number of last completed user's tasks
user_tasks_redundancy = 15
# drop user's tasks older than this number of days
user_tasks_window = 15

# Uncomment the following section if you are going to use ldap_auth plugin
# instead of simple_auth plugin
# [ldap]
#
# host = ldap.example.com
# port = 389
# use_ssl = false
# bind_username = cn=admin,dc=ppem,dc=l,dc=company,dc=ru
# bind_password = ppem
# base_dn = dc=ppem,dc=l,dc=company,dc=ru
# prefix_user_dn = ou=users
# prefix_group_dn = ou=groups
# user_class = inetOrgPerson
# user_name_attr = cn
# user_first_name_attr = givenName
# user_last_name_attr = sn
# user_display_name_attr = displayName
# user_email_attr = mail
# user_id_attr = uid
# group_class = groupOfUniqueNames
# group_name_attr = cn
# group_members_attr = uniqueMember
# # user_membership_attr = memberOf
# user_check_period = 300
# user_phone_attr  = telephoneNumber
# user_job_title_attr = jobTitle

### Инициализируем репозиторий 

init-pgpro-manager-repo --conf /etc/pgpro-manager.conf

systemctl start pgpro-manager
systemctl status pgpro-manager

##### После заходим по IP в WEB интерфейс с портом 8877 логин пароль admin/admin


#########################____Регистрация Агентов____#####################################
# Добавляем новый репозиторий 
wget https://repo.postgrespro.ru/ppem/ppem/keys/pgpro-repo-add.sh

chmod +x pgpro-repo-add.sh

sh pgpro-repo-add.sh

# После создания файла заходим в него и меняем ссылки 
nano /etc/apt/sources.list.d/postgrespro-std-15.list
# Repositiory for 'PostgresPro Standard 15'
rpm http://repo.postgrespro.ru/std/std-15/altlinux/10 x86_64 pgpro
rpm http://repo.postgrespro.ru/ppem/ppem/altlinux/10/ noarch pgpro

apt-get update
apt-get install pgpro-manager-agent
#######

### Создание агентов в ВЕБ интерфейсе 
"Настройки" – "Настройки агентов" - "Добавить агент"
Название - название сервера СУБД где будет установлен и запущен агент PPEM.
Хост - IP адрес или имя хоста.
Порт - порт агента PPEM, по-умолчанию 8899.
Протокол - http
Период опроса доступности, сек. - 10
Статус - Ок

Выбираем "Сохранить".

От туда нам нужен ключ аутентификации в поле auth 
nano /etc/pgpro-manager-agent.conf

[system]
; Should be same as in ee-manager.service
pid = /run/pgpro-manager/agent.pid

[networking]
; Listen on all addresses by default
host = 0.0.0.0
; Port to listen
port = 8899
; Where to get connection auth key (can be config or file)
manager_auth_type = config
; Key if kept here
manager_key = bRHGNUzXfD1ZFba0ntilchxXwqr9xLbe ### ПОДСТАВИТЬ СВОЙ КЛЮЧ КОТОРЫЙ СГЕНЕРИЛ НОВЫЙ АГЕНТ!!!!! 
; File to store key if stored separately
manager_file=/var/lib/pgpro-manager/agent/manager
; DNS name or IP address of manager UI host
manager_host = 10.22.4.106 ####### Указать IP адрес машины на которой стоит СУБД 

[plugins]
enabled = instance_objects,  core, simple_auth, menu, instance_manage, instance_monitoring, manager_admin, pg_probackup, pgpro_scheduler, plugins, instances_log, pg_stat_statements, pg_query_state, conf_preset, pgpro_pwr

; inside /usr/lib/python3/dist-packages
search_path = ee_manager/plugins

[log]
file = /var/log/pgpro-manager-agent.log
; Possible log level values: CRITICAL, ERROR, WARNING, INFO, DEBUG.
level = ERROR
format = %%(asctime)s:[%%(levelname)s]: %%(message)s
rotating = True
rotating_size = 1GB
rotating_count = 10

[monitoring]
status = on
polling_interval = 15
rotation_period = 7
