define :spawn_fcgi do
  p = {
    :children => 1,
    :chdir => '',
  }.merge(params.symbolize_keys)

  p[:socket] = {
    :path => "/var/run/spawn-fcgi/#{params[:name]}.sock",
    :address => "127.0.0.1",
    :user => "nobody",
    :group => "nobody",
    :mode => "0660",
  }.merge(p[:socket].symbolize_keys)

  include_recipe "spawn-fcgi"

  name = p[:name]

  link "/etc/init.d/spawn-fcgi.#{name}" do
    to "/etc/init.d/spawn-fcgi"
  end

  template "/etc/conf.d/spawn-fcgi.#{name}" do
    source "spawn-fcgi.confd"
    cookbook "spawn-fcgi"
    owner "root"
    group "root"
    mode "0644"
    variables p
    notifies :restart, "service[spawn-fcgi.#{name}]"
  end

  service "spawn-fcgi.#{name}" do
    action [:enable, :start]
  end

  nrpe_command "check_spawn-fcgi_#{name}" do
    command "/usr/lib/nagios/plugins/check_pidfile /var/run/spawn-fcgi/#{name}"
  end

  nagios_service "FCGI-#{name.upcase}" do
    check_command "check_nrpe!check_spawn-fcgi_#{name}"
  end
end
