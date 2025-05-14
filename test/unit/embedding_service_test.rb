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
    mock_embedding = Array.new(1536) { rand }
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

    result, original_dimension = @service.generate_embedding("Test text")
    assert_equal 2000, result.length
    assert_equal 1536, original_dimension
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

  def test_pad_embedding
    vector = Array.new(1000) { 0.1 }
    result = @service.pad_embedding(vector)
    assert_equal EmbeddingService::MAX_DIMENSION, result.length

    vector = Array.new(EmbeddingService::MAX_DIMENSION) { 0.1 }
    result = @service.pad_embedding(vector)
    assert_equal EmbeddingService::MAX_DIMENSION, result.length
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
end
