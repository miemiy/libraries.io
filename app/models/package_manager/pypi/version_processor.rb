# frozen_string_literal: true

module PackageManager
  class Pypi
    class VersionProcessor
      def initialize(project_releases:, project_name:, known_versions:)
        @project_releases = project_releases
        @project_name = project_name
        @known_versions = known_versions
      end

      def execute
        @project_releases.map do |project_release|
          if @known_versions.key?(project_release.version_number)
            known_attributes = @known_versions[project_release.version_number]
            status = if project_release&.yanked?
                       "Removed"
                     elsif known_attributes[:status] == "Removed"
                       nil
                     else
                       known_attributes[:status]
                     end
            known_attributes[:status] = status
            known_attributes
          else
            version_number = project_release.version_number
            original_license = json_api_single_release_for_version(version_number).license
            rss_api_release = rss_api_releases_hash[version_number]
            published_at = project_release.published_at || rss_api_release&.published_at
            status = project_release&.yanked? ? "Removed" : nil

            {
              number: version_number,
              published_at: published_at,
              original_license: original_license,
              status: status,
              deprecation_reason: project_release&.yanked_reason,
            }
          end
        end
      end

      private

      def rss_api_releases
        RssApiReleases.request(project_name: @project_name).releases
      end

      def json_api_single_release_for_version(version_number)
        JsonApiSingleRelease.request(
          project_name: @project_name,
          version_number: version_number
        )
      end

      def rss_api_releases_hash
        return @rss_api_releases_hash if @rss_api_releases_hash

        @rss_api_releases_hash = if @project_releases.all_releases_have_published_at?
                                   {}
                                 else
                                   rss_api_releases.each_with_object({}) do |release, obj|
                                     obj[release.version_number] = release
                                   end
                                 end
      end
    end
  end
end
