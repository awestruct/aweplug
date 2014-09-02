require 'aweplug/cache/file_cache'

module Aweplug
  module Helpers
    module Video
      class VideoBase

        def initialize(video, site)
          @site = site
          site.send('cache=', Aweplug::Cache::FileCache.new) if site.cache.nil?
          @video = video
          @searchisko = Aweplug::Helpers::Searchisko.new({:base_url => @site.dcp_base_url, 
                                                          :authenticate => true, 
                                                          :searchisko_username => ENV['dcp_user'], 
                                                          :searchisko_password => ENV['dcp_password'], 
                                                          :cache => @site.cache,
                                                          :logger => @site.log_faraday,
                                                          :searchisko_warnings => @site.searchisko_warnings})
        end

        # Create the basic methods
        [:id, :title, :tags].each do |attr|
          define_method attr.to_s do
            @video[attr.to_s] || ''
          end
        end

        # Create date methods
        [:modified_date, :upload_date].each do |attr|
          define_method attr.to_s do
            pretty_date(@video[attr.to_s])
          end

          define_method "#{attr.to_s}_iso8601" do
            DateTime.parse(@video[attr.to_s]).iso8601
          end
        end

        # Create the unimplemented methods
        [:cast, :duration, :height, :width, :normalized_cast].each do |attr|
          define_method attr.to_s do
            nil
          end
        end
        
        def description
          d = @video["description"]
          out = ""
          if d
            i = 0
            max_length = 150
            d.scan(/[^\.!?]+[\.!?]/).map(&:strip).each do |s|
              i += s.length
              if i > max_length
                break
              else
                out += s
              end
            end
            # Deal with the case that the description has no sentence end in it
            out = out.empty? ? d : out
          end
          out
        end

        def detail_url
          "#{@site.base_url}/video/#{provider}/#{id}"
        end

        def normalized_author
          normalized_cast[0]
        end

        def searchisko_payload
          author = cast[0]
          {
            :sys_title => title,
            :sys_description => description,
            :sys_url_view => "#{@site.base_url}/video/vimeo/#{id}",
            :author => author.nil? ? nil : author['username'],
            :contributors => cast.empty? ? nil : cast.collect {|c| c['username']},
            :sys_created => upload_date_iso8601,
            :sys_last_activity_date => modified_date_iso8601,
            :duration => duration.to_i,
            :thumbnail => thumb_url,
            :tags => tags
          }.reject{ |k,v| v.nil? }
        end

        def contributor_exclude
          contributor_exclude = Pathname.new(@site.dir).join("_config").join("searchisko_contributor_exclude.yml")
          if contributor_exclude.exist?
            yaml = YAML.load_file(contributor_exclude)
            return yaml['vimeo'] unless yaml['vimeo'].nil?
          end
          {}
        end

        def pretty_date(date_str)
          date = DateTime.parse(date_str)
          a = (Time.now-date.to_time).to_i

          case a
          when 0 then 'just now'
          when 1 then 'a second ago'
          when 2..59 then a.to_s+' seconds ago' 
          when 60..119 then 'a minute ago' #120 = 2 minutes
          when 120..3540 then (a/60).to_i.to_s+' minutes ago'
          when 3541..7100 then 'an hour ago' # 3600 = 1 hour
          when 7101..82800 then ((a+99)/3600).to_i.to_s+' hours ago' 
          when 82801..172000 then 'a day ago' # 86400 = 1 day
          when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+' days ago'
          when 518400..1036800 then 'a week ago'
          when 1036800..4147200 then ((a+180000)/(60*60*24*7)).to_i.to_s+' weeks ago'
          else date.strftime("%F")
          end
        end

      end
    end
  end
end

