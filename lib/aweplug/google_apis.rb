require 'google/api_client'
require 'aweplug/cache'
require 'aweplug/helpers/faraday'

module Aweplug
  module GoogleAPIs

    # Helpers for working with Google APIs

    # Get the Google API Client
    def google_client site, logger: true, authenticate: true, readonly: true
      cache = Aweplug::Cache.default site
      if (logger) 
        if (logger.is_a?(::Logger))
          @logger = logger
        else 
          @logger = ::Logger.new('_tmp/faraday.log', 'daily')
        end
      end

      opts = { :application_name => site.application_name, :application_version => site.application_version }
      opts.merge!({:key => ENV['google_api_key']}) if authenticate && readonly
      opts.merge!({:authorization => nil})  if readonly

      # TODO Add write access
      client = Google::APIClient.new opts 
      faraday = Aweplug::Helpers::FaradayHelper.default({:logger => @logger, :cache => cache})
      faraday.ssl.ca_file = client.connection.ssl.ca_file

      client.connection = faraday
      client
    end

  end
end
