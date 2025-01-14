tag("mysql-server")

include_recipe "mysql::default"

package "dev-db/innotop"
package "dev-db/maatkit"
package "dev-db/mysqltuner"
package "dev-db/mytop"
package "dev-db/xtrabackup-bin"
package "dev-ruby/mysql-ruby"

# configuration files
directory "/etc/mysql/conf.d" do
  owner "root"
  group "root"
  mode "0755"
end

template "/etc/mysql/my.cnf" do
  source "my.cnf"
  owner "root"
  group "root"
  mode "0644"
end

template "/etc/conf.d/mysql" do
  source "mysql.confd"
  owner "root"
  group "root"
  mode "0644"
end

# create initial database and users
mysql_root_pass = get_password("mysql/root")

template "/usr/sbin/mysql_pkg_config" do
  source "mysql_pkg_config"
  owner "root"
  group "root"
  mode "0755"
  not_if { File.directory?("/var/lib/mysql/mysql") }
  backup 0
  variables(:root_pass => mysql_root_pass)
end

execute "mysql_pkg_config" do
  creates "/var/lib/mysql/mysql"
end

file "/usr/sbin/mysql_pkg_config" do
  action :delete
  backup 0
end

file "/root/.my.cnf" do
  content "[client]\nuser = root\npass = #{mysql_root_pass}\n"
  owner "root"
  group "root"
  mode "0600"
  backup 0
end

# syslog and logrotate configuration
syslog_config "90-mysql" do
  template "syslog.conf"
end

template "/etc/logrotate.d/mysql" do
  source "logrotate.conf"
  owner "root"
  group "root"
  mode "0644"
end

%w(mysql.err mysql.log mysqld.err slow-queries.log).each do |l|
  file "/var/log/mysql/#{l}" do
    owner "mysql"
    group "wheel"
    mode "0640"
  end
end

# init script
service "mysql" do
  action [:enable, :start]
end

# nagios service checks
if tagged?("nagios-client")

  # simple helper class for custom nagios checks
  directory "/usr/lib/ruby/site_ruby/nagios/plugin" do
    owner "root"
    group "root"
    mode "0755"
    recursive true
  end

  cookbook_file "/usr/lib/ruby/site_ruby/nagios/plugin/mysql.rb" do
    source "nagios-mysql.rb"
    owner "root"
    group "root"
    mode "0644"
  end

  # simple process check
  nrpe_command "check_mysql" do
    command "/usr/lib/nagios/plugins/check_pidfile /var/run/mysqld/mysqld.pid /usr/sbin/mysqld"
  end

  nagios_service "MYSQL" do
    check_command "check_nrpe!check_mysql"
    notification_interval 15
    servicegroups "mysql"
  end

  nagios_service_escalation "MYSQL"

  # MySQL user for check_mysql_health and others
  mysql_nagios_password = get_password("mysql/nagios")

  file "/var/nagios/home/.my.cnf" do
    content "[client]\nuser = nagios\npass = #{mysql_nagios_password}\n"
    owner "nagios"
    group "nagios"
    mode "0600"
    backup 0
  end

  mysql_user "nagios" do
    force_password true
    password mysql_nagios_password
  end

  mysql_grant "nagios" do
    user "nagios"
    privileges ["PROCESS", "REPLICATION CLIENT"]
    database "*"
  end

  # do not use upstream version with wrapper hack
  package "net-analyzer/nagios-check_mysql_health" do
    action :remove
  end

  nagios_plugin "check_mysql_health_wrapper" do
    action :delete
  end

  # instead use patched version with my.cnf support
  nagios_plugin "check_mysql_health"

  node[:mysql][:server][:nagios].each do |name, params|
    command_name = "check_mysql_#{name}"
    service_name = "MYSQL-#{name.upcase}"

    nrpe_command command_name do
      command "/usr/lib/nagios/plugins/check_mysql_health --mode #{params[:command]} --warning #{params[:warning]} --critical #{params[:critical]}"
    end

    nagios_service service_name do
      check_command "check_nrpe!check_mysql_#{name}"
      check_interval params[:check_interval]
      notification_interval params[:notification_interval]
      servicegroups "mysql"
      enabled params[:enabled]
    end

    nagios_service_dependency service_name do
      depends %w(MYSQL)
    end
  end

  nagios_service_dependency "MYSQL-SLAVELAG" do
    depends %w(MYSQL-SLAVEIO MYSQL-SLAVESQL)
  end

  nagios_service_escalation "MYSQL-SLAVEIO"
  nagios_service_escalation "MYSQL-SLAVESQL"
end

# munin plugins
if tagged?("munin-node")
  mysql_munin_password = get_password("mysql/munin")

  mysql_user "munin" do
    force_password true
    password mysql_munin_password
  end

  mysql_grant "munin-global" do
    user "munin"
    privileges ["SUPER", "PROCESS", "REPLICATION CLIENT"]
    database "*"
  end

  mysql_grant "munin-mysql" do
    user "munin"
    privileges ["SELECT"]
    database "mysql"
  end

  # remove old plugins
  %w(bytes queries slave_status slowqueries threads).each do |p|
    munin_plugin "mysql_#{p}" do
      action :delete
    end
  end

  # use advanced mysql graphs
  package "net-analyzer/munin-mysql"

  munin_plugin "mysql" do
    config [
      "env.mysqlconnection DBI:mysql:mysql",
      "env.mysqluser munin",
      "env.mysqlpassword #{mysql_munin_password}",
    ]
  end
end
