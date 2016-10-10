require 'spec_helper'

# Check service enabled & now running
property[:service_enabled].each do |t|
  describe service(t) do
    it { should be_enabled }
    it { should be_running }
  end
end

# Check service disabled & now stopping
property[:service_disabled].each do |t|
  describe service(t) do
    it { should_not be_enabled }
    it { should_not be_running }
  end
end

