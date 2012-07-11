# Class: mysql::backup
#
# This module handles ...
#
# Parameters:
#   [*backupuser*]     - The name of the mysql backup user.
#   [*backuppassword*] - The password of the mysql backup user.
#   [*backupdir*]      - The target directory of the mysqldump.
#   [*provider*]       - The provider, current either default or percona.
#
# Actions:
#   GRANT SELECT, RELOAD, LOCK TABLES ON *.* TO 'user'@'localhost'
#    IDENTIFIED BY 'password';
#
# Requires:
#   Class['mysql::server']
#
# Sample Usage:
#   class { 'mysql::backup':
#     backupuser     => 'myuser',
#     backuppassword => 'mypassword',
#     backupdir      => '/tmp/backups',
#     provider       => 'percona',
#   }
#
class mysql::backup (
  $backupuser,
  $backuppassword,
  $backupdir,
  $ensure = 'present',
  $provider=nil,
) inherits mysql::params {

  database_user { "${backupuser}@localhost":
    ensure        => $ensure,
    password_hash => mysql_password($backuppassword),
    provider      => 'mysql',
    require       => Class['mysql::server'],
  }

  database_grant { "${backupuser}@localhost":
    privileges => [ 'Select_priv', 'Reload_priv', 'Lock_tables_priv' ],
    require    => Database_user["${backupuser}@localhost"],
  }

  case $provider {
    'percona': {
      package { $backup_package_name:
        ensure => latest,
      }
    }
    default: {
      cron { 'mysql-backup':
        ensure  => $ensure,
        command => '/usr/local/sbin/mysqlbackup.sh',
        user    => 'root',
        hour    => 23,
        minute  => 5,
        require => File['mysqlbackup.sh'],
      }

      file { 'mysqlbackup.sh':
        ensure  => $ensure,
        path    => '/usr/local/sbin/mysqlbackup.sh',
        mode    => '0700',
        owner   => 'root',
        group   => 'root',
        content => template('mysql/mysqlbackup.sh.erb'),
      }

      file { 'mysqlbackupdir':
        ensure => 'directory',
        path   => $backupdir,
        mode   => '0700',
        owner  => 'root',
        group  => 'root',
      }
    }
  }
}
