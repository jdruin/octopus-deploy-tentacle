
resource_name :od_tentacle

property :instance, String, name_property: true
property :version, String
property :source, String
property :checksum, String
property :auto_upgrade, [true, false], default: true
property :home_path, String, default: 'C:\Octopus'
property :server_thumbprint, String
property :polling, [true, false], default: false
property :port, Integer, default: 10933
property :server, [String, nil], default: nil
property :api_key, String
property :roles, Array, default: ['default']
property :environment, Array, default: [node.chef_environment]
property :public_dns, String, default: node['fqdn']
property :open_firewall, [true, false], default: true

property :proxy_host, [Integer, nil], default: nil
property :proxy_password, [String, nil], default: nil
property :proxy_port, Integer, default: 80
property :proxy_username, [String, nil], default: nil
property :use_default_proxy, [true, false], default: false

default_action :install

action :install do

  Chef::Application.fatal!(':version cannot be nil for action :install') if new_resource.version.nil?

  tentacle_installer = ::File.join(Chef::Config[:file_cache_path], 'octopus-tentacle.msi')

  install_url = new_resource.source unless new_resource.source.nil?
  install_url = installer_url(new_resource.version, node[:kernel][:machine]) if install_url.nil?

  remote_file tentacle_installer do
    action :create
    source install_url
    checksum new_resource.checksum if new_resource.checksum
  end

  windows_package 'Octopus Deploy Tentacle' do
    action :install
    source tentacle_installer
    version new_resource.version if new_resource.version && new_resource.auto_upgrade
    installer_type :msi
    options '/qn /norestart'
  end
end

action :configure do

  Chef::Application.fatal!(':server_thumbprint cannot be nil for action :configure') if new_resource.server_thumbprint.nil?
  Chef::Application.fatal!(':api_key cannot be nil for action :configure') if new_resource.api_key.nil?
  if new_resource.polling && new_resource.server.nil?
    Chef::Application.fatal!(':server cannot be nil for action :configure if :polling is true')
  end

  od_tentacle new_resource.instance do
    version new_resource.version
  end

  install_dir = 'c:\\Program Files\\Octopus Deploy\\Tentacle\\'

  ## Setting the root key OD uses to look up its info
  registry_key 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Octopus\\Tentacle' do
    values    [{ name: 'InstallLocation', type: :string, data: install_dir }]
    action    :create
  end

  config_name = nil
  ## Stupid instances.  Checks to see if a 'non default' instance is being made
  if new_resource.instance.downcase != 'tentacle'
    tentacle_root = ::File.join(new_resource.home_path, new_resource.instance)
    config_name = "Tentacle-#{new_resource.instance}.config"
    service_name = "OctopusDeploy Tentacle: #{new_resource.instance}"
    service_path = "\"#{install_dir}Tentacle.exe\" run -instance=\"#{new_resource.instance}\""
    registry_key "HKEY_LOCAL_MACHINE\\SOFTWARE\\Octopus\\Tentacle\\#{new_resource.instance}" do
      values [{ name: 'ConfigurationFilePath', type: :string, data: ::File.join(tentacle_root, config_name) }]
      action :create
      recursive true
    end
  else
    config_name = 'Tentacle.config'
    tentacle_root = new_resource.home_path
    service_name = 'OctopusDeploy Tentacle'
    service_path = "\"#{install_dir}Tentacle.exe\" run -instance=\"Tentacle\""
    registry_key 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Octopus\\Tentacle\\Tentacle' do
      values [{ name: 'ConfigurationFilePath', type: :string, data: ::File.join(tentacle_root, config_name) }]
      action :create
      recursive true
    end
  end

  tentacle_port = new_resource.port

  if new_resource.open_firewall
    windows_firewall_rule 'OD Tentacle' do
      localport tentacle_port.to_s
      protocol 'TCP'
      firewall_action :allow
    end
  end

  config_path = ::File.join(tentacle_root, config_name)

  sub_id_from_config = subscription_id_from_config(config_path)

  if new_resource.polling
    subscription_id = if sub_id_from_config.nil?
                        squid = random_string(20)
                        "poll://#{squid}/"
                      else
                        sub_id_from_config
                      end
    communication_style = 2
  else
    subscription_id = nil
    communication_style = 1
  end

  cert_from_config = entry_from_config(config_path, 'Tentacle.Certificate')
  thumbprint_from_config = entry_from_config(config_path, 'Tentacle.CertificateThumbprint')

  tentacle_cert = if cert_from_config.nil?
                    encoded_tentacle_cert
                  else
                    { 'cert' => cert_from_config, 'thumbprint' => thumbprint_from_config }
                  end
  trusted_server_config = [{ 'Thumbprint' => new_resource.server_thumbprint,
                             'CommunicationStyle' => communication_style,
                             'Address' => "https://#{new_resource.public_dns}:#{new_resource.port}/",
                             'Squid' => nil,
                             'SubscriptionId' => subscription_id }].to_json

  od_configs = { 'od_home' => tentacle_root,
                 'cert' => tentacle_cert['cert'],
                 'cert_thumbprint' => tentacle_cert['thumbprint'],
                 'proxy_host' => new_resource.proxy_host,
                 'proxy_password' => new_resource.proxy_password,
                 'proxy_username' => new_resource.proxy_username,
                 'proxy_port' => new_resource.proxy_port,
                 'use_default_proxy' => new_resource.use_default_proxy,
                 'trusted_server' => trusted_server_config,
                 'application_dir' => "#{tentacle_root}\\Applications",
                 'nolisten' => !new_resource.polling,
                 'port' => tentacle_port,
  }

  directory tentacle_root do
    action :create
    recursive true
  end
  template config_path do
    source    'tentacle.config.erb'
    variables od_configs
  end

  create_service(service_name, service_path) unless service_installed?(service_name)

  windows_service service_name do
    service_name service_name
    action [:enable, :start]
  end
