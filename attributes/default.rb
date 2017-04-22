id = 'themis-finals-service2-checker'

default[id]['basedir'] = '/var/themis/finals/checker/service2'
default[id]['github_repository'] = 'themis-project/themis-finals-service2-checker'
default[id]['revision'] = 'master'
default[id]['user'] = 'vagrant'
default[id]['group'] = 'vagrant'

default[id]['debug'] = false
default[id]['service_alias'] = 'service2'

default[id]['server']['processes'] = 2
default[id]['server']['port_range_start'] = 10_100

default[id]['queue']['processes'] = 2
default[id]['queue']['redis_db'] = 11

default[id]['source_packages'] = false
default[id]['autostart'] = false
