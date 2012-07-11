# = Class: mysql::server::master
# This class will configure a server as master in a master to
# master scenario.
#
# == Parameters
# * $slavehost:  The slave for this mysql server.
# * $repl_user:  The user used for replication.
# * $repl_pw:    The password for the replication user.
#
# == Actions
# Sets master to master replication if the slave host already
# has a slave up and running pointing to this master.
#
# == Requires
# Class['mysql::server']
#
# == Sample Usage
#   class { 'mysql::server::master':
#     masterhost => 'mysqlmaster',
#     repl_user  => 'repl',
#     repl_pw    => 'password',
#   }
#
# == Author
# Anita Krueger <anita.krueger@wirecard.com>
class mysql::server::master (
  $slavehost,
  $repl_user,
  $repl_pw, ) {

  $masterhost = $slavehost

  Database_user[[ "$repl_user@$::fqdn", "$repl_user@$masterhost", ]]  ->
  Database_grant[[ "$repl_user@$::fqdn", "$repl_user@$masterhost", ]] ->
  Exec['stop-slave'] -> File['/usr/share/mysql/set_m2m_repl_data.sh']   ->
  Exec['set-master-to-master'] -> Exec['start-slave']

  Exec['stop-slave'] ~> Exec['set-master-to-master'] ~> Exec['start-slave']

  Exec {
    path => ['/sbin', '/usr/sbin', '/bin', '/usr/bin'],
  }

  database_user { [
    "$repl_user@$::fqdn",
    "$repl_user@$slavehost", ]:
    password_hash => mysql_password($repl_pw),
    require       => Class ['mysql::server'],
  }

  database_grant { [
    "$repl_user@$::fqdn",
    "$repl_user@$slavehost", ]:
    privileges => ['Repl_slave_priv'],
    require    => Database_user [[ "$repl_user@$::fqdn", "$repl_user@$slavehost", ]],
  }

  exec { 'stop-slave':
    command => 'mysql -e "stop slave;"',
    unless  => 'mysql -e "show slave status" | grep Waiting',
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

}
