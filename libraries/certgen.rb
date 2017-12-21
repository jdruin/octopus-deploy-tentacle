
module Druin
  module Octopus
    ## A class to help with working with those stupid encrypted certs in Octopus
    ## Deploy configs
    class Certgen
      require 'openssl'
      require 'base64'
      require_relative 'dpapi'
      require 'tmpdir'
      include DpApi

      def self_signed_cert(subject, time_length, key_strength = 2048)
        cert = generate_cert_stub(subject, time_length)
        key = OpenSSL::PKey::RSA.new(key_strength)
        cert.public_key = key.public_key
        cert.serial = 0x0
        cert.version = 2
        ef = generate_cert_extensions(cert)
        cert.extensions = [ef.create_extension('basicConstraints', 'CA:TRUE', true), ef.create_extension('subjectKeyIdentifier', 'hash')]
        cert.add_extension ef.create_extension('authorityKeyIdentifier', 'keyid:always,issuer:always')
        cert.sign(key, OpenSSL::Digest::SHA1.new) ## Need to update this to SHA256
        Hash['cert' => cert, 'private_key' => key, 'thumbprint' => OpenSSL::Digest::SHA1.new(cert.to_der).to_s]
      end

      def generate_cert_stub(subject, years = 1)
        cert = OpenSSL::X509::Certificate.new
        cert.subject = cert.issuer = OpenSSL::X509::Name.parse(subject)
        cert.not_before = Time.now
        cert.not_after = Time.now + years.to_i * (365 * 24 * 60 * 60)
        cert
      end

      def generate_cert_extensions(cert)
        ef = OpenSSL::X509::ExtensionFactory.new
        ef.subject_certificate = cert
        ef.issuer_certificate = cert
        ef
      end

      def create_pkcs12(pass, name, key, cert)
        OpenSSL::PKCS12.create(pass, name, key, cert)
      end

      def od_encoded_cert(pkcs12)
        path = File.join(Dir.tmpdir, 'OD_cert.pfx')
        File.open(path, 'wb') { |f| f.print pkcs12.to_der }
        cert_file = File.binread(path)
        File.delete(path)
        base64_cert =  Base64.strict_encode64(cert_file)
        encrypted_cert = encrypt(base64_cert, nil, [LOCAL_MACHINE])
        Base64.strict_encode64(encrypted_cert)
      end
    end
  end
end
