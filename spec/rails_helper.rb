require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Rack::Attack is opt-in per example group (tag :rack_attack) so that
  # ordinary request specs never trip throttles.
  config.before(:each) { Rack::Attack.enabled = false }
  config.before(:each, :rack_attack) do
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end
  config.after(:each, :rack_attack) { Rack::Attack.enabled = false }

  config.before(:each) { ActionMailer::Base.deliveries.clear }
end
