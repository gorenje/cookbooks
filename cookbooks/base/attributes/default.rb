# this nodes chef environment
default[:chef_environment] = "production"

# cluster support
default[:cluster][:name] = "default"

# this should be overriden globally or per-role
default[:contacts][:hostmaster] = "root@#{node[:fqdn]}"

# localization/i18n
default[:timezone] = "Europe/Berlin"
default[:locales] = [
  "en_US.UTF-8 UTF-8",
  "de_DE.UTF-8 UTF-8",
]

# nameservers and search domain
default[:resolv][:search] = [node[:domain]]
default[:resolv][:nameservers] = %w(8.8.8.8 8.8.4.4)
default[:resolv][:hosts] = []
default[:resolv][:aliases] = []

# sysctl attributes
default[:sysctl][:net][:ipv4][:ip_forward] = 0
default[:sysctl][:net][:netfilter][:nf_conntrack_max] = 262144
default[:sysctl][:kernel][:sysrq] = 1
default[:sysctl][:kernel][:panic] = 60
default[:sysctl][:vm][:overcommit_ratio] = 95
default[:sysctl][:vm][:overcommit_memory] = 2
default[:sysctl][:net][:core][:somaxconn] = 128 ## default

# shared memory sizes
default_unless[:sysctl][:kernel][:shmall] = 2*1024*1024 #pages
default_unless[:sysctl][:kernel][:shmmax] = 32*1024*1024 #bytes
default_unless[:sysctl][:kernel][:shmmni] = 4096

# skip hardware cookbooks
default[:skip][:hardware] = false

# base packages
node[:packages] = %w(
  app-admin/lib_users
  app-admin/pwgen
  app-admin/pydf
  app-admin/sysstat
  app-arch/atool
  app-arch/xz-utils
  app-misc/colordiff
  app-misc/mc
  app-shells/bash-completion
  dev-util/strace
  mail-client/mailx
  net-analyzer/bwm-ng
  net-analyzer/iptraf-ng
  net-analyzer/mtr
  net-analyzer/netcat
  net-analyzer/tcpdump
  net-analyzer/traceroute
  net-dns/bind-tools
  net-misc/keychain
  net-misc/telnet-bsd
  net-misc/whois
  sys-apps/ethtool
  sys-apps/hdparm
  sys-apps/iproute2
  sys-apps/pciutils
  sys-fs/ncdu
  sys-process/htop
  sys-process/iotop
  sys-process/lsof
)

# default system users/groups
default[:base][:groups] = {
  :root => {
    :gid => 0,
    :members => "root",
  },
  :bin => {
    :gid => 1,
    :members => "root,bin,daemon",
  },
  :daemon => {
    :gid => 2,
    :members => "root,bin,daemon",
  },
  :sys => {
    :gid => 3,
    :members => "root,bin,adm",
  },
  :adm => {
    :gid => 4,
    :members => "root,adm,daemon",
  },
  :tty => {
    :gid => 5,
    :members => "",
  },
  :disk => {
    :gid => 6,
    :members => "root,adm",
  },
  :lp => {
    :gid => 7,
    :members => "lp",
  },
  :mem => {
    :gid => 8,
    :members => "",
  },
  :kmem => {
    :gid => 9,
    :members => "",
  },
  :floppy => {
    :gid => 11,
    :members => "root",
  },
  :news => {
    :gid => 13,
    :members => "news",
  },
  :uucp => {
    :gid => 14,
    :members => "uucp",
  },
  :console => {
    :gid => 17,
    :members => "",
  },
  :audio => {
    :gid => 18,
    :members => "",
  },
  :cdrom => {
    :gid => 19,
    :members => "",
  },
  :tape => {
    :gid => 26,
    :members => "root",
  },
  :video => {
    :gid => 27,
    :members => "root",
  },
  :cdrw => {
    :gid => 80,
    :members => "",
  },
  :usb => {
    :gid => 85,
    :members => "",
  },
  :utmp => {
    :gid => 406,
    :members => "",
  },
  :nogroup => {
    :gid => 65533,
    :members => "",
  },
  :nobody => {
    :gid => 65534,
    :members => "",
  },
  :man => {
    :gid => 15,
    :members => "",
  },
}

default[:base][:users] = {
  :bin => {
    :uid => 1,
    :gid => 1,
    :home => "/bin",
    :shell => "/bin/false",
  },
  :daemon => {
    :uid => 2,
    :gid => 2,
    :home => "/sbin",
    :shell => "/bin/false",
  },
  :adm => {
    :uid => 3,
    :gid => 4,
    :home => "/var/adm",
    :shell => "/bin/false",
  },
  :lp => {
    :uid => 4,
    :gid => 7,
    :home => "/var/spool/lpd",
    :shell => "/bin/false",
  },
  :sync => {
    :uid => 5,
    :gid => 0,
    :home => "/sbin",
    :shell => "/bin/sync",
  },
  :shutdown => {
    :uid => 6,
    :gid => 0,
    :home => "/sbin",
    :shell => "/sbin/shutdown",
  },
  :halt => {
    :uid => 7,
    :gid => 0,
    :home => "/sbin",
    :shell => "/sbin/halt",
  },
  :news => {
    :uid => 9,
    :gid => 13,
    :home => "/var/spool/news",
    :shell => "/bin/false",
  },
  :uucp => {
    :uid => 10,
    :gid => 14,
    :home => "/var/spool/uucp",
    :shell => "/bin/false",
  },
  :operator => {
    :uid => 11,
    :gid => 0,
    :home => "/root",
    :shell => "/bin/bash",
  },
  :nobody => {
    :uid => 65534,
    :gid => 65534,
    :home => "/var/empty",
    :shell => "/bin/false",
  },
  :man => {
    :uid => 13,
    :gid => 15,
    :home => "/usr/share/man",
    :shell => "/sbin/nologin",
    :comment => "added by portage for man",
  },
}

# block upgrades with p.mask entries
default[:gentoo][:upgrade_blockers] = []

# rc_sys
if node[:virtualization][:role] == "guest"
  default[:openrc][:sys] = case node[:virtualization][:system]
                             when "linux-vserver"
                               "vserver"
                             else
                               raise "Unsupported virtualization system: #{node[:virtualization][:system]}"
                             end
else
  default[:openrc][:sys] = ""
end
