require 'spec_helper'

# Check Timezone
describe command('strings /etc/localtime') do
  its(:stdout) { should match '/JST-9/'}
end
describe file('/etc/sysconfig/clock') do
  its(:command) { should match(/ZONE=\"Asia\/Tokyo\"/) }
end
