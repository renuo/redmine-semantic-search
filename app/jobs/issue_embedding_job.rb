class IssueEmbeddingJob < ActiveJob::Base
  queue_as :default

  def perform(issue_id)
    return unless plugin_enabled?

    Rails.logger.info("=> [SEMANTIC_SEARCH] Performing job for issue #{issue_id}")
    issue = Issue.find_by(id: issue_id)
    return unless issue

    embedding = IssueEmbedding.find_or_initialize_by(issue_id: issue_id)
    content_hash = IssueEmbedding.calculate_content_hash(issue)

    return unless embedding_needs_update?(embedding, content_hash)

    update_embedding(issue, embedding, content_hash)
  end

  private

  def plugin_enabled?
    Setting.plugin_redmine_semantic_search["enabled"] == "1"
  end

  def embedding_needs_update?(embedding, new_content_hash)
    embedding.content_hash != new_content_hash ||
      embedding.model_used != Setting.plugin_redmine_semantic_search["embedding_model"]
  end

  def update_embedding(issue, embedding, content_hash)
    embedding_service = EmbeddingService.new
    begin
      content = embedding_service.prepare_issue_content(issue)
      vector = embedding_service.generate_embedding(content)

      embedding.embedding_vector = vector
      embedding.content_hash = content_hash
      embedding.model_used = Setting.plugin_redmine_semantic_search["embedding_model"]
      embedding.save!

      Rails.logger.info("=> [SEMANTIC_SEARCH] Successfully generated embedding for Issue ##{issue.id}")
    rescue StandardError => e
      Rails.logger.error("=> [SEMANTIC_SEARCH] Failed to generate embedding for Issue ##{issue.id}: #{e.message}")
      raise e
    end
  end
end
