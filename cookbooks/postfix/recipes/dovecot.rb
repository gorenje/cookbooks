portage_package_use "mail-mta/postfix|dovecot" do
  package "mail-mta/postfix"
  use %w(dovecot-sasl)
end

include_recipe "postfix"

postconf "Dovecot SASL/LDA" do
  set :dovecot_destination_recipient_limit => 1,
      :smtpd_sasl_type => "dovecot",
      :smtpd_sasl_path => "private/auth",
      :smtpd_sasl_auth_enable => "yes"
end

postmaster "dovecot" do
  unpriv "n"
  command "pipe"
  args "flags=DRhu user=mail:mail argv=/usr/libexec/dovecot/deliver -f ${sender} -d ${recipient}"
end
