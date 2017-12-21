#
# Cookbook:: od-tentacle
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

od_tentacle 'Tentacle' do
  action :configure
  version '3.16.3'
  server_thumbprint '22A1E3307686D1D8E9EFB8FCA46D292C578A8FAF'
  api_key 'API-KWHD4XYZEV5VYOWDTEJ7FVZL44'
  polling false
  server 'http://octopusdeploy'
end

# od_tentacle 'Tentacle' do
#   action :uninstall
# end

# od_tentacle 'Tentacle' do
#   action :remove
# end

od_tentacle 'Tentacle' do
  action :register
  server 'http://octopusdeploy'
  api_key 'API-KWHD4XYZEV5VYOWDTEJ7FVZL44'
end
