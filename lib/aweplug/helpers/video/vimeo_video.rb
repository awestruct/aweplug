require 'aweplug/helpers/video/video_base'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/searchisko'
require 'duration'
require 'ostruct'

module Aweplug
  module Helpers
    module Video
      # Internal: Data object to hold and parse values from the Vimeo API.
      class VimeoVideo < ::Aweplug::Helpers::Video::VideoBase
        include Aweplug::Helpers::SearchiskoSocial

        attr_reader :duration

        def initialize video, site
          super video, site
          @duration = Duration.new(video['duration'])
        end

        def provider
          'vimeo'
        end

        def url
          @video['urls']['url'].first['_content']
        end

        def thumb_url
          if @video['thumbnails']
            @video["thumbnails"]["thumbnail"][1]["_content"]
          else
            ""
          end
        end

        def tags
          r = []
          if @video['tags'].is_a? Hash
            @video['tags']['tag'].inject([]) do |result, element|
              r << element['normalized']
            end
          end
          r
        end

        # Create the height and width methods
        [:height, :width].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || ''
          end
        end

        def cast
          unless @cast
            @cast = []
            excludes = contributor_exclude
            if @video['cast']['member'].is_a? Array
              @video['cast']['member'].each do |m|
                @cast << m unless excludes.include? m['username']
              end
            elsif !@video['cast']['member'].nil?
              @cast << @video['cast']['member'] unless excludes.include? @video['cast']['member']['username']
            end
          end
          @cast
        end

        def normalized_cast
          if @ncast.nil?
            @ncast = []
            unless cast.empty?
              cast.each do |c|
                @ncast << normalize('contributor_profile_by_vimeo_username', c['username'], @searchisko, c['display_name'])
              end 
            end
          end
          @ncast
        end

        def contributor_exclude
          super + ['jbossdeveloper']
        end

        def embed color, width, height
          %Q{<div widescreen vimeo><iframe src="//player.vimeo.com/video/#{id}?title=0&byline=0&portrait=0&badge=0&color=#{color}" width="#{width}" height="#{height}" frameborder="0" webkitallowfullscreen mozallowfullscreen allowfullscreen></iframe></div>}
        end

      end
    end
  end
end

