require 'aweplug/helpers/video/video_base'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/searchisko'
require 'ostruct'
require 'duration'

module Aweplug
  module Helpers
    module Video
      # Internal: Data object to hold and parse values from the Vimeo API.
      class YouTubeVideo < ::Aweplug::Helpers::Video::VideoBase
        include Aweplug::Helpers::SearchiskoSocial

        def initialize video, site
          super video['snippet'], site
          @id = video['id']
          @url = "http://www.youtube.com/v=#{@id}"
          @duration = Duration.new(video['contentDetails']['duration'])
          @thumb_url = @video["thumbnails"]["medium"]["url"]
          @height
        end

        attr_reader :url, :id, :duration, :thumb_url

        def provider
          'youtube'
        end

        # Create date methods
        [:modified_date, :upload_date].each do |attr|
          define_method attr.to_s do
            pretty_date(@video['publishedAt'].to_s)
          end

          define_method "#{attr.to_s}_iso8601" do
            DateTime.parse(@video['publishedAt']).iso8601
          end
        end

        def cast
          unless @cast
            @cast = []
            excludes = 
            unless contributor_exclude.include? @video['channelTitle']
              @cast << @video['channelTitle']
            end
          end
          @cast
        end

        def normalized_cast
          if @ncast.nil?
            @ncast = []
            unless cast.empty?
              cast.each do |c|
                # TODO Should be name
                @ncast << normalize('contributor_profile_by_jbossdeveloper_quickstart_author', c, @searchisko)
              end 
            end
          end
          @ncast
        end

        def contributor_exclude
          super + ['JBoss Developer']
        end

        def embed color, width, height
          %Q{<iframe id="ytplayer" type="text/html" width="#{width}" height="#{height}" src="//www.youtube.com/embed/#{id}?&origin=#{@site.base_url}&color=#{color}&modestbranding=1" frameborder="0"></iframe>}
        end

      end
    end
  end
end

