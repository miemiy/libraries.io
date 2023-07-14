module PackageManager
  class Pypi
    class JsonApiProject
      def self.request(name:)
        data = begin
          ApiService.get("https://pypi.org/pypi/#{name}/json")
        # TODO: handle this condition better. this is how the code
        # originally dealt with API errors
        rescue StandardError
          {}
        end

        new(data)
      end

      def initialize(data)
        @data = data
      end

      def license
        @data.dig("info", "license")
      end

      def license_classifiers
        license_classifiers = @data.dig("info", "classifiers").select { |c| c.start_with?("License :: ") }
        license_classifiers.map { |l| l.split(":: ").last }.join(",")
      end

      def name
        @data.dig("info", "name")
      end

      def description
        @data.dig("info", "summary")
      end

      def homepage
        @data.dig("info", "home_page")
      end

      def keywords_array
        Array.wrap(@data.dig("info", "keywords").try(:split, /[\s.,]+/))
      end

      def licenses
        license.presence || license_classifiers
      end

      def repository_url
        ["Source", "Source Code", "Repository", "Code"].filter_map do |field|
          @data.dig("info", "project_urls", field)
        end.first
      end

      def homepage_url
        @data.dig("info", "home_page").presence ||
          @data.dig("info", "project_urls", "Homepage")
      end

      def preferred_repository_url
        RepositoryService.repo_fallback(
          repository_url,
          homepage_url
        )
      end

      def self.release_data_published_at(details)
        return nil if details == []

        upload_time = details.dig(0, "upload_time")
        raise ArgumentError, "does not contain upload_time" unless upload_time

        upload_time ? Time.parse(upload_time) : nil
      end

      def releases
        @data["releases"].map do |number, details|
          JsonApiProjectRelease.new(
            project: self,
            number: number,
            published_at: self.class.release_data_published_at(details)
          )
        end
      end

      # Various parts of this process still want raw hashes for a type
      # of data called a "mapping".
      def to_mapping
        {
          name: name,
          description: description,
          homepage: homepage,
          keywords_array: keywords_array,
          licenses: licenses,
          repository_url: preferred_repository_url,
        }
      end
    end
  end
end
