require 'chef/knife'
require 'chef/knife/base_vsphere_command'
require 'rbvmomi'
require 'netaddr'

# list hosts belonging to pool
class Chef::Knife::VsphereHostsList < Chef::Knife::BaseVsphereCommand
  banner 'knife vsphere hosts list'

  common_options
  option :pool,
         long: '--pool pool',
         short: '-h',
         description: 'Target pool'

  def find_pools(folder, poolname = nil)
    pools = traverse_folders_for_pools(folder)
    clusters = traverse_folders_for_computeresources(folder)
    cluster_pool = clusters + pools
    poolname.nil? ? cluster_pool : cluster_pool.select { |p| p.name == poolname }
  end

  def run
    vim_connection
    dc = datacenter
    folder = dc.hostFolder

    target_pool = config[:pool]

    pools = find_pools(folder, target_pool)
    if target_pool && pools.empty?
      puts "Pool #{target_pool} not found"
      return
    end

    pool_list = pools.map do |pool|
      host_list = list_hosts(pool)
      { 'Pool' => pool.name, 'Hosts' => host_list }
    end
    ui.output(pool_list)
  end

  private

  def list_hosts(pool)
    hosts = pool.host || []
    hosts.map do |hostc|
      { 'Host' => hostc.name }
    end
  end
end
