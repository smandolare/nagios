class web-server {
	package { 'httpd': 
		name => 'httpd',
		ensure => present,
	}
	
	service { 'httpd':
		ensure => running,
		enable => true,
		require => Package['httpd'],
	}

	if defined(Class['nagios_agent']){
		nagios_service { 'nagios_service_httpd':
			ensure => present,
			check_command => check_http,
			use => 'generic-service',
			host_name => $hostname,
			service_description => "Web Server - httpd",
			target => "/etc/nagios/puppet/$hostname-services.cfg",
			require => Exec['init-git'],
		}
	}
}

class nagios_agent {
	nagios_host { "$hostname":
		ensure => present,
		address => $ipaddress,
		host_name => $hostname,
		use => 'generic-host',
		max_check_attempts => '3',
		target => "/etc/nagios/puppet/$hostname.cfg",
		require => Exec['init-git'],
	}

	file { "/etc/nagios":
		ensure => directory,
	}
	
	include git_client

	exec { "init-git":
		path => '/bin/',
		command => 'git clone https://git@github.com/smandolare/nagios.git /etc/nagios/puppet; cd /etc/nagios/puppet; git config user.email "puppet@local.local"',
		require => [File["/etc/nagios"],Package['git']],
		unless => "/bin/test -d /etc/nagios/puppet",
	}
}

stage { 'last': 
	require => Stage['main'],
}

class nagios_push {
	exec { "git-push":
		path => '/bin/',
		command => 'cd /etc/nagios/puppet; git pull; git add *; git commit -m "puppet auto-commit"; git push https://smandolare:Password01@github.com/smandolare/nagios.git',
	}
}

class { 'nagios_push':
	stage => 'last',
}

class git_client {
	package { 'git':
		ensure => present,
	}
}

node puppet-slave-m {
	include nagios_agent
	include web-server
	include nagios_push
	include nagios-server
	
}

class nagios-server {
	package { 'nagios':
		name => 'nagios',
		ensure => present,
	}
	package { 'nagios-plugins':
		name => 'nagios-plugins-all',
		ensure => present,
	}
	
	service { 'nagios':
		ensure => running,
		enable => true,
		require => Package['nagios'],
		subscribe => File["/etc/nagios/puppet"],
	}

	file { "/etc/nagios/puppet": }

	exec { 'nag-passwd':
		path => '/bin',
		command => "htpasswd -c -b /etc/nagios/passwd nagiosadmin admin",
		require => Package['nagios'],
	}

}

node puppet-slave {
	include nagios_agent
	include web-server
}
