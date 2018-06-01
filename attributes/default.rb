id = 'themis-finals-python-service-checker'

default[id]['fqdn'] = nil

default[id]['root'] = '/var/themis/finals/checker'
default[id]['github_repository'] = 'themis-project/themis-finals-python-service-checker'
default[id]['revision'] = 'master'

default[id]['python'] = '2'

default[id]['debug'] = false
default[id]['service_alias'] = 'python'

default[id]['server']['processes'] = 2
default[id]['server']['port_range_start'] = 10_100

default[id]['queue']['processes'] = 2
default[id]['queue']['redis_db'] = nil

default[id]['source_packages'] = false
default[id]['autostart'] = false

default[id]['push_run_timeout'] = 60
default[id]['push_queue_ttl'] = 60
default[id]['pull_run_timeout'] = 30
default[id]['pull_queue_ttl'] = 30
default[id]['result_ttl'] = 300
