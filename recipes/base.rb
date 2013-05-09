::Chef::Recipe.send(:include, Kakao::Openstack)

package 'ntp'

package 'ubuntu-cloud-keyring' do
	only_if { node[:lsb][:codename] == 'precise' }
end

apt_repository "openstack-updates" do
	uri node[:openstack][:cloud_archive_url]
	distribution "#{node[:lsb][:codename]}-updates/grizzly"
	components ['main']
	only_if { node[:lsb][:codename] == 'precise' }
end

# create openrc
keystone_node = node_by_role node[:openstack][:roles][:keystone]

if not keystone_node.nil? and not keystone_node[:keystone].nil?
	template '/root/openrc' do
		source 'openrc.erb'
		variables({
			:keystone_node => keystone_node,
		})
		only_if { not keystone_node.empty? and not keystone_node[:keystone][:admin_passwd].nil? }
	end
end

directory '/root/stack'
cookbook_file "/root/stack/clear.sh" do
	source "clear.sh"
	owner "root"
	group "root"
	mode 00755
end
