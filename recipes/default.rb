id = 'themis-finals-sample-checker-py'

include_recipe 'modern_nginx::default'
include_recipe 'latest-redis::default'
include_recipe 'supervisor::default'

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
    ssh_known_hosts_entry 'github.com'
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

virtualenv_path = ::File.join node[id]['basedir'], '.venv'

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
  'HOST' => '127.0.0.1',
  'PORT' => node[id]['server']['port_range_start'],
  'INSTANCE' => '%(process_num)s',
  'LOG_LEVEL' => node[id]['debug'] ? 'DEBUG' : 'INFO',
  'STDOUT_SYNC' => node[id]['debug'],
  'REDIS_HOST' => node['latest-redis']['listen']['host'],
  'REDIS_PORT' => node['latest-redis']['listen']['port'],
  'REDIS_DB' => node[id]['queue']['redis_db'],
  'THEMIS_FINALS_KEY_NONCE_SIZE' => node['themis-finals']['key_nonce_size'],
  'THEMIS_FINALS_AUTH_TOKEN_HEADER' => node['themis-finals']['auth_token_header']
}

# unless sentry_dsn.fetch(node[id]['service_alias'], nil).nil?
#   checker_environment['SENTRY_DSN'] = sentry_dsn.fetch(node[id]['service_alias'])
# end

supervisor_service "#{namespace}.server" do
  command 'sh script/server'
  process_name 'server-%(process_num)s'
  numprocs node[id]['server']['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup true
  killasgroup true
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'server-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'server-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment checker_environment.merge(
    'THEMIS_FINALS_MASTER_KEY' => data_bag_item('themis-finals', node.chef_environment)['keys']['master']
  )
  directory node[id]['basedir']
  serverurl 'AUTO'
  action :enable
end

supervisor_service "#{namespace}.queue" do
  command 'sh script/queue'
  process_name 'queue-%(process_num)s'
  numprocs node[id]['queue']['processes']
  numprocs_start 0
  priority 300
  autostart false
  autorestart true
  startsecs 1
  startretries 3
  exitcodes [0, 2]
  stopsignal :INT
  stopwaitsecs 10
  stopasgroup true
  killasgroup true
  user node[id]['user']
  redirect_stderr false
  stdout_logfile ::File.join logs_basedir, 'queue-%(process_num)s-stdout.log'
  stdout_logfile_maxbytes '10MB'
  stdout_logfile_backups 10
  stdout_capture_maxbytes '0'
  stdout_events_enabled false
  stderr_logfile ::File.join logs_basedir, 'queue-%(process_num)s-stderr.log'
  stderr_logfile_maxbytes '10MB'
  stderr_logfile_backups 10
  stderr_capture_maxbytes '0'
  stderr_events_enabled false
  environment checker_environment.merge(
    'THEMIS_FINALS_CHECKER_KEY' => data_bag_item('themis-finals', node.chef_environment)['keys']['checker']
  )
  directory node[id]['basedir']
  serverurl 'AUTO'
  action :enable
end

supervisor_group namespace do
  programs [
    "#{namespace}.server",
    "#{namespace}.queue"
  ]
  action :enable
end

template "#{node['nginx']['dir']}/sites-available/themis-finals-checker-#{node[id]['service_alias']}.conf" do
  source 'nginx.conf.erb'
  mode 0644
  variables(
    server_name: node[id]['fqdn'],
    service_name: node[id]['service_alias'],
    logs_basedir: logs_basedir,
    server_processes: node[id]['server']['processes'],
    server_port_start: node[id]['server']['port_range_start']
  )
  notifies :reload, 'service[nginx]', :delayed
  action :create
end

nginx_site "themis-finals-checker-#{node[id]['service_alias']}.conf"
