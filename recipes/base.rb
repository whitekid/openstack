package 'ntp'

package 'ubuntu-cloud-keyring' do
	only_if { node[:lsb][:codename] == 'precise' }
end

apt_repository "openstack" do
	uri 'http://ubuntu-cloud.archive.canonical.com/ubuntu'
	distribution "#{node[:lsb][:codename]}/grizzly"
	components ['main']
	only_if { node[:lsb][:codename] == 'precise' }
end

apt_repository "openstack-updates" do
	uri 'http://ubuntu-cloud.archive.canonical.com/ubuntu'
	distribution "#{node[:lsb][:codename]}-updates/grizzly"
	components ['main']
	only_if { node[:lsb][:codename] == 'precise' }
end

# create openrc
keystone_node = search(:node, "roles:#{node[:openstack][:roles][:keystone]}")

template '/root/openrc' do
	source 'openrc.erb'
	variables({
		:keystone_node => keystone_node[0],
	})
	not_if { keystone_node.empty? }
end
