# frozen_string_literal: true

class RepositoryDownloadWorker
  include Sidekiq::Worker
  sidekiq_options queue: :repo, lock: :until_executed

  def perform(repo_id, token = nil)
    Repository.find_by_id(repo_id).try(:update_all_info, token)
  end
end
