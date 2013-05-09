::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

connection_info = {
	:host => 'localhost',
	:username => 'root',
	:password => node[:mysql][:server_root_password],
}

node['mysql']['client']['packages'].each do |pkg|
	package pkg do
		action :nothing
	end.run_action(:upgrade)
end

chef_gem 'mysql'

%w{keystone glance quantum nova cinder}.each do |db|
	mysql_database db do
		connection connection_info
		action :create
	end

	node.set_unless[:openstack][:mysql]["#{db}_password"] = secure_password

	mysql_database_user db do
		connection connection_info
		password node[:openstack][:mysql]["#{db}_password"]
		database_name db
		host '%'
		privileges [:all]
		action [:create, :grant]
	end
end
