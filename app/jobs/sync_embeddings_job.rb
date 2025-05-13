class SyncEmbeddingsJob < ActiveJob::Base
  queue_as :default

  def perform
    return unless plugin_enabled?

    Issue.find_each do |issue|
      IssueEmbeddingJob.perform_later(issue.id)
    end

    Rails.logger.info("=> [SEMANTIC_SEARCH] Scheduled embedding generation for all issues")
  end

  private

  def plugin_enabled?
    Setting.plugin_semantic_search["enabled"] == "1"
  end
end
