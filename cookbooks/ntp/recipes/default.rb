package "net-misc/openrdate"
package "net-misc/openntpd"

directory "/var/lib/openntpd/chroot" do
  owner "root"
  group "root"
  mode "0755"
  recursive true
end

user "ntp" do
  home "/var/lib/openntpd/chroot"
end

file "/etc/ntpd.conf" do
  content node[:ntp][:server].split(/,/).collect { |a| "server #{a}" }.join("\n") + "\n"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, "service[ntpd]"
end

cookbook_file "/etc/conf.d/ntpd" do
  source "ntpd.confd"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, "service[ntpd]"
end

directory "/var/lib/openntpd/chroot" do
  owner "root"
  group "root"
  mode "0755"
  recursive true
end

service "openrdate" do
  action [:enable, :start]
end

service "ntpd" do
  action [:enable, :start]
end

nrpe_command "check_time" do
  command "/usr/lib/nagios/plugins/check_ntp_time -H #{node[:ntp][:server].split(/,/).first}"
end

nagios_service "TIME" do
  check_command "check_nrpe!check_time"
  servicegroups "system"
end
