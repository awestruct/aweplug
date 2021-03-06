require 'aweplug/cache'

module Aweplug
  module Helpers
    module Video
      class VideoBase

        def initialize(video, site, default_ttl = 86400) # A day seems good for videos
          @site = site
          @video = video
          @searchisko = Aweplug::Helpers::Searchisko.default site, default_ttl
        end

        # Create the basic methods
        [:title, :tags].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || ''
          end
        end

        # Create the unimplemented methods
        [:cast, :duration, :modified_date, :published_date, :normalized_cast].each do |attr|
          define_method attr.to_s do
            nil
          end
        end

        # Create the height and width methods
        [:height, :width].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || nil
          end
        end

        def description
          d = @video["description"]
          out = ""
          max_length = 150
          if d
            i = 0
            d.scan(/[^\.!?]+[\.!?]\s/).map(&:strip).each do |s|
              i += s.length
              out += s

              if i > max_length
                break
              end
            end
            # Deal with the case that the description has no sentence end in it
            out = (out.empty? || out.length < 60) ? d : out
          end
          out = out.gsub("\n", ' ')[0..max_length]
          out
        end

        def full_description
          @video["description"]
        end

        def detail_url
          "#{@site.base_url}/video/#{provider}/#{id}"
        end

        def normalized_author
          normalized_cast[0]
        end

        def author
          cast[0]
        end

        def searchisko_payload
          {
            :sys_title => title,
            :sys_description => description,
            :full_description => full_description,
            :sys_url_view => detail_url,
            :author => author.nil? ? nil : author['username'],
            :contributors => cast.empty? ? nil : cast.collect {|c| c['username']},
            :sys_created => published_date.iso8601,
            :sys_last_activity_date => modified_date.iso8601,
            :duration => duration.to_i,
            :thumbnail => thumb_url,
            :target_product => target_product.flatten.compact.uniq,
            :tags => tags,
            :view_count => view_count,
            :like_count => like_count
          }.reject{ |k,v| v.nil? }
        end

        def contributor_exclude
          contributor_exclude = Pathname.new(@site.dir).join("_config").join("searchisko_contributor_exclude.yml")
          if contributor_exclude.exist?
            yaml = YAML.load_file(contributor_exclude)
            return yaml[provider] unless yaml[provider].nil?
          end
          {}
        end

        def to_h
          hash = {}
          [:title, :tags, :cast, :duration, :modified_date, :published_date, :normalized_cast,
           :height, :width, :description, :author, :detail_url, :normalized_author, :full_description
          ].each {|k| hash[k] = self.send k}
          hash
        end

      end
    end
  end
end

