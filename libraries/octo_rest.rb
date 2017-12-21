
require 'chef/http'

module Druin
  module Octopus
    module Rest
      def rest_client(server_url, api_key)
        options = { headers: { 'X-Octopus-ApiKey' => api_key } }
        Chef::HTTP.new("#{server_url}/api", options)
      end

      def tentacle_registered?(thumbprint, server_url, api_key)
        ::JSON.parse(rest_client(server_url, api_key).get("/machines/all?thumbprint=#{thumbprint}")).any? do |machine|
          machine['Thumbprint'] == thumbprint
        end
      end

      def register_tentacle(machine, server_url, api_key)
        begin
          body = ::JSON.generate(machine)
          rest_client(server_url, api_key).post('/machines', body)
        rescue Exception => e
          if e.message.include?('400')
            Chef::Log.warn('You have given a bad OD parameter or the tentacle is already registered.')
          end
        end
      end

      def discover_tentacle(client_fqdn, client_port, server_url, api_key)
        rest_client(server_url, api_key).get("machines/discover?host=#{client_fqdn}&port=#{client_port}&type=TentaclePassive")
      end

      def get_environment_id(environment_name, server_url, api_key)
        ::JSON.parse(rest_client(server_url, api_key).get('environments/all')).each do |env|
          next unless env['Name'].downcase == environment_name.downcase
          return env['Id']
        end
      end
    end
  end
end
