default[:nagios][:from_address] = "nagios@#{node[:fqdn]}"
default[:nagios][:nrpe][:listen_addr] = node[:ipaddress]
default[:nagios][:nsca][:password] = "n6JlHK3zql33QpQiiNWk1rC5XQsDk8KB"

default[:nagios][:host][:contact_groups] = %w(everyone)
default[:nagios][:service][:contact_groups] = %w(everyone)
