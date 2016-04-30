id = 'themis-finals-sample-checker-py'

default[id][:basedir] = '/var/themis/finals/checkers/sample-checker-py'
default[id][:github_repository] = 'aspyatkin/themis-finals-sample-checker-py'
default[id][:revision] = 'develop'
default[id][:user] = 'vagrant'
default[id][:group] = 'vagrant'

default[id][:debug] = true
default[id][:service_alias] = 'service_2'
default[id][:processes] = 2
