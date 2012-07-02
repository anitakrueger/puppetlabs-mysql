# Class: mysql::server
#
# manages the installation of the mysql server.  manages the package, service,
# my.cnf
#
# Parameters:
#   [*package_name*]        - name of package
#   [*package_ensure*]      - ensure for the package, i.e. present or latest
#   [*service_name*]        - name of service
#   [*service_provider*]    - prodiver for the service
#   [*enabled*]             - ensure the service is running or not
#   [*root_password*]       - root user password.
#   [*old_root_password*]   - previous root user password,
#   [*bind_address*]        - address to bind service.
#   [*port*]                - port to bind service.
#   [*etc_root_password*]   - whether to save /etc/.my.cnf.
#   [*service_name*]        - mysql service name.
#   [*config_file*]         - my.cnf configuration file path.
#   [*socket*]              - mysql socket.
#   [*datadir*]             - path to datadir.
#   [*ssl]                  - enable ssl
#   [*ssl_ca]               - path to ssl-ca
#   [*ssl_cert]             - path to ssl-cert
#   [*ssl_key]              - path to ssl-key
#   [*mysqld_extra_params*] - array of extra params for my.cnf
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class mysql::server (
  $package_name        = $mysql::params::server_package_name,
  $package_ensure      = 'present',
  $service_name        = $mysql::params::service_name,
  $service_provider    = $mysql::params::service_provider,
  $enabled             = true,
  $root_password       = 'UNSET',
  $old_root_password   = '',
  $bind_address        = $mysql::params::bind_address,
  $port                = $mysql::params::port,
  $etc_root_password   = $mysql::params::etc_root_password,
  $service_name        = $mysql::params::service_name,
  $config_file         = $mysql::params::config_file,
  $socket              = $mysql::params::socket,
  $datadir             = $mysql::params::datadir,
  $ssl                 = $mysql::params::ssl,
  $ssl_ca              = $mysql::params::ssl_ca,
  $ssl_cert            = $mysql::params::ssl_cert,
  $ssl_key             = $mysql::params::ssl_key,
  $log_error           = $mysql::params::log_error,
  $default_engine      = 'UNSET',
  $root_group          = $mysql::params::root_group,
  $mysqld_extra_params = 'nil',
) inherits mysql::params {

  package { 'mysql-server':
    name   => $package_name,
    ensure => $package_ensure,
  }

  if $ssl and $ssl_ca == undef {
    fail('The ssl_ca parameter is required when ssl is true')
  }

  if $ssl and $ssl_cert == undef {
    fail('The ssl_cert parameter is required when ssl is true')
  }

  if $ssl and $ssl_key == undef {
    fail('The ssl_key parameter is required when ssl is true')
  }

  if $enabled {
    $service_ensure = 'running'
  } else {
    $service_ensure = 'stopped'
  }

  # manage root password if it is set
  if $root_password != 'UNSET' {
    case $old_root_password {
      '':      { $old_pw='' }
      default: { $old_pw="-p${old_root_password}" }
    }

    exec { 'set_mysql_rootpw':
      command   => "mysqladmin -u root ${old_pw} password ${root_password}",
      logoutput => true,
      unless    => "mysqladmin -u root -p${root_password} status > /dev/null",
      path      => '/usr/local/sbin:/usr/bin:/usr/local/bin',
      require   => [
        File [$config_file],
        Service [$service_name], ],
    }

    file { '/root/.my.cnf':
      content => template('mysql/my.cnf.pass.erb'),
      require => Exec['set_mysql_rootpw'],
    }

    if $etc_root_password {
      file{ '/etc/my.cnf':
        content => template('mysql/my.cnf.pass.erb'),
        require => Exec['set_mysql_rootpw'],
      }
    }
  }

  file { [
    '/etc/mysql',
    '/etc/mysql/conf.d', ]:
    ensure  => directory,
    mode    => '0755',
  }

  file { $config_file:
    content => template('mysql/my.cnf.erb'),
    mode    => '0644',
    require => File ['/etc/mysql/conf.d'],
    notify  => Service [$service_name],
  }

  service { $service_name:
    name     => $service_name,
    ensure   => $service_ensure,
    enable   => $enabled,
    require  => File [$config_file],
    provider => $service_provider,
  }

}
