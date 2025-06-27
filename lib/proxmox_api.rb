# frozen_string_literal: true

require 'faraday'
require 'json'

# This class is wrapper for Proxmox PVE APIv2.
# See README for usage examples.
#
# @author Eugene Lapeko
class ProxmoxAPI
  AUTH_PARAMS = %i[username realm password otp].freeze
  RESOURCE_OPTIONS = %i[headers].freeze
  REST_METHODS = %i[get post put delete].freeze

  # This class is used to collect api path before request
  class ApiPath
    # @param [ProxmoxAPI] api ProxmoxAPI object to call when request is executed
    def initialize(api)
      raise ArgumentError, 'Not an instance of ProxmoxAPI' unless api.is_a? ProxmoxAPI

      @api = api
      @path = []
    end

    def to_s
      @path.join('/')
    end

    def to_a
      @path.dup
    end

    def [](index)
      @path << index.to_s
      self
    end

    def method_missing(method, *args)
      return @api.__send__(:submit, method, to_s, *args) if REST_METHODS.any? { |rm| /^#{rm}!?$/.match? method }

      @path << method.to_s
      self
    end

    def respond_to_missing?(*)
      true
    end
  end

  # This exception is raised when Proxmox API returns error code
  #
  # @!attribute [r] response
  #   @return [Faraday::Response] answer from Proxmox server
  class ApiException < RuntimeError
    attr_reader :response

    def initialize(response, description)
      @response = response
      super(description)
    end
  end

  # Constructor method for ProxmoxAPI
  #
  # @param [String] cluster hostname/ip of cluster to control
  # @param [Hash] options cluster connection parameters
  #
  # @option options [String] :username - username to be used for connection
  # @option options [String] :password - password to be used for connection
  # @option options [String] :realm - auth realm, can be given in :username ('user@realm')
  # @option options [String] :token - token to be used instead of username, password, and realm
  # @option options [String] :secret - secret to be used with token
  # @option options [String] :otp - one-time password for two-factor auth
  #
  # @option options [Boolean] :verify_ssl - verify server certificate
  #
  # You can also pass here all ssl options supported by faraday gem
  # @see https://github.com/lostisland/faraday
  def initialize(cluster, options)
    if use_pve_api_token_auth?(options)
      options[:headers] = { Authorization: "PVEAPIToken=#{options[:token]}=#{options[:secret]}" }
    end
    @base_url = build_base_url(cluster, options)
    @connection = build_faraday_connection(@base_url, options)
    @auth_ticket = build_auth_ticket(options)
  end

  def [](index)
    ApiPath.new(self)[index]
  end

  def method_missing(method, *args)
    ApiPath.new(self).__send__(method, *args)
  end

  def respond_to_missing?(*)
    true
  end

  # The list of options to be passed to Faraday object
  def self.connection_options
    %w[verify_ssl] + RESOURCE_OPTIONS.map(&:to_s)
  end

  private

  def build_auth_ticket(options)
    options.key?(:token) ? {} : create_auth_ticket(options.slice(*auth_params))
  end

  def build_base_url(cluster, options)
    "https://#{cluster}:#{options[:port] || 8006}/api2/json/"
  end

  def use_pve_api_token_auth?(options)
    options.key?(:token) && options.key?(:secret)
  end

  def build_faraday_connection(base_url, options)
    Faraday.new(url: base_url) do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.ssl.verify = options[:verify_ssl] if options.key?(:verify_ssl)
      options[:headers].each { |k, v| faraday.headers[k] = v } if options.key?(:headers)
    end
  end

  def raise_on_failure(response, message = 'Proxmox API request failed')
    return unless response.status >= 400

    raise ApiException.new(response, message)
  end

  def create_auth_ticket(options)
    response = @connection.post('access/ticket', options)
    raise_on_failure(response, 'Proxmox authentication failure')
    data = JSON.parse(response.body, symbolize_names: true)[:data]
    {
      cookies: { PVEAuthCookie: data[:ticket] },
      CSRFPreventionToken: data[:CSRFPreventionToken]
    }
  end

  def prepare_request(method, data)
    headers = {}
    params = {}
    body = nil
    headers['Cookie'] = @auth_ticket[:cookies].map { |k, v| "#{k}=#{v}" }.join('; ') if @auth_ticket[:cookies]
    headers['CSRFPreventionToken'] = @auth_ticket[:CSRFPreventionToken] if @auth_ticket[:CSRFPreventionToken]
    case method
    when :post, :put
      body = data
    when :get
      params = data
    end
    { headers: headers, params: params, body: body }
  end

  def submit(method, url, data = {})
    method, skip_raise = normalize_method(method)
    request_options = prepare_request(method, data)
    response = perform_request(method, url, request_options)
    raise_on_failure(response) unless skip_raise
    parse_response(response)
  end

  def normalize_method(method)
    if /!$/.match? method
      [method.to_s.tr('!', '').to_sym, true]
    else
      [method, false]
    end
  end

  def perform_request(method, url, request_options)
    @connection.public_send(method, url, request_options[:body]) do |req|
      req.headers.update(request_options[:headers])
      req.params.update(request_options[:params]) if method == :get
    end
  end

  def parse_response(response)
    JSON.parse(response.body, symbolize_names: true)[:data]
  end
end
