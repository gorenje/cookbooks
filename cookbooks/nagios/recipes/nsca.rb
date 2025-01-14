package "net-analyzer/nagios-nsca"

directory "/etc/nagios" do
  owner "nagios"
  group "nagios"
  mode "0750"
end

master = node.run_state[:nodes].select do |n|
  n[:tags].include?("nagios-master")
end.first

template "/etc/nagios/send_nsca.cfg" do
  source "send_nsca.cfg.erb"
  owner "nagios"
  group "nagios"
  mode "0640"
  variables :master => master
end
