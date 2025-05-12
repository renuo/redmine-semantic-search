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

    @issue = Issue.create!(
      project: @project,
      tracker: @tracker,
      author: @user,
      subject: 'Test issue for semantic search',
      description: 'This is a test issue created for semantic search testing'
    )

    @embedding = IssueEmbedding.create!(
      issue: @issue,
      embedding_vector: [0.1] * 1536,
      content_hash: 'test_hash'
    )

    EmbeddingService.any_instance.stubs(:generate_embedding).returns([0.1] * 1536)

    @mock_result = [{
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

    SemanticSearchService.any_instance.stubs(:search).returns(@mock_result)

    log_user(@user.login, 'jsmith')
  end

  def teardown
    ENV.delete('OPENAI_API_KEY')
    @embedding.destroy if @embedding && IssueEmbedding.exists?(@embedding.id)
    @issue.destroy if @issue && Issue.exists?(@issue.id)
  end

  test "semantic search end-to-end happy path" do
    visit '/semantic_search'

    assert_selector 'h2', text: 'Semantic Search'
    assert_selector 'form#semantic-search-form'

    within '#semantic-search-form' do
      fill_in 'q', with: 'test query about bug issues'
      click_button 'Search'
    end

    assert_selector 'dl#search-results-list', wait: 5

    assert_selector "dt a[href='/issues/#{@issue.id}']"

    find("dt a[href='/issues/#{@issue.id}']").click

    assert_current_path(%r{/issues/#{@issue.id}}, url: true)
  end

  test "semantic search with empty results" do
    SemanticSearchService.any_instance.unstub(:search)
    SemanticSearchService.any_instance.stubs(:search).returns([])

    visit '/semantic_search'

    within '#semantic-search-form' do
      fill_in 'q', with: 'query with no results'
      click_button 'Search'
    end

    assert_selector 'p.nodata', wait: 5
  end

  test "semantic search page is accessible only to authorized users" do
    Capybara.reset_sessions!

    visit '/semantic_search'

    assert_current_path(/\/login/, url: true)
  end
end
