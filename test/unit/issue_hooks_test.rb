require File.expand_path('../../test_helper', __FILE__)

class IssueHooksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  fixtures :projects, :users, :issues, :journals, :time_entries

  def setup
    @issue = Issue.find(1)
    @issue_hooks = SemanticSearch::IssueHooks.instance

    clear_enqueued_jobs
    ActiveJob::Base.queue_adapter = :test
  end

  def test_hooks_schedule_job_when_enabled
    Setting.plugin_semantic_search = { "enabled" => "1" }

    @issue_hooks.define_singleton_method(:schedule_embedding_job) do |issue_id|
      IssueEmbeddingJob.perform_later(issue_id)
    end

    @issue_hooks.define_singleton_method(:plugin_enabled?) do
      true
    end

    assert_enqueued_with(job: IssueEmbeddingJob, args: [@issue.id]) do
      @issue_hooks.controller_issues_new_after_save(issue: @issue)
    end
    clear_enqueued_jobs

    assert_enqueued_with(job: IssueEmbeddingJob, args: [@issue.id]) do
      @issue_hooks.controller_issues_edit_after_save(issue: @issue)
    end
    clear_enqueued_jobs

    journal = Journal.new(journalized: @issue, journalized_type: 'Issue', user_id: 1, notes: 'Test comment')
    journal.save
    assert_enqueued_with(job: IssueEmbeddingJob, args: [@issue.id]) do
      @issue_hooks.controller_journals_new_after_save(journal: journal)
    end
    clear_enqueued_jobs

    assert_enqueued_with(job: IssueEmbeddingJob, args: [@issue.id]) do
      @issue_hooks.controller_journals_edit_post(journal: journal)
    end
    clear_enqueued_jobs

    time_entry = TimeEntry.new(
      issue: @issue,
      user_id: 2,
      hours: 1,
      spent_on: Date.today,
      activity_id: 9,
      project_id: @issue.project_id,
      comments: 'Test time entry comment'
    )
    assert_enqueued_with(job: IssueEmbeddingJob, args: [@issue.id]) do
      @issue_hooks.controller_timelog_edit_after_save(time_entry: time_entry)
    end
  end

  def test_hooks_do_not_schedule_job_when_disabled
    Setting.plugin_semantic_search = { "enabled" => "0" }

    assert_equal "0", Setting.plugin_semantic_search["enabled"]

    # Stub plugin_enabled? to return false
    @issue_hooks.define_singleton_method(:plugin_enabled?) do
      false
    end

    assert_no_enqueued_jobs do
      @issue_hooks.controller_issues_new_after_save(issue: @issue)
    end

    assert_no_enqueued_jobs do
      @issue_hooks.controller_issues_edit_after_save(issue: @issue)
    end

    journal = Journal.new(journalized: @issue, journalized_type: 'Issue', user_id: 1, notes: 'Test comment')
    journal.save
    assert_no_enqueued_jobs do
      @issue_hooks.controller_journals_new_after_save(journal: journal)
    end

    assert_no_enqueued_jobs do
      @issue_hooks.controller_journals_edit_post(journal: journal)
    end

    time_entry = TimeEntry.new(
      issue: @issue,
      user_id: 2,
      hours: 1,
      spent_on: Date.today,
      activity_id: 9,
      project_id: @issue.project_id,
      comments: 'Test time entry comment'
    )
    assert_no_enqueued_jobs do
      @issue_hooks.controller_timelog_edit_after_save(time_entry: time_entry)
    end
  end
end
