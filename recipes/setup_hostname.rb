#
# Cookbook Name:: rightscale
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

require 'socket'

def local_ip
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true # Turn off reverse DNS resolution temporarily.
  UDPSocket.open do |s|
    s.connect '64.233.187.99', 1
    s.addr.last
  end
ensure
  Socket.do_not_reverse_lookup = orig
end

def show_host_info
  # Display current hostname values in log.
  log "  Hostname: #{`hostname` == '' ? '<none>' : `hostname`}"
  log "  Network node hostname: #{`uname -n` == '' ? '<none>' : `uname -n`}"
  log "  Alias names of host: #{`hostname -a` == '' ? '<none>' : `hostname -a`}"
  log "  Short host name (cut from first dot of hostname): #{`hostname -s` == '' ? '<none>' : `hostname -s`}"
  log "  Domain of hostname: #{`domainname` == '' ? '<none>' : `domainname`}"
  log "  FQDN of host: #{`hostname -f` == '' ? '<none>' : `hostname -f`}"
end

# Set hostname from short or long (when domain_name set).
if "#{node.rightscale.domain_name}" != ""
  hostname = "#{node.rightscale.short_hostname}.#{node.rightscale.domain_name}"
  hosts_list = "#{node.rightscale.short_hostname}.#{node.rightscale.domain_name} #{node.rightscale.short_hostname}"
else
  hostname = "#{node.rightscale.short_hostname}"
  hosts_list = "#{node.rightscale.short_hostname}"
end

# Show current host info.
log "  Setting hostname for '#{hostname}'."
log "  == Current host/node information =="
show_host_info

# Get node IP.
node_ip = "#{local_ip}"
log "  Node IP: #{node_ip}"

# Update /etc/hosts
log "  Configure /etc/hosts"
template "/etc/hosts" do
  source "hosts.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    :node_ip => node_ip,
    :hosts_list => hosts_list
  )
end

# Update /etc/hostname
log "  Configure /etc/hostname"
file "/etc/hostname" do
  owner "root"
  group "root"
  mode "0755"
  content "#{node.rightscale.short_hostname}"
  action :create
end

# Update /etc/resolv.conf
log "  Configure /etc/resolv.conf"
nameserver=`cat /etc/resolv.conf  | grep -v '^#' | grep nameserver | awk '{print $2}'`
if nameserver != ""
  nameserver="nameserver #{nameserver}"
end

if "#{node.rightscale.domain_name}" != ""
  domain = "domain #{node.rightscale.domain_name}"
end

if "#{node.rightscale.search_suffix}" != ""
  search = "search #{node.rightscale.search_suffix}"
end

template "/etc/resolv.conf" do
  source "resolv.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
    :nameserver => nameserver,
    :domain => domain,
    :search => search
  )
end

# Call hostname command.
log "  Setting hostname."
if platform?('centos', 'redhat', 'amazon')
  bash "set_hostname" do
    flags "-ex"
    code <<-EOH
      sed -i "s/HOSTNAME=.*/HOSTNAME=#{hostname}/" /etc/sysconfig/network
      hostname #{hostname}
    EOH
  end
else
  bash "set_hostname" do
    flags "-ex"
    code <<-EOH
      hostname #{hostname}
    EOH
  end
end

# Call domainname command.
if "#{node.rightscale.domain_name}" != ""
  log "  Running domainname"
  bash "set_domainname" do
    flags "-ex"
    code <<-EOH
      domainname #{node.rightscale.domain_name}
    EOH
  end
end

# Restart hostname services on appropriate platforms.
if platform?('ubuntu')
  log "  Starting hostname service."
  service "hostname" do
    service_name "hostname"
    supports :restart => true, :status => true, :reload => true
    action :restart
  end
end

# rightlink commandline tools set tag with rs_tag
log "  Setting hostname tag."
bash "set_node_hostname_tag" do
  flags "-ex"
  code <<-EOH
    type -P rs_tag &>/dev/null && rs_tag --add "node:hostname=#{hostname}"
  EOH
end

# Show the new host/node information.
ruby_block "show_new_host_info" do
  block do
    # Show new host values from system.
    Chef::Log.info("  == New host/node information ==")
    Chef::Log.info("  Hostname: #{`hostname` == '' ? '<none>' : `hostname`}")
    Chef::Log.info("  Network node hostname: #{`uname -n` == '' ? '<none>' : `uname -n`}")
    Chef::Log.info("  Alias names of host: #{`hostname -a` == '' ? '<none>' : `hostname -a`}")
    Chef::Log.info("  Short host name (cut from first dot of hostname): #{`hostname -s` == '' ? '<none>' : `hostname -s`}")
    Chef::Log.info("  Domain of hostname: #{`domainname` == '' ? '<none>' : `domainname`}")
    Chef::Log.info("  FQDN of host: #{`hostname -f` == '' ? '<none>' : `hostname -f`}")
  end
end
