require File.expand_path('../../application_system_test_case', __FILE__)

class RedmineSemanticSearchSystemTest < ApplicationSystemTestCase
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
      embedding_vector: [0.1] * 2000,
      content_hash: 'test_hash',
      model_used: 'text-embedding-ada-002'
    )

    EmbeddingService.any_instance.stubs(:generate_embedding).returns([0.1] * 2000)

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

    RedmineSemanticSearchService.any_instance.stubs(:search).returns(mock_result)

    Setting.plugin_redmine_semantic_search = { "enabled" => "1" }

    RedmineSemanticSearchController.any_instance.stubs(:check_if_enabled).returns(true)

    logout
    log_user(@user.login, 'jsmith')
  end

  def teardown
    ENV.delete('OPENAI_API_KEY')
    @embedding.destroy if @embedding && IssueEmbedding.exists?(@embedding.id)
    @issue.destroy if @issue && Issue.exists?(@issue.id)
    RedmineSemanticSearchController.any_instance.unstub(:check_if_enabled)
  end

  test "semantic search end-to-end happy path" do
    visit '/semantic_search'

    assert_selector 'h2', text: 'Semantic Search'
    assert_selector 'form#redmine-semantic-search-form'

    within '#redmine-semantic-search-form' do
      fill_in 'q', with: 'test query about bug issues'
      click_button 'Search', wait: 5
    end

    assert_selector 'dl#search-results-list', wait: 5

    assert_selector "dt a[href='/issues/#{@issue.id}']"

    page.evaluate_script("window.location.href = '/issues/#{@issue.id}'")

    sleep 1

    assert_current_path(%r{/issues/#{@issue.id}}, url: true)
  end

  test "semantic search with empty results" do
    RedmineSemanticSearchService.any_instance.unstub(:search)
    RedmineSemanticSearchService.any_instance.stubs(:search).returns([])

    visit '/semantic_search'

    within '#redmine-semantic-search-form' do
      fill_in 'q', with: 'query with no results'
      click_button 'Search', wait: 3
    end

    unless page.has_css?('p.nodata', wait: 3)
      puts "DEBUG: p.nodata not found. Current page body:"
      puts page.body
    end
    assert_selector 'p.nodata', wait: 3
  end

  test "semantic search page is accessible only to authorized users" do
    RedmineSemanticSearchController.any_instance.unstub(:check_if_enabled)

    Capybara.reset_sessions!

    visit '/semantic_search'

    assert_current_path(/\/login/, url: true)
  end

  test "top_menu_item_is_hidden_when_plugin_is_disabled" do
    logout
    Capybara.reset_sessions!

    admin_user = User.find(1)
    puts "DEBUG: Admin user found: ID=#{admin_user.id}, Login=#{admin_user.login}, Status=#{admin_user.status}, Admin?=#{admin_user.admin?}, MustChangePasswd?=#{admin_user.must_change_passwd if admin_user.respond_to?(:must_change_passwd)}"

    new_password = 'SecureP@ssw0rd1'
    admin_user.password = new_password
    admin_user.password_confirmation = new_password
    admin_user.status = User::STATUS_ACTIVE
    if admin_user.respond_to?(:must_change_passwd) && admin_user.must_change_passwd
      admin_user.must_change_passwd = false
    end

    save_result = admin_user.save
    puts "DEBUG: admin_user.save result: #{save_result}"
    unless save_result
      puts "DEBUG: admin_user.errors: #{admin_user.errors.full_messages.join(', ')}"
    end
    admin_user.reload
    puts "DEBUG: After save & reload: Login=#{admin_user.login}, Status=#{admin_user.status}, Admin?=#{admin_user.admin?}, MustChangePasswd?=#{admin_user.must_change_passwd if admin_user.respond_to?(:must_change_passwd)}"

    log_user(admin_user.login, new_password)

    Setting.plugin_redmine_semantic_search = Setting.plugin_redmine_semantic_search.merge('enabled' => '0')

    visit '/'

    within '#top-menu' do
      assert_no_link I18n.t(:label_semantic_search), wait: 3
    end
  end
end
