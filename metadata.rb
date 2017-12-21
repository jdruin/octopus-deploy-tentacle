name 'od-tentacle'
maintainer 'The Authors'
maintainer_email 'you@example.com'
license 'All Rights Reserved'
description 'Installs/Configures an Octopus Deploy tentacle'
long_description 'Installs/Configures an Octopus Deploy tentacle'
version '0.1.0'
chef_version '>= 12.1' if respond_to?(:chef_version)

supports 'windows'

depends 'windows_firewall', '~> 3.0.2'

gem 'win32-service'
gem 'ffi'

# The `issues_url` points to the location where issues for this cookbook are
# tracked.  A `View Issues` link will be displayed on this cookbook's page when
# uploaded to a Supermarket.
#
# issues_url 'https://github.com/<insert_org_here>/od-tentacle/issues'

# The `source_url` points to the development repository for this cookbook.  A
# `View Source` link will be displayed on this cookbook's page when uploaded to
# a Supermarket.
#
# source_url 'https://github.com/<insert_org_here>/od-tentacle'
