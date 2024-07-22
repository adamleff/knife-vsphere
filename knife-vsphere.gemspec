$:.unshift(File.dirname(__FILE__) + "/lib")
require "knife-vsphere/version"

Gem::Specification.new do |s|
  s.name = "knife-vsphere"
  s.version = KnifeVsphere::VERSION
  s.summary = "VMware vSphere support for Chef Infra's Knife command"
  s.authors = "Ezra Pagel"
  s.description = "VMware vSphere support for Chef Infra's Knife command"
  s.email = "ezra@cpan.org"
  s.files = Dir["lib/**/*"] + %w{LICENSE}
  s.required_ruby_version = ">= 3.3"
  s.homepage = "https://github.com/chef/knife-vsphere"
  s.license = "Apache-2.0"
  s.add_dependency "rbvmomi2", ">= 3.5.0", "< 4.0"
  s.add_dependency "filesize", ">= 0.1.1", "< 0.3.0"
  s.add_dependency "chef-vault", ">= 2.6"
  s.add_dependency "knife", "~> 18"
end
