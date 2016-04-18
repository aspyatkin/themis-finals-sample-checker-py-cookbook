id = 'themis-finals-sample-checker-py'

include_recipe 'themis-finals::prerequisite_git'
include_recipe 'themis-finals::prerequisite_python'

directory node[id][:basedir] do
  owner node[id][:user]
  group node[id][:group]
  mode 0755
  recursive true
  action :create
end

url_repository = "https://github.com/#{node[id][:github_repository]}"

if node.chef_environment.start_with? 'development'
  ssh_data_bag_item = nil
  begin
    ssh_data_bag_item = data_bag_item('ssh', node.chef_environment)
  rescue
  end

  ssh_key_map = (ssh_data_bag_item.nil?) ? {} : ssh_data_bag_item.to_hash.fetch('keys', {})

  if ssh_key_map.size > 0
    url_repository = "git@github.com:#{node[id][:github_repository]}.git"
  end
end

git2 node[id][:basedir] do
  url url_repository
  branch node[id][:revision]
  user node[id][:user]
  group node[id][:group]
  action :create
end

if node.chef_environment.start_with? 'development'
  git_data_bag_item = nil
  begin
    git_data_bag_item = data_bag_item('git', node.chef_environment)
  rescue
  end

  git_options = (git_data_bag_item.nil?) ? {} : git_data_bag_item.to_hash.fetch('config', {})

  git_options.each do |key, value|
    git_config "git-config #{key} at #{node[id][:basedir]}" do
      key key
      value value
      scope 'local'
      path node[id][:basedir]
      user node[id][:user]
      action :set
    end
  end
end

virtualenv_path = ::File.join node[id][:basedir], '.virtualenv'

python_virtualenv virtualenv_path do
  owner node[id][:user]
  group node[id][:group]
  action :create
end

python_pip "#{node[id][:basedir]}/requirements.txt" do
  user node[id][:user]
  group node[id][:group]
  virtualenv virtualenv_path
  action :install
  options '-r'
end

god_basedir = ::File.join node['themis-finals'][:basedir], 'god.d'

template "#{god_basedir}/sample-checker-py.god" do
  source 'checker.god.erb'
  mode 0644
  variables(
    basedir: node[id][:basedir],
    user: node[id][:user],
    group: node[id][:group],
    service_alias: node[id][:service_alias],
    log_level: node[id][:debug] ? 'DEBUG' : 'INFO',
    beanstalkd_uri: "#{node['themis-finals'][:beanstalkd][:listen][:address]}:#{node['themis-finals'][:beanstalkd][:listen][:port]}",
    processes: node[id][:processes]
  )
  action :create
end
