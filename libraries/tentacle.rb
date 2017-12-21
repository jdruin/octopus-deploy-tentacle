
module Druin
  module Octopus
    module Tentacle
      require 'win32/service'
      include Win32
      def encoded_tentacle_cert(time_length = 100)
        require_relative 'certgen'
        require_relative 'dpapi'

        cert_gen = ::Druin::Octopus::Certgen.new
        new_cert = cert_gen.self_signed_cert('/CN=Octopus Tentacle', time_length)

        p12_cert = cert_gen.create_pkcs12(nil,
                                          'OctopusTentacle',
                                          new_cert['private_key'],
                                          new_cert['cert'])
        encoded_cert = cert_gen.od_encoded_cert(p12_cert)
        thumbprint = new_cert['thumbprint'].to_s.upcase
        cert_info = { 'cert' => encoded_cert, 'thumbprint' => thumbprint }
        cert_info
      end

      def installer_url(version, os_arch)
        if os_arch == 'x86_64'
          "https://download.octopusdeploy.com/octopus/Octopus.Tentacle.#{version}-x64.msi"
        else
          "https://download.octopusdeploy.com/octopus/Octopus.Tentacle.#{version}.msi"
        end
      end

      def random_string(length)
        require 'securerandom'
        SecureRandom.hex(length)
      end

      def entry_from_config(config_path, key)
        require 'nokogiri'
        return nil unless File.exist?(config_path)
        File.open(config_path, 'r') do |od_config|
          doc = Nokogiri::XML(od_config) {|conf| conf.noblanks }
          doc.xpath('/octopus-settings/set').each do |setting|
            next unless setting['key'] == key
            return setting.text
          end
        end
      end

      def subscription_id_from_config(config_path)
        require 'nokogiri'
        return nil unless File.exist?(config_path)
        File.open(config_path, 'r') do |od_config|
          doc = Nokogiri::XML(od_config) {|conf| conf.noblanks }
          doc.xpath('/octopus-settings/set').each do |setting|
            next unless setting['key'] == 'Tentacle.Communication.TrustedOctopusServers'
            servers = ::JSON.parse setting.text
            servers.each do |s|
              return s['SubscriptionId']
            end
          end
        end
      end

      def comm_style_from_config(config_path)
        require 'nokogiri'
        return nil unless File.exist?(config_path)
        File.open(config_path, 'r') do |od_config|
          doc = Nokogiri::XML(od_config) {|conf| conf.noblanks }
          doc.xpath('/octopus-settings/set').each do |setting|
            next unless setting['key'] == 'Tentacle.Communication.TrustedOctopusServers'
            servers = ::JSON.parse setting.text
            servers.each do |s|
              return s['CommunicationStyle']
            end
          end
        end
      end

      def uri_from_config(config_path)
        require 'nokogiri'
        return nil unless File.exist?(config_path)
        File.open(config_path, 'r') do |od_config|
          doc = Nokogiri::XML(od_config) {|conf| conf.noblanks }
          doc.xpath('/octopus-settings/set').each do |setting|
            next unless setting['key'] == 'Tentacle.Communication.TrustedOctopusServers'
            servers = ::JSON.parse setting.text
            servers.each do |s|
              return s['Address']
            end
          end
        end
      end

      def create_service(service_name, service_path)
        Service.create({ service_name: service_name,
                         host: nil,
                         service_type: Service::WIN32_OWN_PROCESS,
                         description: 'Octopus Deploy: Tentacle deployment agent',
                         start_type: Service::AUTO_START,
                         error_control: Service::ERROR_NORMAL,
                         binary_path_name: service_path,
                         load_order_group: 'Network',
                         dependencies: nil,
                         display_name: service_name,
        })
      end

      def service_installed?(service)
        Service.exists?(service)
      end

      def remove_tentacle_services
        Service.services{ |s|
          if s.service_name.downcase.include? 'octopusdeploy tentacle'
            Service.stop(s.service_name)
            Service.delete(s.service_name)
          end
        }
      end

      def find_od_instance(instance)
        require 'win32/registry'
        if registry_key_exists? ("HKEY_LOCAL_MACHINE\\SOFTWARE\\Octopus\\Tentacle\\#{instance}")
          access = Win32::Registry::KEY_ALL_ACCESS
          keyname = "SOFTWARE\\Octopus\\Tentacle\\#{instance}"
          Win32::Registry::HKEY_LOCAL_MACHINE.open(keyname, access) do |reg|
            reg['ConfigurationFilePath']
          end
        end
      end
    end
  end
end
