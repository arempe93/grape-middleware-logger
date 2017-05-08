require 'logger'
require 'grape'

class Grape::Middleware::Logger < Grape::Middleware::Globals
  BACKSLASH = '/'.freeze
  DEFAULT_FILTER = Class.new { def filter(h); h; end }.freeze

  attr_reader :logger

  class << self
    attr_accessor :logger, :filter, :headers

    def default_logger
      default = Logger.new(STDOUT)
      default.formatter = ->(*args) { args.last.to_s << "\n".freeze }
      default
    end
  end

  ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    append_db_runtime(event)
  end if defined?(ActiveRecord)

  def initialize(_, options = {})
    super
    @options[:filter] ||= self.class.filter || DEFAULT_FILTER
    @options[:headers] ||= self.class.headers
    @logger = options[:logger] || self.class.logger || self.class.default_logger
  end

  def call!(env)
    @env = env

    before
    
    grape_error = catch(:error) { @app_response = @app.call(@env) }

    if grape_error
      after_failure(status: error[:status], response: error[:message])
      throw(:error, error)
    end

    @app_response.tap { |(status, _, _)| after(status) }
  end

  def before
    start_timings

    super
    logger.info ''
    logger.info format("Started %<method>s '%<path>s' at %<time>s", method: env[Grape::Env::GRAPE_REQUEST].request_method,
                                                                    path: env[Grape::Env::GRAPE_REQUEST].path,
                                                                    time: @runtime_start.to_s)
    logger.info "Processing by #{processed_by}"
    logger.info "  Parameters: #{parameters}"
    logger.info "  Headers: #{headers}" if @options[:headers]
  end

  def after(status)
    logger.info "Completed #{status}: total=#{total_runtime}ms - db=#{@db_runtime}ms"
    logger.info ''
  end

  private

  def after_failure(status:, response:)
    logger.info "  Failing with #{status} (#{response.fetch(:message, '<NO MESSAGE>')})" 
    after(status)
  end

  def parameters
    request_params = env[Grape::Env::GRAPE_REQUEST_PARAMS].to_hash
    request_params.merge! env[Grape::Env::RACK_REQUEST_FORM_HASH] if env[Grape::Env::RACK_REQUEST_FORM_HASH]
    request_params.merge! env['action_dispatch.request.request_parameters'] if env['action_dispatch.request.request_parameters']
    
    @options[:filter].filter(request_params)
  end

  def headers
    request_headers = env[Grape::Env::GRAPE_REQUEST_HEADERS].to_hash
    return Hash[request_headers.sort] if @options[:headers] == :all

    Array(@options[:headers]).each_with_object({}) do |name, acc|
      acc.merge!(request_headers.select { |key, value| name.to_s.casecmp(key).zero? })
    end
  end

  def start_timings
    @runtime_start = Time.now
    @db_runtime = 0
  end

  def append_db_runtime(event)
    @db_runtime += event.duration
  end

  def total_runtime
    ((Time.now - start_time) * 1_000).round(2)
  end

  def total_db_runtime
    @db_runtime.round(2)
  end

  def processed_by
    endpoint = env[Grape::Env::API_ENDPOINT]
    
    result = []
    result << (endpoint.namespace == BACKSLASH ? '' : endpoint.namespace)

    result.concat(endpoint.options[:path].map { |path| path.to_s.sub(BACKSLASH, '') })
    endpoint.options[:for].to_s << result.join(BACKSLASH)
  end
end

require_relative 'logger/railtie' if defined?(Rails)
