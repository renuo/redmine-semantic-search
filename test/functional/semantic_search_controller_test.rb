require File.expand_path('../../test_helper', __FILE__)

class SemanticSearchControllerTest < Redmine::ControllerTest
  include ActiveJob::TestHelper
  include ApplicationHelper
  fixtures :projects, :users, :roles, :members, :member_roles, :issues, :trackers

  def setup
    @request.session[:user_id] = 1
    Role.find(1).add_permission! :use_semantic_search

    # Enable the plugin by default for most tests
    Setting.plugin_redmine_semantic_search = { "enabled" => "1" }
  end

  def test_index
    get :index
    assert_response :success
    assert_select 'h2', 'Semantic Search'
    assert_select 'form#semantic-search-form'
  end

  def test_index_with_query
    search_results = [
      {
        'issue_id' => 1,
        'subject' => 'Test issue',
        'project_name' => 'eCookbook',
        'tracker_name' => 'Bug',
        'status_name' => 'New',
        'priority_name' => 'Normal',
        'author_name' => 'Admin',
        'assigned_to_name' => 'John Smith',
        'created_on' => Time.now.to_s,
        'updated_on' => Time.now.to_s,
        'description' => 'Test description',
        'similarity_score' => 0.85
      }
    ]

    search_service = mock('SemanticSearchService')
    search_service.stubs(:search).returns(search_results)
    SemanticSearchService.stubs(:new).returns(search_service)

    get :index, params: { q: 'test query' }
    assert_response :success

    assert_select '#search-results', 1, "Search results container not found"

    assert_select 'dl#search-results-list', 1, "Search results list not found"
    assert_select 'dl#search-results-list dt', 1, "No search result items found"
  end

  def test_sync_embeddings_when_enabled
    assert_enqueued_with(job: SyncEmbeddingsJob) do
      post :sync_embeddings
    end

    assert_redirected_to controller: 'issues', action: 'index'
    assert_equal l(:notice_sync_embeddings_started, count: Issue.count), flash[:notice]
  end

  def test_sync_embeddings_when_disabled
    Setting.plugin_redmine_semantic_search = { "enabled" => "0" }

    assert_no_enqueued_jobs do
      post :sync_embeddings
    end

    assert_redirected_to controller: 'issues', action: 'index'
    assert_equal l(:error_plugin_disabled), flash[:error]
  end

  def test_non_admin_cannot_sync_embeddings
    @request.session[:user_id] = 2
    post :sync_embeddings
    assert_response :forbidden
  end

  def test_manager_can_access_search_when_enabled
    @request.session[:user_id] = 2
    get :index
    assert_response :success
  end

  def test_manager_cannot_access_search_when_disabled
    Setting.plugin_redmine_semantic_search = { "enabled" => "0" }

    @request.session[:user_id] = 2
    get :index
    assert_response :not_found
  end

  def test_admin_can_access_search_when_disabled
    Setting.plugin_redmine_semantic_search = { "enabled" => "0" }

    @request.session[:user_id] = 1
    get :index
    assert_response :success
  end

  def test_anonymous_cannot_access_search
    @request.session[:user_id] = nil
    get :index
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Fsemantic_search'
  end
end
