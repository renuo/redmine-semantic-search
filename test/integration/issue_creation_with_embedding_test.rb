require File.expand_path('../../test_helper', __FILE__)

class IssueCreationWithEmbeddingTest < Redmine::IntegrationTest
  include ActiveJob::TestHelper
  include LoginHelpers::Integration
  fixtures :projects, :users, :roles, :members, :member_roles, :trackers, :issue_statuses

  def setup
    @project = Project.find(1)
    @user = User.find(2)
    @role = Role.find(1)
    @role.add_permission!(:add_issues)
    @role.add_permission!(:use_semantic_search)

    @tracker = Tracker.find(1)
    @project.trackers << @tracker unless @project.trackers.include?(@tracker)

    @embedding_service_mock = EmbeddingServiceMock.new
    EmbeddingService.stubs(:new).returns(@embedding_service_mock)

    clear_enqueued_jobs

    IssueEmbedding.delete_all
  end

  def test_issue_creation_schedules_embedding_job_when_enabled
    Setting.plugin_redmine_semantic_search = { "enabled" => "1" }

    RedmineSemanticSearch::IssueHooks.instance.stubs(:plugin_enabled?).returns(true)

    RedmineSemanticSearch::IssueHooks.instance.stubs(:schedule_embedding_job).with do |issue_id|
      IssueEmbeddingJob.perform_later(issue_id)
    end

    log_user(@user.login, 'jsmith')

    get "/projects/#{@project.identifier}/issues/new"
    assert_response :success

    post "/projects/#{@project.identifier}/issues", params: {
      issue: {
        tracker_id: @tracker.id,
        subject: 'Test issue with embedding',
        description: 'This is a test issue to verify embedding generation',
        priority_id: IssuePriority.first.id
      }
    }

    assert_response :redirect
    follow_redirect!
    assert_response :success

    issue_id = request.path.split('/').last.to_i

    assert_enqueued_with(job: IssueEmbeddingJob, args: [issue_id])
  end

  def test_issue_creation_does_not_schedule_job_when_disabled
    Setting.plugin_redmine_semantic_search = { "enabled" => "0" }

    original_method = RedmineSemanticSearch::IssueHooks.instance.method(:plugin_enabled?)

    RedmineSemanticSearch::IssueHooks.instance.singleton_class.class_eval do
      define_method(:plugin_enabled?) { false }
    end

    RedmineSemanticSearch::IssueHooks.instance.singleton_class.class_eval do
      define_method(:schedule_embedding_job) { |issue_id| nil }
    end

    perform_enqueued_jobs do
      clear_enqueued_jobs

      log_user(@user.login, 'jsmith')

      get "/projects/#{@project.identifier}/issues/new"
      assert_response :success

      post "/projects/#{@project.identifier}/issues", params: {
        issue: {
          tracker_id: @tracker.id,
          subject: 'Test issue without embedding',
          description: 'This is a test issue when plugin is disabled',
          priority_id: IssuePriority.first.id
        }
      }

      assert_response :redirect
      follow_redirect!
      assert_response :success
    end

    assert_no_enqueued_jobs

    RedmineSemanticSearch::IssueHooks.instance.singleton_class.class_eval do
      define_method(:plugin_enabled?, original_method)
    end
  end
end
