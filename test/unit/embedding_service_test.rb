require File.expand_path('../../test_helper', __FILE__)

class EmbeddingServiceTest < ActiveSupport::TestCase
  fixtures :issues, :journals, :time_entries

  def setup
    ENV['OPENAI_API_KEY'] = 'test_api_key'

    @mock_client = mock('OpenAI::Client')
    OpenAI::Client.stubs(:new).returns(@mock_client)

    @service = EmbeddingService.new
  end

  def teardown
    ENV.delete('OPENAI_API_KEY')
  end

  def test_initialize_raises_error_without_api_key
    ENV.delete('OPENAI_API_KEY')
    assert_raises(EmbeddingService::EmbeddingError) do
      EmbeddingService.new
    end
  end

  def test_generate_embedding
    mock_embedding = Array.new(2000) { rand }
    mock_response = {
      "data" => [
        {
          "embedding" => mock_embedding,
          "index" => 0,
          "object" => "embedding"
        }
      ],
      "model" => "text-embedding-ada-002",
      "object" => "list",
      "usage" => {
        "prompt_tokens" => 5,
        "total_tokens" => 5
      }
    }

    @mock_client.expects(:embeddings).with(
      parameters: {
        model: "text-embedding-ada-002",
        input: "Test text"
      }
    ).returns(mock_response)

    result = @service.generate_embedding("Test text")
    assert_equal mock_embedding, result
  end

  def test_generate_embedding_handles_error_response
    mock_error_response = {
      "error" => {
        "message" => "The API key is invalid",
        "type" => "invalid_request_error",
        "param" => nil,
        "code" => "invalid_api_key"
      }
    }

    @mock_client.expects(:embeddings).returns(mock_error_response)

    assert_raises(EmbeddingService::EmbeddingError) do
      @service.generate_embedding("Test text")
    end
  end

  def test_generate_embedding_handles_network_error
    @mock_client.expects(:embeddings).raises(Faraday::Error.new("Connection failed"))

    assert_raises(EmbeddingService::EmbeddingError) do
      @service.generate_embedding("Test text")
    end
  end

  def test_prepare_issue_content
    issue = Issue.find(1)

    issue.update_columns(
      subject: 'Test subject',
      description: 'Test description'
    )

    Journal.where(journalized: issue).delete_all
    Journal.connection.execute(
      "INSERT INTO journals (journalized_id, journalized_type, user_id, notes, created_on) VALUES (#{issue.id}, 'Issue', 2, 'Test comment', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')"
    )

    TimeEntry.where(issue_id: issue.id).delete_all
    TimeEntry.connection.execute(
      "INSERT INTO time_entries (project_id, user_id, issue_id, hours, activity_id, spent_on, comments, tyear, tmonth, tweek, created_on, updated_on) VALUES (#{issue.project_id}, 2, #{issue.id}, 1, 9, '#{Date.today.strftime('%Y-%m-%d')}', 'Test time entry comment', #{Date.today.year}, #{Date.today.month}, #{Date.today.cweek}, '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}', '#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}')"
    )

    issue.reload

    content = @service.prepare_issue_content(issue)

    assert_includes content, "Issue ##{issue.id} - Test subject"
    assert_includes content, "Description: Test description"
    assert_includes content, "Comment: Test comment"
    assert_includes content, "Time entry note: Test time entry comment"
  end

  def test_pad_embedding_nil_vector
    assert_nil @service.pad_embedding(nil)
  end

  def test_pad_embedding_vector_gt_max_dimension
    vector = Array.new(EmbeddingService::MAX_DIMENSION + 1, 1.0)
    assert_equal vector, @service.pad_embedding(vector)
  end

  def test_pad_embedding_vector_eq_max_dimension
    vector = Array.new(EmbeddingService::MAX_DIMENSION, 1.0)
    assert_equal vector, @service.pad_embedding(vector)
  end

  def test_pad_embedding_vector_lt_max_dimension
    vector = [1.0, 2.0]
    expected_vector = [1.0, 2.0] + Array.new(EmbeddingService::MAX_DIMENSION - 2, 0.0)
    assert_equal expected_vector, @service.pad_embedding(vector)
  end

  def test_model_dimensions_nomic
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = { "embedding_model" => "nomic-embed-text" }
    assert_equal 768, @service.model_dimensions
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
  end

  def test_model_dimensions_openai
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = { "embedding_model" => "text-embedding-ada-002" }
    assert_equal 1536, @service.model_dimensions
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
  end

  def test_model_dimensions_default_unknown_model
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = { "embedding_model" => "unknown-model" }
    assert_equal 2000, @service.model_dimensions
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
  end

  def test_model_dimensions_setting_key_not_present
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = {}
    assert_equal 1536, @service.model_dimensions # Defaults to "text-embedding-ada-002"
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
  end

  def test_model_dimensions_settings_are_nil
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = nil
    assert_equal 1536, @service.model_dimensions # Defaults to "text-embedding-ada-002"
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
  end

  def test_prepare_issue_content_with_minimal_data
    issue = Issue.new(id: 123, subject: 'Minimal Subject')
    issue.description = nil
    issue.stubs(:journals).returns([])
    issue.stubs(:time_entries).returns([])

    expected_content = "Issue #123 - Minimal Subject\nDescription:"
    assert_equal expected_content, @service.prepare_issue_content(issue)
  end

  def test_prepare_issue_content_with_empty_and_nil_journal_notes
    issue = Issue.find(1)
    issue.journals.destroy_all
    issue.update_columns(subject: 'Journal Test', description: 'Journal test desc')

    Journal.create!(journalized: issue, user_id: 2, notes: nil)
    Journal.create!(journalized: issue, user_id: 2, notes: '')
    Journal.create!(journalized: issue, user_id: 2, notes: 'Actual comment')

    issue.reload
    issue.stubs(:time_entries).returns([])

    content = @service.prepare_issue_content(issue)
    assert_includes content, "Issue ##{issue.id} - Journal Test"
    assert_includes content, "Description: Journal test desc"
    assert_includes content, "Comment: Actual comment"
    assert_equal 1, content.scan(/Comment:/).count
    assert_equal 3, content.lines.count
  end

  def test_prepare_issue_content_with_empty_and_nil_time_entry_comments
    issue = Issue.find(1)
    issue.time_entries.destroy_all
    issue.update_columns(subject: 'Time Entry Test', description: 'Time entry test desc')

    TimeEntry.create!(project_id: issue.project_id, user_id: 2, issue_id: issue.id, hours: 1, activity_id: 9, spent_on: Date.today, comments: nil)
    TimeEntry.create!(project_id: issue.project_id, user_id: 2, issue_id: issue.id, hours: 1, activity_id: 9, spent_on: Date.today, comments: '')
    TimeEntry.create!(project_id: issue.project_id, user_id: 2, issue_id: issue.id, hours: 1, activity_id: 9, spent_on: Date.today, comments: 'Actual time entry')

    issue.reload
    issue.stubs(:journals).returns([])

    content = @service.prepare_issue_content(issue)
    assert_includes content, "Issue ##{issue.id} - Time Entry Test"
    assert_includes content, "Description: Time entry test desc"
    assert_includes content, "Time entry note: Actual time entry"
    assert_equal 1, content.scan(/Time entry note:/).count
    assert_equal 4, content.lines.count
  end

  def test_base_url_uses_setting_if_present
    original_settings = Setting.plugin_redmine_semantic_search
    custom_url = "http://localhost:8080/v1"
    Setting.plugin_redmine_semantic_search = { "base_url" => custom_url }

    OpenAI::Client.expects(:new).with(access_token: 'test_api_key', uri_base: custom_url).returns(mock('OpenAI::Client'))
    service = EmbeddingService.new
    assert_not_nil service, "Service should be initialized"
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
    OpenAI::Client.unstub(:new)
    OpenAI::Client.stubs(:new).returns(@mock_client)
  end

  def test_base_url_uses_default_if_setting_not_present
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = {}
    default_url = "https://api.openai.com/v1"

    OpenAI::Client.expects(:new).with(access_token: 'test_api_key', uri_base: default_url).returns(mock('OpenAI::Client'))
    service = EmbeddingService.new
    assert_not_nil service, "Service should be initialized"
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
    OpenAI::Client.unstub(:new)
    OpenAI::Client.stubs(:new).returns(@mock_client)
  end

  def test_base_url_uses_default_if_setting_is_nil
    original_settings = Setting.plugin_redmine_semantic_search
    Setting.plugin_redmine_semantic_search = nil
    default_url = "https://api.openai.com/v1"

    OpenAI::Client.expects(:new).with(access_token: 'test_api_key', uri_base: default_url).returns(mock('OpenAI::Client'))
    service = EmbeddingService.new
    assert_not_nil service, "Service should be initialized"
  ensure
    Setting.plugin_redmine_semantic_search = original_settings
    OpenAI::Client.unstub(:new)
    OpenAI::Client.stubs(:new).returns(@mock_client)
  end
end
