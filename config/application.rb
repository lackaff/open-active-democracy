# Put this in config/application.rb
require File.expand_path('../boot', __FILE__)

require 'rails/all'
require 'rack/openid'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require *Rails.groups(:assets => %w(development test))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end


module OpenActiveDemocracy
  class Application < Rails::Application
    
    require 'core_extensions'
    
    config.encoding = "utf-8"

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    # See Rails::Configuration for more options.
  
    # Skip frameworks you're not going to use (only works if using vendor/rails).
    # To use Rails without a database, you must remove the Active Record framework
    # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]
  
    # Only load the plugins named here, in the order given. By default, all plugins 
    # in vendor/plugins are loaded in alphabetical order.
    # :all can be used as a placeholder for all plugins not explicitly named
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]
  
    # Add additional load paths for your own custom dirs
    # config.load_paths += %W( #{RAILS_ROOT}/extras )
  
    # Force all environments to use the same logger level
    # (by default production uses :info, the others :debug)
    # config.log_level = :debug
  
    # Use the database for sessions instead of the cookie-based default,
    # which shouldn't be used to store highly confidential information
    # (create the session table with 'rake db:sessions:create')
    # config.action_controller.session_store = :active_record_store
  
    # Use SQL instead of Active Record's schema dumper when creating the test database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql
  
    # Activate observers that should always be running
    # config.active_record.observers = :user_observer
  
    # Make Active Record use UTC-base instead of local time
    # config.active_record.default_timezone = :utc

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    config.middleware.use 'Rack::OpenID'

    config.action_view.javascript_expansions[:defaults] = %w(jquery rails)  

    config.i18n.load_path += Dir[File.join(Rails.root.to_s, 'config', 'locales', '**', '*.{rb,yml}')] 
    config.i18n.default_locale = :en
    config.i18n.locale = :en
    
    config.filter_parameters = [:password, :password_confirmation]
 
    config.assets.initialize_on_precompile = false
   
    NB_CONFIG = { 'api_exclude_fields' => [:ip_address, :user_agent, :referrer, :google_token, :google_crawled_at, :activation_code, :salt, :email, :first_name, :last_name, :crypted_password, :is_tagger, :partner_id, :ip_address, :user_agent, :remember_token, :remember_token_expires_at, :referrer, :zip, :birth_date, :city, :state, :is_comments_subscribed, :is_finished_subscribed, :is_followers_subscribed, :is_mergeable, :is_messages_subscribed, :is_newsletter_subscribed, :is_point_changes_subscribed, :is_votes_subscribed, :is_subscribed, :contacts_count, :contacts_invited_count, :contacts_members_count, :contacts_not_invited_count, :code, :rss_code, :address] }
  end
  
  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      # Only works with DalliStore
      Rails.cache.reset if forked
    end
  end
  
  require 'diff'
  require 'open-uri'
  require 'validates_uri_existence_of'
  
  require 'timeout'
  require 'authenticated_system'
  
  require 'load_windows_contacts'
  require 'load_yahoo_contacts'
end
