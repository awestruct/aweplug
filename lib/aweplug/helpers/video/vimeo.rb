require 'oauth'
require 'aweplug/cache'
require 'aweplug/helpers/faraday'
require 'aweplug/helpers/video/vimeo_video'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/video/helpers'
require 'tilt'
require 'yaml'

module Aweplug
  module Helpers
    module Video
      class Vimeo
        include Aweplug::Helpers::Video::Helpers

        VIMEO_URL_PATTERN = /^https?:\/\/vimeo\.com\/(album)?\/?([0-9]+)\/?$/
        BASE_URL = 'https://api.vimeo.com/'

        def initialize site, logger: true, raise_error: false, adapter: nil, default_ttl: 86400 # day default seems good
          @site = site

          cache = Aweplug::Cache.default @site, default_ttl
          if (logger) 
            if (logger.is_a?(::Logger))
              @logger = logger
            else 
              @logger = ::Logger.new('_tmp/faraday.log', 'daily')
            end
          end

          @faraday = Aweplug::Helpers::FaradayHelper.default(BASE_URL, {:cache => cache, :logger => @logger})
          @faraday.authorization 'bearer', ENV['vimeo_access_token']
        end

        def add(url, product: nil, push_to_searchisko: true)
          if url =~ VIMEO_URL_PATTERN
            if $1 == 'album'
              path = "me/albums/#{$2}/videos"
              while !path.nil?
                resp = @faraday.get(path, {per_page: 50})
                path = nil
                if resp.success?
                  json = JSON.load(resp.body)
                  json['data'].collect do |v|
                    if v['metadata']['connections'].has_key? 'credits'
                      respc = @faraday.get(v['metadata']['connections']['credits'])
                      if respc.success?
                        data = JSON.load(respc.body)['data']
                        _add(data[0]['video'], data, product, push_to_searchisko)
                      else
                        puts "Error loading #{v['metadata']['connections']['credits']}"
                      end
                    else
                      _add(v['data'][0], nil, product, push_to_searchisko)
                    end
                  end
                  path = json['paging']['next']
                else
                  puts "Error loading #{path}"
                end
              end
            else
              uri = "videos/#{$2}/credits"
              resp = @faraday.get(uri)
              if resp.success?
                data = JSON.load(resp.body)['data']
                _add(data[0]['video'], data, product, push_to_searchisko)
              else
                puts "Error loading #{uri}"
              end
            end
          end
        end

        private
        
        def _add video, data, product, push_to_searchisko
          if @site.videos[video["link"]]
            video = @site.videos[video["link"]]
            video.add_target_product product
            video
          else
            add_video(Aweplug::Helpers::Video::VimeoVideo.new(video, data, @site), product, push_to_searchisko)
          end
        end

      end
    end
  end
end

