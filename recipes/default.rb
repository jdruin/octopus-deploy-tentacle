#
# Cookbook:: od-tentacle
# Recipe:: default
#
# Copyright:: 2017, Jeffrey Druin, All Rights Reserved.

od_tentacle 'Tentacle' do
  action :configure
  version node['octopus_deploy']['version']
  server_thumbprint node['octopus_deploy']['server']['thumbprint']
  api_key node['octopus_deploy']['server']['api_key']
  polling ['octopus_deploy']['client']['polling']
  server node['octopus_deploy']['server']['url']
end

od_tentacle 'Tentacle' do
  action :register
  server node['octopus_deploy']['server']['url']
  api_key node['octopus_deploy']['server']['api_key']
  roles node['roles']
end