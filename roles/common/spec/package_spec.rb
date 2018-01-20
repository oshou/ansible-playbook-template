require 'spec_helper'

# Check install EPEL
describe yumrepo('epel') do
  it { should exist}
  it { should be_enabled}
end

# Check install package
property[:package].each do |t|
  describe package(t) do
    it {should be_installed}
  end
end
