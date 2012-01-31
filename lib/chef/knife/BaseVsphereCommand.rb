#
# Author:: Ezra Pagel (<ezra@cpan.org>)
# Contributor:: Jesse Campbell (<hikeit@gmail.com>)
# License:: Apache License, Version 2.0
#

require 'chef/knife'
require 'rbvmomi'

# Base class for vsphere knife commands
class Chef
	class Knife
		class BaseVsphereCommand < Knife

			deps do
				require 'chef/knife/bootstrap'
				Chef::Knife::Bootstrap.load_deps
				require 'fog'
				require 'socket'
				require 'net/ssh/multi'
				require 'readline'
				require 'chef/json_compat'
			end


			def self.get_common_options

				option :vsphere_user,
					:short => "-u USERNAME",
					:long => "--user USERNAME",
					:description => "The username for the host"

				option :vsphere_pass,
					:short => "-p PASSWORD",
					:long => "--password PASSWORD",
					:description => "The password for the host"

				option :datacenter,
					:short => "-d DATACENTER",
					:long => "--datacenter DATACENTER",
					:description => "The Datacenter to create the VM in"

				option :path,
					:long => "--path SOAP_PATH",
					:description => "The SOAP endpoint path",
					:proc => Proc.new { |p| Chef::Config[:knife][:path] = p },
					:default => "/sdk"

				option :port,
					:long => "--port PORT",
					:description => "The VI SDK port number to use",
					:proc => Proc.new { |p| Chef::Config[:knife][:port] = p },
					:default => 443

				option :use_ssl,
					:long => "--ssl USE_SSL",
					:description => "Whether to use SSL connection",
					:default => true

				option :insecure,
					:short => "-i USE_INSECURE_SSL",
					:long => "--insecure USE_INSECURE_SSL",
					:description => "Determines whether SSL certificate verification is skipped",
					:default => true

				option :folder,
					:short => "-f FOLDER",
					:long => "--folder FOLDER",
					:description => "The folder to get VMs from",
					:default => ''

			end

			def locate_config_value(key)
				key = key.to_sym
				Chef::Config[:knife][key] || config[key]
			end

			def get_vim_connection

				conn_opts = {
					:host => locate_config_value(:vsphere_host),
					:path => config[:path],
					:port => config[:port],
					:use_ssl => config[:ssl],
					:user => locate_config_value(:vsphere_user),
					:password => locate_config_value(:vsphere_pass),
					:insecure => config[:insecure]
				}

				#    opt :insecure, "don't verify ssl certificate", :short => 'k', :default => (ENV['RBVMOMI_INSECURE'] == '1')
				#    opt :debug, "Log SOAP messages", :short => 'd', :default => (ENV['RBVMOMI_DEBUG'] || false)

				vim = RbVmomi::VIM.connect conn_opts
				config[:vim] = vim
				return vim
			end

			def find_folder(folderName)
				dcname = config[:vsphere_dc] || Chef::Config[:knife][:vsphere_dc]
				dc = config[:vim].serviceInstance.find_datacenter(dcname) or abort "datacenter not found"
				baseEntity = dc.vmFolder
				entityArray = folderName.split('/')
				entityArray.each do |entityArrItem|
					if entityArrItem != ''
						baseEntity = baseEntity.childEntity.grep(RbVmomi::VIM::Folder).find { |f| f.name == entityArrItem } or
              abort "no such folder #{folderName} while looking for #{entityArrItem}"
					end
				end
				baseEntity
			end

			def find_network(networkName)
				dcname = config[:vsphere_dc] || Chef::Config[:knife][:vsphere_dc]
				dc = config[:vim].serviceInstance.find_datacenter(dcname) or abort "datacenter not found"
				baseEntity = dc.network
				baseEntity.find { |f| f.name == networkName } or abort "no such network #{networkName}"
			end

			def find_pool(poolName)
				dcname = config[:vsphere_dc] || Chef::Config[:knife][:vsphere_dc]
				dc = config[:vim].serviceInstance.find_datacenter(dcname) or abort "datacenter not found"
				baseEntity = dc.hostFolder
				entityArray = poolName.split('/')
				entityArray.each do |entityArrItem|
					if entityArrItem != ''
						if baseEntity.is_a? RbVmomi::VIM::Folder
							baseEntity = baseEntity.childEntity.find { |f| f.name == entityArrItem } or
                abort "no such pool #{poolName} while looking for #{entityArrItem}"
						elsif baseEntity.is_a? RbVmomi::VIM::ClusterComputeResource
							baseEntity = baseEntity.resourcePool.resourcePool.find { |f| f.name == entityArrItem } or
                abort "no such pool #{poolName} while looking for #{entityArrItem}"
						elsif baseEntity.is_a? RbVmomi::VIM::ResourcePool
							baseEntity = baseEntity.resourcePool.find { |f| f.name == entityArrItem } or
                abort "no such pool #{poolName} while looking for #{entityArrItem}"
						else
							abort "Unexpected Object type encountered #{baseEntity.type} while finding resourcePool"
						end
					end
				end

        baseEntity = baseEntity.resourcePool if not baseEntity.is_a?(RbVmomi::VIM::ResourcePool) and baseEntity.respond_to?(:resourcePool)
        baseEntity
			end

			def find_datastore(dsName)
				dcname = config[:vsphere_dc] || Chef::Config[:knife][:vsphere_dc]
				dc = config[:vim].serviceInstance.find_datacenter(dcname) or abort "datacenter not found"
				baseEntity = dc.datastore
				baseEntity.find { |f| f.info.name == dsName } or abort "no such datastore #{dsName}"
			end


			def find_all_in_folder(folder, type)
				folder.childEntity.grep(type)
			end

			def find_in_folder(folder, type, name)
				folder.childEntity.grep(type).find { |o| o.name == name }
			end

			def fatal_exit(msg)
				ui.fatal(msg)
				exit 1
			end

		end
	end
end
