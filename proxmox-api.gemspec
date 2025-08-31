# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name                  = 'proxmox-api'
  spec.version               = '2.1.1'
  spec.summary               = 'Proxmox VE REST API wrapper'
  spec.description           = 'Proxmox VE REST API wrapper'
  spec.authors               = ['Eugene Lapeko', 'Xavi Ablaza']
  spec.email                 = 'xavi@hostari.com'
  spec.files                 = ['Gemfile', 'LICENSE', 'lib/proxmox_api.rb']
  spec.require_paths         = ['lib']
  spec.required_ruby_version = '>= 3.0'
  spec.homepage              = 'https://github.com/xaviablaza/proxmox-api'
  spec.license               = 'MIT'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
