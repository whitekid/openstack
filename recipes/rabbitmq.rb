node.set_unless[:openstack][:rabbitmq][:password] = secure_password

execute 'change rabbitmq password' do
	command "rabbitmqctl change_password guest #{node[:openstack][:rabbitmq][:password]}"
end
