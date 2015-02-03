require 'logger'
require 'faraday'
require 'faraday_middleware'

module Aweplug
  module Helpers
    # Helper for faraday actions
    class FaradayHelper
      # Public: Returns a basic Faraday connection using options passed in
      #
      # url:  URL (String or URI) for the base of the full URL.
      # opts: Hash of options to use.
      #       :logger - Logger to use, if none is provided a default is used.
      #       :cache - Optional cache to use.
      #       :no_cache - Boolean indicating not to use a cache.
      #       :adapter - Faraday Adapter to use, :net_http by default.
      #
      # Returns a configured Faraday connection.
      def self.default url = nil, opts = {} 
        logger = opts[:logger] || Logger.new('_tmp/faraday.log', 'daily')

        conn = Faraday.new do |builder|
          builder.response :logger, @logger = logger
          unless opts[:no_cache]
            builder.use FaradayMiddleware::Caching, (opts[:cache] || Aweplug::Cache::FileCache.new), {} 
          end
          builder.request :retry
          builder.request :url_encoded
          builder.request :retry
          builder.response :raise_error
          builder.response :gzip
          builder.options.params_encoder = Faraday::FlatParamsEncoder
          builder.use FaradayMiddleware::FollowRedirects, limit: 3
          builder.ssl.verify = true
          builder.adapter (opts[:adapter] ||:net_http)
        end 
        conn.url_prefix = url if (url.is_a?(String) || url.is_a?(URI))
        conn
      end
    end
  end
end
