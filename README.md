# od-tentacle

This cookbook is heavily influenced by https://github.com/cvent/octopus-deploy-cookbook.  Special thanks to Brent Montague (@BrentM5) for the cookbook.

This cookbook is still very beta and was built to get around the scripting Octopus Deploy wants you to use to install the tentacle on a client.  I have had a lot of issues with it in the past and decided to go down a long road to this cookbook.
```
:instance, String, name_property, Used as the name for the instance
:version, String, Required for :install and :configure
:source, String, Defaults to Octopus Deploy site, but you can use this to point to a specific installer at a URL.
:checksum, String, Good idea to prevent the repeated download of the installer
:auto_upgrade, [true, false], default: true
:home_path, String, default: 'C:\Octopus', Change this to set the configs to a non default location
:server_thumbprint, String, Required for :config, Thumbprint for server
:polling, [true, false], default: false, Turns on the polling client vs listening
:port, Integer, default: 10933, Tentacle port
:server, [String, nil], default: nil, Required for :configure and register. Octopus Deploy server.
:api_key, String, Required for :register. An api key from the Octopus Deploy server.
:roles, Array, default: ['default']
:environment, Array, default: [node.chef_environment]
:public_dns, String, default: node['fqdn']
:open_firewall, [true, false], default: true
:proxy_host, [Integer, nil], default: nil
:proxy_password, [String, nil], default: nil
:proxy_port, Integer, default: 80
:proxy_username, [String, nil], default: nil
:use_default_proxy, [true, false], default: false
```

```ruby
# Installs the tentacle only
od_tentacle 'Tentacle' do
  version #<version>
end

# Installs and configures the node locally
od_tentacle 'Tentacle' do
  action :configure
  version #<version>
  server_thumbprint <server thumbprint>
  api_key #<server api key>
  polling false
  server #<server url>
end

# Registers with the Octopus Deploy server

od_tentacle 'Tentacle' do
  action :register
  server #<server url>
  api_key #<server api key>
end

# Unistalls the tentacle
od_tentacle 'Tentacle' do
  action :uninstall
end

# Removes the instance information for a tentacle
od_tentacle 'Tentacle' do
  action :remove
end
```
