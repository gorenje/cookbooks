maintainer       "Benedikt Böhm"
maintainer_email "bb@xnull.de"
license          "Apache 2.0"
description      "Installs/Configures postfix"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.1"
supports         "gentoo"

depends "munin"
depends "nagios"
depends "openssl"
depends "portage"
depends "spamassassin"