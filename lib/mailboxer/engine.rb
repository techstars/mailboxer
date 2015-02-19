require 'carrierwave'
begin
  require 'sunspot_rails'
rescue LoadError
end

require 'mongoid'

module Mailboxer
  class Engine < Rails::Engine
  end
end
