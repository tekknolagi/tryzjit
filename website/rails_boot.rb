# frozen_string_literal: true

# Loaded with `-r` before the snippet on the /rails page. Boots a minimal
# single-file Rails application (in the style of Rails' bug report templates)
# against an in-memory SQLite database, then turns ZJIT on so that only code
# run by the snippet gets compiled, not Rails' own boot.

require 'bundler/setup'
require 'logger'
require 'rails'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'

ENV['DATABASE_URL'] = 'sqlite3::memory:'

class TryZJITApplication < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.root = '/tmp/tryzjit-app'
  config.eager_load = true
  config.logger = Logger.new(nil)
  config.secret_key_base = 'tryzjit'
  config.hosts.clear
  config.active_job.queue_adapter = :inline
  config.action_mailer.delivery_method = :test
end

FileUtils.mkdir_p(Rails.application.config.root)
Rails.application.initialize!
ActiveRecord::Migration.verbose = false

RubyVM::ZJIT.enable
