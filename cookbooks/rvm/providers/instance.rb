include ChefUtils::RVM

action :create do
  rvm = infer_vars(new_resource.name, new_resource.version)

  bash "install rvm-#{rvm[:version]}" do
    code <<-EOS
    export USER=#{rvm[:user]}
    export HOME=#{rvm[:homedir]}

    tmpfile=$(mktemp)
    curl -s https://rvm.beginrescueend.com/install/rvm -o ${tmpfile}
    chmod +x ${tmpfile}
    ${tmpfile} #{rvm[:version]}
    rm -f ${tmpfile}
    EOS

    creates "#{rvm[:path]}/src/rvm-#{rvm[:version]}"
    user rvm[:user]
    group rvm[:group]
  end

  portage_preserve_libs "rvm-#{rvm[:user]}" do
    paths [
      "#{rvm[:path]}/rubies",
      "#{rvm[:path]}/gems",
    ]
  end
end

action :delete do
  rvm = infer_vars(new_resource.user)

  directory rvm[:path] do
    action :delete
    recursive true
  end
end
