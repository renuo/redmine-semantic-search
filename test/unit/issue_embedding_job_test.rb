require File.expand_path('../../test_helper', __FILE__)

class IssueEmbeddingJobTest < ActiveSupport::TestCase
  fixtures :projects, :users, :issues

  def setup
    @issue = Issue.find(1)

    @embedding_service_mock = EmbeddingServiceMock.new
    EmbeddingService.stubs(:new).returns(@embedding_service_mock)

    IssueEmbedding.delete_all
  end

  def test_job_creates_embedding_when_enabled
    Setting.plugin_redmine_semantic_search = {
      "enabled" => "1",
      "embedding_model" => "text-embedding-ada-002"
    }

    job = IssueEmbeddingJob.new
    job.perform(@issue.id)

    embedding = IssueEmbedding.find_by(issue_id: @issue.id)
    assert_not_nil embedding
    assert_equal @issue.id, embedding.issue_id
  end

  def test_job_does_nothing_when_disabled
    Setting.plugin_redmine_semantic_search = {
      "enabled" => "0",
      "embedding_model" => "text-embedding-ada-002"
    }

    job = IssueEmbeddingJob.new
    job.perform(@issue.id)

    embedding = IssueEmbedding.find_by(issue_id: @issue.id)
    assert_nil embedding
  end

  def test_job_does_not_update_unchanged_embedding
    Setting.plugin_redmine_semantic_search = {
      "enabled" => "1",
      "embedding_model" => "text-embedding-ada-002"
    }

    content_hash = IssueEmbedding.calculate_content_hash(@issue)
    original_embedding = IssueEmbedding.create!(
      issue_id: @issue.id,
      embedding_vector: [0.1] * 2000,
      content_hash: content_hash,
      model_used: 'text-embedding-ada-002'
    )

    job = IssueEmbeddingJob.new
    job.perform(@issue.id)

    updated_embedding = IssueEmbedding.find_by(issue_id: @issue.id)
    assert_equal original_embedding.id, updated_embedding.id
    assert_equal original_embedding.content_hash, updated_embedding.content_hash
  end

  def test_job_does_nothing_if_issue_not_found
    Setting.plugin_redmine_semantic_search = {
      "enabled" => "1",
      "embedding_model" => "text-embedding-ada-002"
    }

    job = IssueEmbeddingJob.new
    job.perform(9999)

    assert_nil IssueEmbedding.find_by(issue_id: 9999)
  end

  def test_job_handles_embedding_generation_failure
    Setting.plugin_redmine_semantic_search = {
      "enabled" => "1",
      "embedding_model" => "text-embedding-ada-002"
    }

    @embedding_service_mock.stubs(:generate_embedding).raises(StandardError.new("Test error"))

    job = IssueEmbeddingJob.new
    assert_raises StandardError do
      job.perform(@issue.id)
    end

    embedding = IssueEmbedding.find_by(issue_id: @issue.id)
    assert_nil embedding
  end
end
