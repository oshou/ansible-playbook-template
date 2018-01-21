require 'spec_helper'

# Check hostname
describe command('hostname') do
  its(:stdout) { should match "#{property[:hostname]}" }
end
puts "-------------------------------------------"
puts "host_inventory: #{host_inventory['hostname']}"
puts "-------------------------------------------"
