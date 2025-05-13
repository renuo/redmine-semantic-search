require File.expand_path('../../application_system_test_case', __FILE__)

class SemanticSearchSystemTest < ApplicationSystemTestCase
  fixtures :projects, :users, :roles, :members, :member_roles, :trackers

  def setup
    # Start with a clean session
    Capybara.reset_sessions!

    # Find or create test user
    @user = User.find_by(login: 'jsmith')
    unless @user
      puts "Creating test user 'jsmith'"
      @user = User.create!(
        login: 'jsmith',
        firstname: 'John',
        lastname: 'Smith',
        mail: 'jsmith@example.net',
        status: 1,
        password: 'jsmith',
        password_confirmation: 'jsmith'
      )
    end

    # Find or create manager role
    @role = Role.find_by(name: 'Manager')
    unless @role
      puts "Creating Manager role"
      @role = Role.create!(name: 'Manager')
    end
    @role.add_permission!(:use_semantic_search)

    # Set up test environment
    ENV['OPENAI_API_KEY'] = 'test_api_key'

    # Find or create test project
    @project = Project.find_by(identifier: 'ecookbook')
    unless @project
      puts "Creating test project 'ecookbook'"
      @project = Project.create!(
        name: 'eCookbook',
        identifier: 'ecookbook',
        is_public: true
      )
    end

    # Ensure user is a member of the project
    unless @project.members.exists?(user_id: @user.id)
      puts "Adding user to project"
      @project.members.create!(user: @user, roles: [@role])
    end

    @tracker = Tracker.first || Tracker.create!(name: 'Bug')

    # Destroy any existing test issues with the same subject to ensure a clean test environment
    Issue.where(subject: 'Test issue for semantic search').destroy_all

    begin
      @issue = Issue.create!(
        project: @project,
        tracker: @tracker,
        author: @user,
        subject: 'Test issue for semantic search',
        description: 'This is a test issue created for semantic search testing'
      )

      puts "Created test issue with ID: #{@issue.id}"

      # Ensure any existing embeddings are removed
      IssueEmbedding.where(issue_id: @issue.id).destroy_all

      @embedding = IssueEmbedding.create!(
        issue: @issue,
        embedding_vector: [0.1] * 1536,
        content_hash: 'test_hash',
        model_used: 'text-embedding-ada-002'
      )

      puts "Created embedding for issue ID: #{@issue.id}"
    rescue => e
      puts "Error creating test data: #{e.message}"
      puts e.backtrace.join("\n")
      raise e
    end

    # Set up stubs
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

    # Create a more robust stub for the search service that applies to any query
    search_service = SemanticSearchService.new
    SemanticSearchService.stubs(:new).returns(search_service)
    search_service.stubs(:search).returns(mock_result)

    puts "Stubbed search service to return mock result with issue ID: #{@issue.id}"

    # Enable the plugin in settings
    Setting.plugin_semantic_search = {
      "enabled" => "1",
      "search_limit" => "10"
    }

    # Stub controller methods for more reliable tests
    SemanticSearchController.any_instance.stubs(:check_if_enabled).returns(true)

    # Log in as the test user
    logout
    log_user(@user.login, 'jsmith')
    puts "Logged in as user: #{@user.login}"
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

    # Debug the current page state
    puts "Before search - Current URL: #{current_url}"

    within '#semantic-search-form' do
      fill_in 'q', with: 'test query about bug issues'
      click_button 'Search'
    end

    # Debug after search submission
    puts "After search - Current URL: #{current_url}"

    # Force wait on query parameter in URL to ensure search was submitted
    assert has_current_path?(/\?q=.+/, wait: 10), "Search query parameter not found in URL"

    # Ensure search results are present
    assert_selector 'div#search-results', wait: 10
    assert_selector 'dl#search-results-list', wait: 10
    assert_selector "dt a[href='/issues/#{@issue.id}']", wait: 10

    find("dt a[href='/issues/#{@issue.id}']").click

    using_wait_time 10 do
      assert_current_path(%r{/issues/#{@issue.id}}, url: true)
    end
  end

  test "semantic search with empty results" do
    # Create a specific stub for empty results
    empty_search_service = SemanticSearchService.new
    SemanticSearchService.stubs(:new).returns(empty_search_service)
    empty_search_service.stubs(:search).returns([])

    puts "Set up stub for empty search results"

    visit '/semantic_search'

    # Ensure page is loaded
    assert_selector '#semantic-search-form', wait: 5
    puts "Found search form"

    within '#semantic-search-form' do
      fill_in 'q', with: 'query with no results'
      click_button 'Search'
    end

    puts "Submitted search form with query 'query with no results'"
    puts "Current URL after search: #{current_url}"

    # First verify that we have a search results section
    assert_selector '#search-results', wait: 10
    puts "Found search results container"

    # Then check for no data message
    assert_selector 'p.nodata', wait: 10
    puts "Found no data message"
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
    # Start with fresh session
    Capybara.reset_sessions!

    # Make sure user exists in test database
    admin = User.find_by(login: 'admin')
    unless admin
      puts "Admin user not found in database, creating one"
      admin = User.new(
        login: 'admin',
        firstname: 'Admin',
        lastname: 'User',
        mail: 'admin@example.net',
        admin: true,
        status: 1,
        password: 'admin',
        password_confirmation: 'admin'
      )
      admin.save!
    end

    # Log in as admin with proper credentials
    log_user('admin', 'admin')

    # Take screenshot after login for verification
    path = Rails.root.join('tmp/screenshots', "admin_logged_in_#{Time.now.to_i}.png")
    page.save_screenshot(path)
    puts "Admin login verification screenshot: #{path}"

    # Disable the plugin
    Setting.plugin_semantic_search = {"enabled" => "0", "search_limit" => "10"}
    puts "Plugin disabled: #{Setting.plugin_semantic_search.inspect}"

    # Visit the homepage
    visit '/'

    # Wait for page to load and take screenshot
    path = Rails.root.join('tmp/screenshots', "homepage_#{Time.now.to_i}.png")
    page.save_screenshot(path)
    puts "Homepage screenshot: #{path}"

    # Verify top menu exists
    assert_selector '#top-menu', wait: 10, message: "Top menu not found"

    # Check that semantic search link is not present
    semantic_search_text = I18n.t(:label_semantic_search)
    puts "Looking for menu item with text: '#{semantic_search_text}'"

    assert_no_text semantic_search_text
  end
end
