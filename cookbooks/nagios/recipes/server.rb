tag("nagios-master")

include_recipe "apache::php"

portage_package_use "net-analyzer/nagios-core" do
  use %w(apache2)
end

portage_package_use "net-analyzer/nagios-plugins" do
  use %w(ldap mysql nagios-dns nagios-ntp nagios-ping nagios-ssh postgres)
end

include_recipe "nagios::nrpe"
include_recipe "nagios::nsca"

package "net-analyzer/nagios"
package "net-analyzer/mk-livestatus"

directory "/etc/nagios" do
  owner "nagios"
  group "nagios"
  mode "0750"
end

directory "/var/nagios/rw" do
  owner "nagios"
  group "apache"
  mode "6755"
end

file "/var/nagios/rw/nagios.cmd" do
  owner "nagios"
  group "apache"
  mode "0660"
end

directory "/var/run/nsca" do
  owner "nagios"
  group "nagios"
  mode "0755"
end

template "/usr/lib/nagios/plugins/notify" do
  source "notify"
  owner "root"
  group "nagios"
  mode "0750"
end

# nagios master/slave setup
slave = node.run_state[:nodes].select do |n|
  n[:tags].include?("nagios-master") and
  n[:fqdn] != node[:fqdn]
end

if slave.length > 1
  raise "only 1 nagios slave is supported. found: #{slave.map { |n| n[:fqdn] }.inspect}"
else
  slave = slave.first
end

if slave
  include_recipe "beanstalkd"

  nagios_plugin "queue_check_result"
  nagios_plugin "process_check_results"

  cookbook_file "/etc/init.d/nsca-processor" do
    source "nsca-processor.initd"
    owner "root"
    group "root"
    mode "0755"
  end

  template "/etc/conf.d/nsca-processor" do
    source "nsca-processor.confd"
    owner "root"
    group "root"
    mode "0644"
    variables :slave => slave
  end

  service "nsca-processor" do
    action [:enable, :start]
  end

  nrpe_command "check_beanstalkd_nsca" do
    command "/usr/lib/nagios/plugins/check_beanstalkd -S localhost:11300 " +
            "-w #{node[:beanstalkd][:nagios][:warning]} " +
            "-c #{node[:beanstalkd][:nagios][:critical]} " +
            "-t send_nsca"
  end

  nagios_service "BEANSTALKD-NSCA" do
    check_command "check_nrpe!check_beanstalkd_nsca"
  end

  nagios_plugin "enable_master"
  nagios_plugin "disable_master"

  template "/usr/lib/nagios/plugins/check_nagios_slave" do
    source "check_nagios_slave"
    owner "root"
    group "nagios"
    mode "0750"
    variables :slave => slave
  end

  cron "check_nagios_slave" do
    command "/usr/bin/flock /var/lock/check_nagios_slave.lock -c /usr/lib/nagios/plugins/check_nagios_slave"
  end
end

# retrieve data from the search index
contacts = node.run_state[:users].select do |u|
  u.include?(:nagios_contact_groups)
end.sort_by do |u|
  u[:id]
end

hostmasters = contacts.select do |c|
  c[:tags] and c[:tags].include?("hostmaster")
end.map do |c|
  c[:id]
end

hosts = node.run_state[:nodes].select do |n|
  n[:tags].include?("nagios-client")
end.sort_by do |n|
  n[:fqdn]
end

roles = node.run_state[:roles].reject do |r|
  r.name == "base"
end.sort_by do |r|
  r.name
end

# build hostgroups
hostgroups = {}

hosts.each do |h|
  # group per cluster
  cluster = h[:cluster][:name] or "default"

  hostgroups[cluster] ||= []
  hostgroups[cluster] << h[:fqdn]

  # group per role (except base)
  h[:roles] ||= []
  h[:roles].each do |r|
    next if r == "base"
    hostgroups[r] ||= []
    hostgroups[r] << h[:fqdn]
  end
end

# build service groups
servicegroups = []
hosts.each do |h|
  h[:nagios][:services].each do |name, params|
    if params[:servicegroups]
      servicegroups |= params[:servicegroups].split(",")
    end
  end
end

# remove sample objects
%w(hosts localhost printer services switch windows).each do |f|
  nagios_conf f do
    action :delete
  end
end

# nagios base config
%w(nagios nsca resource).each do |f|
  nagios_conf f do
    subdir false
    variables :slave => slave
  end
end

nagios_conf "cgi" do
  subdir false
  variables :hostmasters => hostmasters
end

# create nagios objects
nagios_conf "commands"

nagios_conf "templates" do
  variables :hostmasters => hostmasters
end

nagios_conf "contacts" do
  variables :contacts => contacts
end

nagios_conf "timeperiods" do
  variables :contacts => contacts
end

nagios_conf "hostgroups" do
  variables :hostgroups => hostgroups
end

nagios_conf "servicegroups" do
  variables :servicegroups => servicegroups
end

hosts.each do |host|
  nagios_conf "host-#{host[:fqdn]}" do
    template "host.cfg.erb"
    variables :host => host
  end
end

include_recipe "nagios::extras"

service "nagios" do
  action [:enable, :start]
end

service "nsca" do
  action [:enable, :start]
end

# apache specifics
group "nagios" do
  members %w(apache)
  append true
end

file "/etc/nagios/users" do
  content contacts.map { |c| "#{c[:id]}:#{c[:password]}" }.join("\n")
  owner "root"
  group "apache"
  mode "0640"
end

node[:apache][:default_redirect] = "https://#{node[:fqdn]}"

apache_vhost "nagios" do
  template "apache.conf"
end

file "/var/www/localhost/htdocs/index.php" do
  content '<?php header("Location: /nagios/"); ?>\n'
  owner "root"
  group "root"
  mode "0644"
end

file "/var/www/localhost/htdocs/index.html" do
  action :delete
end

template "/usr/share/nagios/htdocs/index.php" do
  source "index.php"
  owner "nagios"
  group "nagios"
  mode "0644"
end

# jNag server (for mobile interface)
cookbook_file "/usr/share/nagios/htdocs/jNag.php" do
  source "jnag/jNag.php"
  owner "nagios"
  group "nagios"
  mode "0644"
end

remote_directory "/usr/share/nagios/htdocs/jNag/images" do
  source "jnag/images"
  owner "nagios"
  group "nagios"
  mode "0755"
end

nagios_conf "jnag" do
  subdir false
end

# nagios health check
nrpe_command "check_nagios" do
  command "/usr/lib/nagios/plugins/check_nagios -F /var/nagios/status.dat -C /usr/sbin/nagios -e 5"
end

nagios_service "NAGIOS" do
  check_command "check_nrpe!check_nagios"
end
