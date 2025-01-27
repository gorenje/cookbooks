module Gentoo
  module Portage
    module PackageConf

      # Creates or deletes per package portage attributes. Returns true if it
      # changes (sets or deletes) something.
      # * action == :create || action == :delete
      # * conf_type =~ /\A(use|keywords|mask|unmask)\Z/
      def manage_package_conf(action, conf_type, name, package = nil, flags = nil)
        conf_file = package_conf_file(conf_type, name)
        case action
        when :create
          create_package_conf_file(conf_file, normalize_package_conf_content(package, flags))
        when :delete
          delete_package_conf_file(conf_file)
        else
          raise Chef::Exceptions::Package, "Unknown action :#{action}."
        end
      end

      # Returns the portage package control file name:
      # =net-analyzer/nagios-core-3.1.2 => chef-net-analyzer-nagios-core-3-1-2
      # =net-analyzer/netdiscover => chef-net-analyzer-netdiscover
      def package_conf_file(conf_type, name)
        conf_dir = "/etc/portage/package.#{conf_type}"
        raise Chef::Exceptions::Package, "#{conf_type} should be a directory." unless ::File.directory?(conf_dir)

        package_atom = name.strip.split(/\s+/).first
        package_file = package_atom.gsub(/[\/\.|]/, "-").gsub(/[^a-z0-9_\-]/i, "")
        return "#{conf_dir}/chef-#{package_file}"
      end

      # Normalizes package conf content
      def normalize_package_conf_content(name, flags = nil)
        [ name, normalize_flags(flags) ].join(' ')
      end

      # Normalizes String / Arrays
      def normalize_flags(flags)
        if flags.is_a?(Array)
          flags.sort.uniq.join(' ')
        else
          flags
        end
      end

      def same_content?(filepath, content)
        content.strip == ::File.read(filepath).strip
      end

      def create_package_conf_file(conf_file, content)
        return nil if ::File.exists?(conf_file) && same_content?(conf_file, content)

        ::File.open("#{conf_file}", "w") { |f| f << content + "\n" }
        Chef::Log.info("Created #{conf_file} \"#{content}\".")
        true
      end

      def delete_package_conf_file(conf_file)
        return nil unless ::File.exists?(conf_file)

        ::File.delete(conf_file)
        Chef::Log.info("Deleted #{conf_file}")
        true
      end
    end

    module Emerge
      include Gentoo::Portage::PackageConf

      def package_info
        @package_info ||= package_info_from_eix(@new_resource.package_name)
      end

      def emerge(action)
        if package_info[:candidate_version].to_s == ""
          raise Chef::Exceptions::Package, "No candidate version available for #{@new_resource.name}"
        end

        if emerge?(action)
          Chef::Mixin::Command.run_command_with_systems_locale(
            :command => "/usr/bin/emerge --color=n --nospinner --quiet #{@new_resource.options} #{package_info[:package_atom]}"
          )
        end
      end

      private

      def emerge?(action)
        version = @new_resource.version.to_s

        if package_info[:current_version] == ""
          Chef::Log.info("No version found. Installing package[#{package_info[:package_atom]}].")
          return true
        end

        case action
        when :install
          return false if version == ""
          return false if package_info[:current_version] == version
          Chef::Log.info("Installing package[#{package_info[:package_atom]}] (version requirements unmet).")
          true

        when :upgrade
          return false if package_info[:current_version] == package_info[:candidate_version]
          true

        else
          raise Chef::Exceptions::Package, "Unknown action :#{action}"
        end
      end

      # Searches for "package_name" and returns a hash with parsed information
      # returned by eix.
      #
      #   # git is installed on the system
      #   package_info_from_eix("git")
      #   => {
      #        :category => "dev-vcs",
      #        :package_name => "git",
      #        :current_version => "1.6.3.3",
      #        :candidate_version => "1.6.4.4"
      #      }
      #   # git isn't installed
      #   package_info_from_eix("git")
      #   => {
      #        :category => "dev-vcs",
      #        :package_name => "git",
      #        :current_version => "",
      #        :candidate_version => "1.6.4.4"
      #      }
      #   package_info_from_eix("dev-vcs/git") == package_info_from_eix("git")
      #   => true
      #   package_info_from_eix("package/doesnotexist")
      #   => nil
      def package_info_from_eix(package_name)
        eix = "/usr/bin/eix"
        eix_update = "/usr/bin/eix-update"

        unless ::File.executable?(eix)
          raise Chef::Exceptions::Package, "You need to install app-portage/eix for fast package searches."
        end

        # We need to update the eix database if it's older than the current portage
        # tree or the eix binary.
        unless ::FileUtils.uptodate?("/var/cache/eix", [eix, "/usr/portage/metadata/timestamp"])
          Chef::Log.debug("eix database outdated, calling `#{eix_update}`.")
          Chef::Mixin::Command.run_command_with_systems_locale(:command => eix_update)
        end

        query_command = [
          eix,
          "--nocolor",
          "--pure-packages",
          "--stable",
          "--exact",
          '--format "<category>\t<name>\t<installedversions:VERSION>\t<bestversion:VERSION>\n"',
          package_name.count("/") > 0 ? "--category-name" : "--name",
          package_name
        ].join(" ")

        eix_out = eix_stderr = nil

        Chef::Log.debug("Calling `#{query_command}`.")
        status = Chef::Mixin::Command.popen4(query_command) do |pid, stdin, stdout, stderr|
          eix_stderr = stderr.read
          if stdout.read.split("\n").first =~ /\A(\S+)\t(\S+)\t(\S*)\t(\S+)\Z/
            eix_out = {
              :category => $1,
              :package_name => $2,
              :current_version => $3,
              :candidate_version => $4
            }
          end
        end

        eix_out ||= {}

        unless status.exitstatus == 0
          raise Chef::Exceptions::Package, "eix search failed: `#{query_command}`\n#{eix_stderr}\n#{status.inspect}!"
        end

        eix_out[:package_atom] = full_package_atom(eix_out[:category], eix_out[:package_name], @new_resource.version)
        eix_out
      end

      def full_package_atom(category, name, version = nil)
        package_atom = "#{category}/#{name}"
        return package_atom unless version

        if version =~ /^\~(.+)/
          "~#{package_name}-#{$1}"
        else
          "=#{package_name}-#{version}"
        end
      end

    end
  end
end

# monkeypatch Chefs package resource and portage provider
class Chef
  class Provider
    class Package
      class Portage < Chef::Provider::Package
        include ::Gentoo::Portage::Emerge

        def load_current_resource
          @current_resource = Chef::Resource::Package.new(@new_resource.name)
          @current_resource.package_name(@new_resource.package_name)

          begin
            unless package_info[:current_version].strip.empty?
              @current_resource.version(package_info[:current_version])
            end
          rescue Chef::Exceptions::Package
            # not available
          end

          @current_resource
        end

        def install_package(name, version)
          emerge(:install)
        end

        def upgrade_package(name, version)
          emerge(:upgrade)
        end

        def candidate_version
          @candidate_version ||= package_info[:candidate_version]
        end

      end
    end
  end
end
