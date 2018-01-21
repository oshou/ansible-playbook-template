require 'spec_helper'


# Check selinux disable
describe selinux do
  it { should be_disabled }
end
