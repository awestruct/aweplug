require 'pathname'
require 'asciidoctor'
require 'aweplug/helpers/git_metadata'
require 'aweplug/helpers/searchisko'
require 'aweplug/helpers/searchisko_social'
require 'aweplug/helpers/cdn'
require 'aweplug/cache'
require 'json'

module Aweplug
  module Extensions
    # Public: An awestruct extension for guides / examples written in AsciiDoc.
    #         Files with the .asciidoc or .adoc extension are considered to be
    #         AsciiDoc files. This extension makes use of asciidoctor to 
    #         render the files.
    #
    # Example
    #
    #   extension Aweplug::Extensions::AsciidocExample({...})
    class AsciidocExample 
      include Aweplug::Helper::Git::Commit::Metadata
      include Aweplug::Helper::Git::Repository
      include Aweplug::Helpers::SearchiskoSocial
  

      # Public: Initialization method, used in the awestruct pipeline. This
      #         makes use of the Aweplug::Helper::Searchisko class, please see 
      #         that class for more info on options and settings for Searchisko.
      #
      # opts - A Hash of options, some being required, some not (default: {}). 
      #        :repository               - The String name of the directory 
      #                                    containing the repository (required).
      #        :directory                - The String directory name, within the
      #                                    :respository, containing the files 
      #                                    (required).
      #        :layout                   - The String name of the layout to use, 
      #                                    omitting the extension (required).
      #        :output_dir               - The String or Pathname of the output 
      #                                    directory for the files (required).
      #        :additional_excludes      - An Array of Strings containing 
      #                                    additional base file names to exclude 
      #                                    (default: []).
      #        :recurse_subdirectories   - Boolean flag indicating to continue 
      #                                    searching subdirectories (default: 
      #                                    true).
      #        :additional_metadata_keys - An Array of String keys from the 
      #                                    AsciiDoc metadata to include in the 
      #                                    searchisko payload (default: []).
      #        :site_variable            - String name of the key within the site
      #                                    containing additional metadata about 
      #                                    the guide (default: value of 
      #                                    :output_dir).
      #        :push_to_searchisko       - A boolean controlling whether a push to
      #                                    seachisko should happen. A push will not
      #                                    happen when the development profile is in
      #                                    use, regardless of the value of this 
      #                                    option.
      # Returns the created extension.
      def initialize(opts = {})
        required_keys = [:repository, :directory, :layout, :output_dir, :site_variable]
        opts = {additional_excludes: [], recurse_subdirectories: true, 
                additional_metadata_keys: [], site_variable: opts[:output_dir], push_to_searchisko: true}.merge opts
        missing_required_keys = required_keys - opts.keys

        raise ArgumentError.new "Missing required arguments #{missing_required_keys.join ', '}" unless missing_required_keys.empty?

        @repo = opts[:repository]
        @output_dir = Pathname.new opts[:output_dir]
        @layout = opts[:layout]
        @recurse_subdirectories = opts[:recurse_subdirectories]
        @additional_metadata_keys = opts[:additional_metadata_keys]
        @additional_excludes = opts[:additional_excludes]
        @directory = File.join opts[:repository], opts[:directory]
        @site_variable = opts[:site_variable]
        @push_to_searchisko = opts[:push_to_searchisko]
      end

      # Internal: Execute method required by awestruct. Called during the
      # pipeline execution. No return.
      #
      # site - The site instance from awestruct.
      #
      # Returns nothing.
      def execute site
        searchisko = Aweplug::Helpers::Searchisko.default site, 360

        Find.find @directory do |path|
          Find.prune if File.directory?(path) && !@recurse_subdirectories

          next if File.directory?(path) # If it's a directory, start recursing

          Find.prune if File.extname(path) !~ /\.a(scii)?doc/ || @additional_excludes.include?(File.basename path)

          # TODO: Skip adding the page to the site if it's already there

          page = site.engine.load_site_page path
          
          page.layout = @layout
          # TODO: Set the imagedir attribute for the page
          page.output_dir =  File.join(@output_dir, File.basename(page.output_path, File.extname(page.output_path))).downcase
          page.output_path = '/' + File.join(page.output_dir, 'index.html')

          doc = Asciidoctor.load_file path
          metadata = {:author => doc.author, 
                      :commits => commit_info(@repo, path), 
                      :current_tag => current_tag(@repo, path),
                      :current_branch => current_branch(@repo, path),
                      :title => doc.doctitle, 
                      :tags => doc.attributes['tags'],
                      :toc => doc.sections.inject([]) {|result, elm| result << {:id => elm.id, :text => elm.title}; result},
                      :github_repo_url => repository_url(@repo),
                      # Will need to strip html tags for summary
                      :summary => doc.sections.first.blocks.first.content,
                      :searchisko_type => 'jbossdeveloper_example',
                      :searchisko_id => Digest::SHA1.hexdigest(doc.doctitle)[0..7]
                    }
          metadata[:published] = DateTime.parse(metadata[:commits].first[:date]) unless metadata[:commits].empty?
          unless metadata[:current_branch] == 'HEAD'
            git_ref = metadata[:current_branch]
          else
            git_ref = metadata[:current_tag] || 'HEAD'
          end
          metadata[:download] = "#{metadata[:github_repo_url]}/archive/#{git_ref}.zip"
          metadata[:browse] = "#{metadata[:github_repo_url]}/tree/#{git_ref}"
          metadata[:scm] = 'github'

          metadata[:contributors] = metadata[:commits].collect { |c| c[:author_email] }.uniq

          site.pages << page

          searchisko_hash = {
            :sys_title => metadata[:title], 
            :sys_description => metadata[:summary],
            :sys_content => doc.render, 
            :sys_url_view => "#{site.base_url}#{site.ctx_root.nil? ? '/' : '/' + site.ctx_root + '/'}#{page.output_dir}",
            :contributors => metadata[:contributors],
            :author => metadata[:author],
            :sys_created => metadata[:commits].collect { |c| DateTime.parse c[:date] }.last,
            :sys_activity_dates => metadata[:commits].collect { |c| DateTime.parse c[:date] },
          } 

          @additional_metadata_keys.inject(searchisko_hash) do |hash, key|
            hash[key.to_sym] = doc.attributes[key]
            hash
          end

          if @push_to_searchisko
            searchisko.push_content(metadata[:searchisko_type],
                                    metadata[:searchisko_id],
                                    searchisko_hash.to_json)
          end

          unless metadata[:author].nil?
            metadata[:author] = normalize 'contributor_profile_by_jbossdeveloper_quickstart_author', metadata[:author], searchisko
          end

          metadata[:contributors].collect! do |contributor|
            contributor = normalize 'contributor_profile_by_jbossdeveloper_quickstart_author', contributor, searchisko
          end
          metadata[:contributors].delete(metadata[:author])


          page.send('metadata=', metadata)
        end
      end
    end
  end
end
