# frozen_string_literal: true

namespace :maintenance_stats do
  desc "Gather maintenance stats for a list of repositories"
  task :gather_maintenance_stats, %i[input_file commit] => :environment do |_t, args|
    commit = args.commit.present? && args.commit == "yes"
    data = CSV.read(args.input_file, headers: false, col_sep: "\t")

    skipped_no_package_count = 0
    result_ids = []
    skipped_no_repository_count = 0
    data.each do |platform, name|
      # libraries platform casing varies
      project = Project.find_by("platform ILIKE ? AND name LIKE ?", platform, name)

      unless project
        Rails.logger.info("Did not find project: #{platform}/#{name}")
        skipped_no_package_count += 1
        next
      end

      repository = project.repository
      unless repository
        Rails.logger.info("Did not find repository: #{platform}/#{name}")
        skipped_no_repository_count += 1
        next
      end

      project.repository.gather_maintenance_stats if commit
      result_ids << project.id
      Rails.logger.info("Processed: #{platform}/#{name}")
    end

    Rails.logger.info("#{data.count} total rows")
    Rails.logger.info("#{skipped_no_package_count} rows could not find packages for")
    Rails.logger.info("#{skipped_no_repository_count} rows could not find repositories for")
    Rails.logger.info("Enqueud #{result_ids.count} projects for updating. Project IDs:")
    Rails.logger.info(result_ids.join(", "))
    Rails.logger.info("\nThese changes have not been committed. Re-run this task with [,yes] to proceed.") unless commit
  end

  supported_platforms = %w[Cargo CocoaPods Conda Go Maven NPM NuGet Packagist Pypi Rubygems]

  desc "Create maintenance stats for projects"
  task :create_maintenance_stats, [:number_to_sync] => :environment do |_task, args|
    exit if ENV["READ_ONLY"].present?
    number_to_sync = args.number_to_sync || 2000
    Project.joins(:repository).where(platform: supported_platforms).merge(Repository.no_existing_stats).limit(number_to_sync).each(&:update_maintenance_stats_async)
  end

  desc "Update maintenance stats for repositories"
  task :update_maintenance_stats, [:number_to_sync] => :environment do |_task, args|
    exit if ENV["READ_ONLY"].present?
    number_to_sync = args.number_to_sync || 2000
    Repository.least_recently_updated_stats.where(host_type: "GitHub").limit(number_to_sync).each { |repository| repository.gather_maintenance_stats_async(priority: :low) }
  end
end
