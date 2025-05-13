require File.expand_path('../../test_helper', __FILE__)

class SemanticSearchTest < Redmine::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles, :issues, :trackers

  def setup
    @user = User.find(2)
    @role = Role.find(1)
    @role.add_permission!(:use_semantic_search)

    ENV['OPENAI_API_KEY'] = 'test_api_key'

    @issue = Issue.find(1)
    @embedding = IssueEmbedding.create!(
      issue: @issue,
      embedding_vector: [0.1] * 1536,
      content_hash: 'test_hash',
      model_used: 'text-embedding-ada-002'
    )

    @mock_results = [
      {
        'issue_id' => @issue.id,
        'subject' => @issue.subject,
        'project_name' => @issue.project.name,
        'tracker_name' => @issue.tracker.name,
        'updated_on' => @issue.updated_on.to_s,
        'distance' => 0.25
      }
    ]
    SemanticSearchService.any_instance.stubs(:search).returns(@mock_results)

    Setting.plugin_semantic_search = { "enabled" => "1" }

    SemanticSearchController.any_instance.stubs(:check_if_enabled).returns(true)
  end

  def teardown
    ENV.delete('OPENAI_API_KEY')
    SemanticSearchController.any_instance.unstub(:check_if_enabled)
  end

  def test_semantic_search_happy_path
    log_user(@user.login, 'jsmith')

    get '/semantic_search'
    assert_response :success
    assert_select 'h2', 'Semantic Search'

    get '/semantic_search', params: { q: 'test query' }
    assert_response :success

    assert_select 'dl#search-results-list dt', 1
    assert_select 'dl#search-results-list dt a.issue-link', text: "Issue ##{@issue.id}: #{@issue.subject}"
  end

  def test_semantic_search_requires_login
    get '/semantic_search'
    assert_redirected_to '/login?back_url=http%3A%2F%2Fwww.example.com%2Fsemantic_search'
  end

  def test_semantic_search_requires_permission
    @role.remove_permission!(:use_semantic_search)

    log_user(@user.login, 'jsmith')

    get '/semantic_search'
    assert_response :forbidden
  end

  private

  def log_user(login, password)
    get '/login'
    assert_response :success
    post '/login', params: {
      username: login,
      password: password
    }
    assert_redirected_to '/my/page'
    follow_redirect!
    assert_equal login, User.find(session[:user_id]).login
  end
end
