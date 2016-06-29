require "pathname"
require "puppet/provider/package"
require "puppet/util/execution"

Puppet::Type.type(:package).provide :cmsdist, :parent => Puppet::Provider::Package do
  include Puppet::Util::Execution

  desc "CMS packages via cmspkg."

  has_feature :unversionable
  has_feature :package_settings
  has_feature :install_options

  def self.home
    if boxen_home = Facter.value(:boxen_home)
      "#{boxen_home}/homebrew"
    else
      "/opt/cms"
    end
  end

  def self.default_architecture
    "slc6_amd64_gcc530"
  end

  def self.default_cms_user
    "cmsbuild"
  end

  def self.default_repository
    return "cms"
  end

  def self.default_server
    return "cmsrep.cern.ch"
  end

  def self.default_server_path
    return "cmssw/cms"
  end
  
  def get_install_options
    if @resource[:install_options].is_a?(Array)
      return @resource[:install_options][0]
    elsif @resource[:install_options].is_a?(Hash)
      return @resource[:install_options]
    else
      Puppet.debug "install_options not specified. Using default."
      return {}
    end
  end

  def self.bootstrapped?(architecture, prefix)
    Puppet.debug "Checking if #{architecture} bootstrapped in #{prefix}."
    return File.exists? File.join([prefix, architecture, "cms", "cms-common", "1.0", "etc", "profile.d", "init.sh"])
  end

  # Helper function to boostrap a CMS environment.
  def bootstrap(architecture, prefix, user, repository, server, server_path)
    if self.class.bootstrapped?(architecture, prefix)
      execute ["chown","-R", user, File.join([prefix, architecture , "var/lib/rpm"])," | true"]
      Puppet.debug("Bootstrap previously done.")
      return
    end
    Puppet.debug("Creating #{prefix} and assigning it to #{user}")
    begin
      execute ["mkdir", "-p", prefix]
      execute ["chown", user, prefix]
    rescue Exception => e
      Puppet.warning "Unable to create / find installation area. Please check your install_options."
      raise e
    end
    Puppet.debug("Fetching bootstrap from #{repository}")
    execute ["wget", "--no-check-certificate", "-O",
             File.join([prefix, "bootstrap-#{architecture}.sh"]),
             "#{server}/#{server_path}/repos/bootstrap.sh"]
    Puppet.debug("Installing CMS bootstrap.")
    execute ["sudo", "-u", user,
             "sh", "-x", File.join([prefix, "bootstrap-#{architecture}.sh"]),
             "setup",
             "-path", prefix,
             "-arch", architecture,
             "-server", server,
             "-server-path", server_path,
             "-assume-yes"]
    Puppet.debug("Bootstrap completed")
  end

  def install
    opts = self.get_install_options
    prefix = (opts["install_prefix"] or self.class.home)
    architecture = (opts["architecture"] or self.class.default_architecture)
    user = (opts["install_user"] or self.class.default_cms_user)
    repository = (opts["repository"] or self.class.default_repository)
    server = (opts["server"] or self.class.default_server)
    server_path = (opts["server_path"] or self.class.default_server_path)
    fullname, overwrite_architecture = @resource[:name].split "/"
    architecture = (overwrite_architecture and overwrite_architecture or architecture)
    bootstrap(architecture, prefix, user, repository, server, server_path)
    output = `sudo -u #{user} bash -c '#{prefix}/common/cmspkg -a #{architecture} update && #{prefix}/common/cmspkg -a #{architecture} install -y #{fullname} 2>&1'`
    Puppet.debug output
    if $?.to_i != 0
      raise Puppet::Error, "Could not install package. #{output}"
    end
    $?.to_i
  end

  def uninstall
    opts = self.get_install_options
    prefix = (opts["install_prefix"] or self.class.home)
    architecture = (opts["architecture"] or self.class.default_architecture)
    user = (opts["install_user"] or self.class.default_cms_user)
    repository = (opts["repository"] or self.class.default_repository)
    server = (opts["server"] or self.class.default_server)
    server_path = (opts["server_path"] or self.class.default_server_path)
    fullname, overwrite_architecture = @resource[:name].split "/"
    architecture = (overwrite_architecture and overwrite_architecture or architecture)
    bootstrap(architecture, prefix, user, repository, server, server_path)
    output = `sudo -u #{user} bash -c '#{prefix}/common/cmspkg -a #{architecture} -y --dist-clean --delete-dir remove #{fullname} 2>&1'`
    Puppet.debug output
    if $?.to_i != 0
      raise Puppet::Error, "Could not remove package. #{output}"
    end
    $?.to_i
  end

  def query
    opts = self.get_install_options
    prefix = (opts["install_prefix"] or self.class.home)
    architecture = (opts["architecture"] or self.class.default_architecture)
    user = (opts["install_user"] or self.class.default_cms_user)
    repository = (opts["repository"] or self.class.default_repository)
    server = (opts["server"] or self.class.default_server)
    server_path = (opts["server_path"] or self.class.default_server_path)
    Puppet.debug "query invoked with #{prefix} #{architecture} #{user}"
    fullname, overwrite_architecture = @resource[:name].split "/"
    architecture = (overwrite_architecture and overwrite_architecture or architecture)
    group, package, version = fullname.split "+"
    bootstrap(architecture, prefix, user, repository, server, server_path)
    existance = File.exists? File.join([prefix, architecture, group, package,
                                        version, "etc", "profile.d", "init.sh"])
    if not existance
      return nil
    else
      return { :ensure => "1.0", :name => @resource[:name] }
    end
  end

  def self.instances
    return []
  end

  # Override default `execute` to run super method in a clean
  # environment without Bundler, if Bundler is present
  def execute(*args)
    if Puppet.features.bundled_environment?
      Bundler.with_clean_env do
        super
      end
    else
      super
    end
  end

  # Override default `execute` to run super method in a clean
  # environment without Bundler, if Bundler is present
  def self.execute(*args)
    if Puppet.features.bundled_environment?
      Bundler.with_clean_env do
        super
      end
    else
      super
    end
  end
end
