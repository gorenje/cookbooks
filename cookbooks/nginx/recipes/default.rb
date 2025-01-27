include_recipe "syslog"

nginx_default_use_flags = %w(
  -nginx_modules_http_browser
  -nginx_modules_http_empty_gif
  -nginx_modules_http_geo
  -nginx_modules_http_memcached
  -nginx_modules_http_ssi
  -nginx_modules_http_userid
  aio
  nginx_modules_http_empty_gif
  nginx_modules_http_realip
  nginx_modules_http_stub_status
)

portage_package_use "www-servers/nginx" do
  use(nginx_default_use_flags + node[:nginx][:use_flags])
end

group "nginx" do
  gid 82
  append true
end

user "nginx" do
  uid 82
  gid 82
  home "/dev/null"
  shell "/sbin/nologin"
  comment "added by portage for nginx"
end

package "www-servers/nginx"

service "nginx" do
  action [:enable, :start]
  supports [:reload]
end

%w(
  /etc/nginx
  /etc/nginx/modules
  /etc/nginx/servers
  /etc/ssl/nginx
).each do |d|
  directory d do
    owner "root"
    group "root"
    mode "0755"
  end
end

directory "/var/cache/nginx" do
  owner "nginx"
  group "nginx"
  mode "0755"
end

ssl_certificate "/etc/ssl/nginx/nginx" do
  cn node[:fqdn]
  owner "nginx"
  group "nginx"
  notifies :reload, "service[nginx]"
end

%w(csr pem).each do |f|
  file "/etc/ssl/nginx/nginx.#{f}" do
    action :delete
  end
end

template "/etc/nginx/nginx.conf" do
  source "nginx.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, "service[nginx]"
end

nginx_module "fastcgi" do
  template "fastcgi.conf.erb"
end

link "/etc/nginx/fastcgi.conf" do
  to "/etc/nginx/modules/fastcgi.conf"
end

file "/etc/nginx/fastcgi_params" do
  action :delete
end

nginx_server "status" do
  template "status.conf"
end

syslog_config "90-nginx" do
  template "syslog.conf"
end

cookbook_file "/etc/logrotate.d/nginx" do
  source "logrotate.conf"
  owner "root"
  group "root"
  mode "0644"
end

%w(memory request status).each do |p|
  munin_plugin "nginx_#{p}" do
    source "nginx_#{p}"
  end
end
