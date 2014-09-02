require 'oauth'
require 'aweplug/cache/file_cache'
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

        def initialize site
          @site = site
          site.send("vimeo_cache=", {}) if site.vimeo_cache.nil?
          site.send('cache=', Aweplug::Cache::FileCache.new) if site.cache.nil?
        end

        def add(url, product: nil, push_to_searchisko: true)
          if url =~ VIMEO_URL_PATTERN
            if $1 == 'album'
              videos = []
              albumJson = JSON.load(exec_method('vimeo.albums.getVideos', {album_id: $2, per_page: 50, full_response: 1, format: 'json'}))
              albumJson['videos']['video'].each do |v|
                videos << add_video(v['id'], product, push_to_searchisko)
              end
              videos
            else
              add_video($2, product, push_to_searchisko)
            end
          end
        end

        private

        def add_video (id, product, push_to_searchisko)
          if @site.vimeo_cache.has_key? id
            @site.vimeo_cache[id]
          else
            page_path = Pathname.new(File.join 'video', 'vimeo', "#{id}.html")

            videoJson = JSON.load(exec_method "vimeo.videos.getInfo", {format: 'json', video_id: id})['video'].first
            video = Aweplug::Helpers::Video::VimeoVideo.new videoJson, @site
            add_video_to_site video, @site

            send_video_to_searchisko video, @site, product, push_to_searchisko
            @site.vimeo_cache[id] = video
            video
          end
        end

        # Internal: Execute a method against the Vimeo API
        #
        # method   - the API method to execute
        # options  - Hash of the options (names and values) to send to Vimeo
        #
        # Returns JSON retreived from the Vimeo API
        def exec_method(method, options)
          if access_token
            query = "http://vimeo.com/api/rest/v2?method=#{method}&" 
            query += options.inject([]) {|a, (k,v)| a << "#{k}=#{v}"; a}.join("&")
            access_token.get(query).body
          end
        end

        # Internal: Obtains an OAuth::AcccessToken for the Vimeo API, using the 
        # vimeo_client_id and vimeo_access_token defined in site/config.yml and
        # vimeo_client_secret and vimeo_access_token_secret defined in environment
        # variables
        #
        # site - Awestruct Site instance
        # 
        # Returns an OAuth::AccessToken for the Vimeo API 
        def access_token
          if @access_token
            @access_token
          else
            if not ENV['vimeo_client_secret']
              puts 'Cannot fetch video info from vimeo, vimeo_client_secret is missing from environment variables'
              return
            end
            if not @site.vimeo_client_id
              puts 'Cannot fetch video info vimeo, vimeo_client_id is missing from _config/site.yml'
              return
            end
            if not ENV['vimeo_access_token_secret']
              puts 'Cannot fetch video info from vimeo, vimeo_access_token_secret is missing from environment variables'
              return
            end
            if not @site.vimeo_access_token
              puts 'Cannot fetch video info from vimeo, vimeo_access_token is missing from _config/site.yml'
              return
            end
            consumer = OAuth::Consumer.new(@site.vimeo_client_id, ENV['vimeo_client_secret'],
                                          { :site => "https://vimeo.com",
                                            :scheme => :header
            })
            # now create the access token object from passed values
            token_hash = { :oauth_token => @site.vimeo_access_token,
                          :oauth_token_secret => ENV['vimeo_access_token_secret']
            }
            OAuth::AccessToken.from_hash(consumer, token_hash )
          end
        end
      end
    end
  end
end

