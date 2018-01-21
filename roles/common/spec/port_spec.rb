require 'spec_helper'

# Check port status OK
property[:port].each do |t|
  describe port(t) do
    it { should be_listening }
  end
end
