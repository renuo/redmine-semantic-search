class IssueEmbeddingJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id)
    Rails.logger.info("=> [SEMANTIC_SEARCH] Performing job for issue #{issue_id}")
    issue = Issue.find_by(id: issue_id)
    return unless issue

    embedding_service = EmbeddingService.new
    embedding = IssueEmbedding.find_or_initialize_by(issue_id: issue_id)

    # no need to compare EVERY subject, description, etc.
    content_hash = IssueEmbedding.calculate_content_hash(issue)

    return if embedding.persisted? && embedding.content_hash == content_hash

    begin
      content = embedding_service.prepare_issue_content(issue)
      vector = embedding_service.generate_embedding(content)

      embedding.embedding_vector = vector
      embedding.content_hash = content_hash
      embedding.save!

      Rails.logger.info("=> [SEMANTIC_SEARCH] Successfully generated embedding for Issue ##{issue_id}")
    rescue StandardError => e
      Rails.logger.error("=> [SEMANTIC_SEARCH] Failed to generate embedding for Issue ##{issue_id}: #{e.message}")
      raise e
    end
  end
end
