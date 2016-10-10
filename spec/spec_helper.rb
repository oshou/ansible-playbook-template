require 'serverspec'
require 'net/ssh'
require 'yaml'

properties = YAML.load_file('properties.yml')


set :backend, :ssh

if ENV['ASK_SUDO_PASSWORD']
  puts "ASK_SUDO_PASSWORD:" + ENV['ASK_SUDO_PASSWORD']
  begin
    require 'highline/import'
  rescue LoadError
    fail "highline is not available. Try installing it."
  end
  set :sudo_password, ask("Enter sudo password: ") { |q| q.echo = false }
else
  set :sudo_password, ENV['SUDO_PASSWORD']
  puts "SUDO_PASSWORD:" + ENV['SUDO_PASSWORD']
end

set_property properties[:hostname]
options = Net::SSH::Config.for(host)
options[:user] ||= Etc.getlogin
puts "options:user #{options[:user]}"

set :host,        options[:host_name] || host
set :ssh_options, options
set :request_pty, true

# Disable sudo
# set :disable_sudo, true


# Set environment variables
# set :env, :LANG => 'C', :LC_MESSAGES => 'C'

# Set PATH
set :path, '/sbin:/usr/local/sbin:$PATH'
