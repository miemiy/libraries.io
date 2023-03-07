# frozen_string_literal: true

namespace :maintenance_stats do
  desc "Gather maintenance stats for a list of repositories"
  task :gather_maintenance_stats, %i[input_file commit] => :environment do |_t, args|
    commit = args.commit.present? && args.commit == "yes"
    data = CSV.read(args.input_file, headers: false)

    skipped_no_package_count = 0
    result_ids = []
    skipped_no_repository_count = 0
    data.each do |package_info|
      # libraries platform casing varies
      project = Project.find_by("platform ILIKE ? AND name LIKE ?", package_info[0], package_info[1])

      unless project
        Rails.logger.info("Did not find project: #{package_info[0]}/#{package_info[0]}")
        skipped_no_package_count += 1
        next
      end

      repository = project.repository
      unless repository
        Rails.logger.info("Did not find repository: #{package_info[1]}/#{package_info[1]}")
        skipped_no_repository_count += 1
        next
      end

      project.repository.gather_maintenance_stats if commit
      result_ids << project.id

      Rails.logger.info("#{data.count} total rows")
      Rails.logger.info("#{skipped_no_package_count} rows could not find packages for")
      Rails.logger.info("#{skipped_no_repository_count} rows could not find repositories for")
      Rails.logger.info("Enqueud #{result_ids.count} projects for updating. Project IDs:")
      Rails.logger.info(result_ids.join(", "))
      Rails.logger.info("\nThese changes have not been committed. Re-run this task with [,yes] to proceed.") unless commit
    end
  end
end
