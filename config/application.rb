# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
require "graphql/client/http"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Libraries
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # config.autoload_paths << Rails.root.join('lib')

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # config.middleware.use Rack::Deflater

    # Initialize GraphQL client for Github API v4
    # Load schema from previous Github API schema dump
    Schema = Application.root.join("config/github_graphql_schema.json").to_s

    # Create new client from schema to parse queries with
    # Actual client for querying should come from AuthToken
    Client = GraphQL::Client.new(schema: Schema)
    Application.config.graphql = ActiveSupport::OrderedOptions.new
    Application.config.graphql.client = Client
    Application.config.graphql.schema = Schema

    config.active_job.queue_adapter = :sidekiq

    config.exceptions_app = routes

    Rails::Timeago.default_options limit: proc { 60.days.ago }, nojs: true, format: proc { |time, _options| time.strftime("%b %e, %Y") }

    # GC::Profiler.enable

    config.middleware.use Rack::Attack
    config.middleware.use Rack::Attack::RateLimit, throttle: ["api"]

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource(/^\/api\/.+/,
                 headers: :any,
                 methods: %i[get post patch put delete options head], expose: %w[total per-page],
                 max_age: 86400)
      end
    end

    # Env-based config
    config.github_public_key = ENV["GITHUB_PUBLIC_KEY"]
    config.github_public_secret = ENV["GITHUB_PUBLIC_SECRET"]
    config.github_private_key = ENV["GITHUB_PRIVATE_KEY"]
    config.github_private_secret = ENV["GITHUB_PRIVATE_SECRET"]
    config.github_key = ENV["GITHUB_KEY"]
    config.github_secret = ENV["GITHUB_SECRET"]
    config.bitbucket_key = ENV["BITBUCKET_KEY"]
    config.gitlab_key = ENV["GITLAB_KEY"]
    config.gitlab_application_id = ENV["GITLAB_APPLICATION_ID"]
    config.gitlab_secret = ENV["GITLAB_SECRET"]
    config.bugsnag_api_key = ENV["BUGSNAG_API_KEY"]
    config.bitbucket_application_id = ENV["BITBUCKET_APPLICATION_ID"]
    config.bitbucket_secret = ENV["BITBUCKET_SECRET"]
    config.ga_analytics_id = ENV["GA_ANALYTICS_ID"]
    config.gtm_id = ENV["GTM_ID"]
    config.tidelift_api_key = ENV["TIDELIFT_API_KEY"]
  end
end
