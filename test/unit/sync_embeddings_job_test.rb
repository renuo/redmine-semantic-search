require File.expand_path('../../test_helper', __FILE__)

class SyncEmbeddingsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  fixtures :projects, :users, :issues

  def setup
    clear_enqueued_jobs

    @issues = Issue.limit(3)
  end

  def test_job_schedules_issue_jobs_when_enabled
    Setting.plugin_semantic_search = { "enabled" => "1" }

    job = SyncEmbeddingsJob.new
    job.perform

    assert_equal Issue.count, enqueued_jobs.size

    issue_ids = Issue.pluck(:id)
    enqueued_jobs.each do |job|
      assert_equal "IssueEmbeddingJob", job[:job].to_s
      assert_includes issue_ids, job[:args][0]
    end
  end

  def test_job_does_nothing_when_disabled
    Setting.plugin_semantic_search = { "enabled" => "0" }

    job = SyncEmbeddingsJob.new
    job.perform

    assert_equal 0, enqueued_jobs.size
  end
end