end

action :register do

  Chef::Application.fatal!(':server cannot be nil for action :register') if new_resource.server.nil?
  Chef::Application.fatal!(':api_key cannot be nil for action :register') if new_resource.api_key.nil?

  config_path = find_od_instance(new_resource.instance)
  if !config_path.nil?
    thumbprint = entry_from_config(config_path, 'Tentacle.CertificateThumbprint')
    if !tentacle_registered?(thumbprint, new_resource.server, new_resource.api_key)
      port = entry_from_config(config_path, 'Tentacle.Services.PortNumber')
      comm_style = comm_style_from_config(config_path)
      uri = uri_from_config(config_path)
      environ_ids = []

      [new_resource.environment].flatten.each do |e|
        environ_ids << get_environment_id(e.to_s, new_resource.server, new_resource.api_key)
      end

      if comm_style == 1
        machine = { 'Endpoint' =>
                      { 'CommunicationStyle' => 'TentaclePassive',
                        'Thumbprint' => thumbprint,
                        'Uri' => uri,
                      },
                    'EnvironmentIDs' => environ_ids,
                    'Name' => new_resource.public_dns,
                    'Roles' => new_resource.roles,
                    'Status' => 'Unknown',
                    'IsDisabled' => false,
                  }
        Chef::Log.debug(machine)
        register_tentacle(machine, new_resource.server, new_resource.api_key)
      else
        machine = { 'Endpoint' =>
                      { 'CommunicationStyle' => 'TentacleActive',
                        'Thumbprint' => thumbprint,
                        'Uri' => uri,
                      },
                    'EnvironmentIDs' => environ_ids,
                    'Name' => new_resource.public_dns,
                    'Roles' => new_resource.roles,
                    'Status' => 'Unknown',
                    'IsDisabled' => false,
                  }

        register_tentacle(machine, new_resource.server, new_resource.api_key)
      end
    end
  else
    ::Chef::Log.info("Instance named: #{new_resource.instance} does not exist on this node.")
  end
end

action :remove do
  #Check registry for instance info
  instance_path = find_od_instance(new_resource.instance)

  if !instance_path.nil?
    config_dir = ::File.dirname(instance_path)
    ::FileUtils.rm_rf(config_dir) unless !::Dir.exist?(config_dir)
  end
  #remove registry entries

  registry_key "HKEY_LOCAL_MACHINE\\SOFTWARE\\Octopus\\Tentacle\\#{new_resource.instance}" do
    action :delete
  end

end

action :uninstall do
  remove_tentacle_services
  windows_package 'Octopus Deploy Tentacle' do
    action :remove
  end
end

action_class do
  require 'json'
  require 'fileutils'
  include Druin::Octopus::Tentacle
  include Druin::Octopus::Rest
end
