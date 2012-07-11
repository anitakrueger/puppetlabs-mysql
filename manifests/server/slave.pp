# = Class: mysql::server::slave
# This class will configure a server as slave in a master to
# master scenario.
#
# == Parameters
# * $masterhost: The master for this mysql server.
# * $dbs:        Which DBs to import.
# * $repl_user:  The user used for replication.
# * $repl_pw:    The password for the replication user.
#
# == Actions
# 
#
# == Requires
# n/a
#
# == Sample Usage
#   class { 'mysql::server::slave':
#     masterhost => 'mysqlmaster',
#     dbs        => 'db1 db2',
#     repl_user  => 'repl',
#     repl_pw    => 'password',
#   }
#
# == Author
# Anita Krueger <anita.krueger@wirecard.com>
class mysql::server::slave (
  $masterhost,
  $dbs,
  $repl_user,
  $repl_pw, ) {

  $root_pw    = $mysql::server::root_password
  $masterdump = '/tmp/mysql_master_dump'

  Database_user[[ "$repl_user@$::fqdn", "$repl_user@$masterhost", ]]          ->
  Database_grant[[ "$repl_user@$::fqdn", "$repl_user@$masterhost", ]]         ->
  Exec['stop-slave']                          -> Exec['lock-master-tables']   ->
  Exec['dump-master-schema']                  -> Exec['unlock-master-tables'] ->
  Exec['import-master-schema']                -> Exec['unlock-slave-tables']  ->
  File['/usr/share/mysql/set_m2m_repl_data.sh'] -> Exec['set-master-to-master'] ->
  Exec['start-slave']                         -> File[$masterdump]

  Exec['stop-slave']           ~> Exec['lock-master-tables']   ~>
  Exec['dump-master-schema']   ~> Exec['unlock-master-tables'] ~>
  Exec['import-master-schema'] ~> Exec['unlock-slave-tables']  ~>
  Exec['set-master-to-master'] ~> Exec['start-slave']

  Exec {
    path => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
  }

  database_user { [
    "$repl_user@$::fqdn",
    "$repl_user@$masterhost", ]:
    password_hash => mysql_password($repl_pw),
  }

  database_grant { [
    "$repl_user@$::fqdn",
    "$repl_user@$masterhost", ]:
    privileges => ['Repl_slave_priv'],
  }

  exec { 'stop-slave':
    command => 'mysql -e "stop slave;"',
    unless  => 'mysql -e "show slave status" | grep Waiting',
  }

  exec { 'lock-master-tables':
    command     => "mysql --host=$masterhost -uroot -p$root_pw -e \"FLUSH TABLES WITH READ LOCK\"",
    refreshonly => true,
  }

  exec { 'dump-master-schema':
    command     => "mysqldump --host=$masterhost -uroot -p$root_pw --opt --quote-names --routines --databases $dbs > $masterdump",
    refreshonly => true,
  }

  exec { 'unlock-master-tables':
    command     => "mysql --host=$masterhost -uroot -p$root_pw -e \"UNLOCK TABLES\"",
    refreshonly => true,
  }

  exec { 'import-master-schema':
    command     => "mysql < $masterdump",
    refreshonly => true,
  }

  exec { 'unlock-slave-tables':
    command     => 'mysql -e "UNLOCK TABLES"',
    refreshonly => true,
  }

  file { '/usr/share/mysql/set_m2m_repl_data.sh':
    ensure  => present,
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0755',
    content => template("$module_name/set_m2m_repl_data.sh.erb"),
  }

  exec { 'set-master-to-master':
    command     => '/usr/share/mysql/set_m2m_repl_data.sh',
    creates     => '/usr/share/mysql/set_master_repl_data.sql',
    refreshonly => true,
  }

  exec { 'start-slave':
    command     => 'mysql -e "start slave;"',
    refreshonly => true,
  }

  file { $masterdump:
    ensure  => absent,
  }
}
