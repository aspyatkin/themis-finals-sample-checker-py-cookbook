id = 'themis-finals-sample-checker-py'

include_recipe 'themis-finals::prerequisite_git'
include_recipe 'themis-finals::prerequisite_python'
include_recipe 'themis-finals::prerequisite_supervisor'

directory node[id]['basedir'] do
  owner node[id]['user']
  group node[id]['group']
  mode 0755
  recursive true
  action :create
end

url_repository = "https://github.com/#{node[id]['github_repository']}"

if node.chef_environment.start_with? 'development'
  ssh_data_bag_item = nil
  begin
    ssh_data_bag_item = data_bag_item('ssh', node.chef_environment)
  rescue
  end

  ssh_key_map = (ssh_data_bag_item.nil?) ? {} : ssh_data_bag_item.to_hash.fetch('keys', {})

  if ssh_key_map.size > 0
    url_repository = "git@github.com:#{node[id]['github_repository']}.git"
  end
end

git2 node[id]['basedir'] do
  url url_repository
  branch node[id]['revision']
  user node[id]['user']
  group node[id]['group']
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
    git_config "git-config #{key} at #{node[id]['basedir']}" do
      key key
      value value
      scope 'local'
      path node[id]['basedir']
      user node[id]['user']
      action :set
    end
  end
end

virtualenv_path = ::File.join node[id]['basedir'], '.virtualenv'

python_virtualenv virtualenv_path do
  user node[id]['user']
  group node[id]['group']
  python '2'
  action :create
end

pip_requirements "#{node[id]['basedir']}/requirements.txt" do
  user node[id]['user']
  group node[id]['group']
  virtualenv virtualenv_path
  action :install
end

logs_basedir = ::File.join node[id]['basedir'], 'logs'

namespace = "#{node['themis-finals']['supervisor']['namespace']}.checker.#{node[id]['service_alias']}"

# sentry_data_bag_item = nil
# begin
#   sentry_data_bag_item = data_bag_item('sentry', node.chef_environment)
# rescue
# end

# sentry_dsn = (sentry_data_bag_item.nil?) ? {} : sentry_data_bag_item.to_hash.fetch('dsn', {})

checker_environment = {
  'PATH' => "#{::File.join virtualenv_path, 'bin'}:%(ENV_PATH)s",
  'APP_INSTANCE' => '%(process_num)s',
  'LOG_LEVEL' => node[id]['debug'] ? 'DEBUG' : 'INFO',
  'BEANSTALKD_URI' => "#{node['themis-finals']['beanstalkd']['host']}:#{node['themis-finals']['beanstalkd']['port']}",
  'TUBE_LISTEN' => "#{node['themis-finals']['beanstalkd']['tube_namespace']}.service.#{node[id]['service_alias']}.listen",
  'TUBE_REPORT' => "#{node['themis-finals']['beanstalkd']['tube_namespace']}.service.#{node[id]['service_alias']}.report"
}

# unless sentry_dsn.fetch(node[id]['service_alias'], nil).nil?
#   checker_environment['SENTRY_DSN'] = sentry_dsn.fetch(node[id]['service_alias'])
# end

supervisor_service "#{namespace}.server" do
  command "python checker.py"
  process_name 'checker-%(process_num)s'
  numprocs node[id]['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup false
  killasgroup false
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'checker-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'checker-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment checker_environment
  directory node[id]['basedir']
  serverurl 'AUTO'
  action :enable
end

supervisor_group namespace do
  programs [
    "#{namespace}.server"
  ]
  action :enable
end
