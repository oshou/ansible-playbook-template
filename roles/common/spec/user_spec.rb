require 'spec_helper'

# Check User exist
property[:user].each do |t|
  describe user(t) do
    it { should exist }
  end
end
