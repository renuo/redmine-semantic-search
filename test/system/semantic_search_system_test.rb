require File.expand_path('../../application_system_test_case', __FILE__)

class SemanticSearchSystemTest < ApplicationSystemTestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :trackers

  def setup
    @user = User.find_by(login: 'jsmith') || users(:users_002)
    @role = Role.find_by(name: 'Manager') || roles(:roles_001)
    @role.add_permission!(:use_semantic_search)

    ENV['OPENAI_API_KEY'] = 'test_api_key'

    @project = Project.find_by(identifier: 'ecookbook') || projects(:projects_001)
    @tracker = Tracker.first

    # Destroy any existing test issues with the same subject to ensure a clean test environment
    Issue.where(subject: 'Test issue for semantic search').destroy_all

    @issue = Issue.create!(
      project: @project,
      tracker: @tracker,
      author: @user,
      subject: 'Test issue for semantic search',
      description: 'This is a test issue created for semantic search testing'
    )

    # Ensure any existing embeddings are removed
    IssueEmbedding.where(issue_id: @issue.id).destroy_all

    @embedding = IssueEmbedding.create!(
      issue: @issue,
      embedding_vector: [0.1] * 1536,
      content_hash: 'test_hash',
      model_used: 'text-embedding-ada-002'
    )

    EmbeddingService.any_instance.stubs(:generate_embedding).returns([0.1] * 1536)

    mock_result = [{
      "issue_id" => @issue.id,
      "subject" => @issue.subject,
      "description" => @issue.description,
      "project_name" => @project.name,
      "created_on" => @issue.created_on,
      "updated_on" => @issue.updated_on,
      "tracker_id" => @tracker.id,
      "tracker_name" => @tracker.name,
      "status_name" => @issue.status.name,
      "priority_name" => @issue.priority.name,
      "author_name" => @user.name,
      "assigned_to_name" => nil,
      "similarity_score" => 0.95
    }]

    SemanticSearchService.any_instance.stubs(:search).with(any_parameters).returns(mock_result)

    Setting.plugin_semantic_search = { "enabled" => "1" }

    SemanticSearchController.any_instance.stubs(:check_if_enabled).returns(true)

    logout
    log_user(@user.login, 'jsmith')
  end

  def teardown
    ENV.delete('OPENAI_API_KEY')

    # Clean up any stubs
    SemanticSearchService.any_instance.unstub(:search) if SemanticSearchService.any_instance.respond_to?(:search)
    EmbeddingService.any_instance.unstub(:generate_embedding)
    SemanticSearchController.any_instance.unstub(:check_if_enabled)

    # Clean up test data
    @embedding.destroy if @embedding && IssueEmbedding.exists?(@embedding.id)
    @issue.destroy if @issue && Issue.exists?(@issue.id)

    # Ensure browser is reset
    Capybara.reset_sessions!
  end

  test "semantic search end-to-end happy path" do
    visit '/semantic_search'

    assert_selector 'h2', text: 'Semantic Search'
    assert_selector 'form#semantic-search-form'

    within '#semantic-search-form' do
      fill_in 'q', with: 'test query about bug issues'
      click_button 'Search'
    end

    using_wait_time 10 do
      assert_selector '#search-results'
      assert_selector 'dl#search-results-list'
      assert_selector "dt a[href='/issues/#{@issue.id}']"
    end

    find("dt a[href='/issues/#{@issue.id}']").click

    using_wait_time 10 do
      assert_current_path(%r{/issues/#{@issue.id}}, url: true)
    end
  end

  test "semantic search with empty results" do
    SemanticSearchService.any_instance.unstub(:search)
    SemanticSearchService.any_instance.stubs(:search).returns([])

    visit '/semantic_search'

    # Ensure page is loaded
    assert_selector '#semantic-search-form', wait: 5

    within '#semantic-search-form' do
      fill_in 'q', with: 'query with no results'
      click_button 'Search'
    end

    # Wait for the search to complete and check for empty results message
    using_wait_time 10 do
      assert_selector '#search-results'
      assert_selector 'p.nodata', text: I18n.t(:label_no_data)
    end
  end

  test "semantic search page is accessible only to authorized users" do
    SemanticSearchController.any_instance.unstub(:check_if_enabled)

    Capybara.reset_sessions!

    visit '/semantic_search'

    using_wait_time 5 do
      assert_current_path(/\/login/, url: true)
    end
  end

  test "top_menu_item_is_hidden_when_plugin_is_disabled" do
    logout

    log_user('admin', 'admin')

    assert_selector '#loggedas', wait: 5

    Setting.plugin_semantic_search = Setting.plugin_semantic_search.merge('enabled' => '0')

    visit '/'

    assert_selector '#top-menu', wait: 5

    within '#top-menu' do
      assert_no_link I18n.t(:label_semantic_search)
    end
  end
end
