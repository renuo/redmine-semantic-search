require File.expand_path('../../test_helper', __FILE__)

class SemanticSearchServiceTest < ActiveSupport::TestCase
  fixtures :issues, :users, :projects, :trackers, :issue_statuses, :enumerations, :journals, :time_entries

  def setup
    @mock_embedding_service = mock('EmbeddingService')
    EmbeddingService.stubs(:new).returns(@mock_embedding_service)

    @service = SemanticSearchService.new
    @user = User.find(1)
    @query = "test search query"
    @query_embedding = Array.new(2000) { rand }
  end

  def test_search
    @mock_embedding_service.expects(:generate_embedding).with(@query).returns(@query_embedding)

    issue = Issue.find(1)
    embedding = IssueEmbedding.new(
      issue: issue,
      embedding_vector: Array.new(2000) { rand },
      content_hash: 'test_hash',
      model_used: 'text-embedding-ada-002'
    )
    embedding.save!

    mock_results = [
      {
        'issue_id' => issue.id.to_s,
        'subject' => issue.subject,
        'description' => issue.description,
        'project_name' => issue.project.name,
        'created_on' => issue.created_on.to_s,
        'updated_on' => issue.updated_on.to_s,
        'tracker_id' => issue.tracker_id.to_s,
        'tracker_name' => issue.tracker.name,
        'status_name' => issue.status.name,
        'priority_name' => issue.priority.name,
        'author_firstname' => issue.author.firstname,
        'author_lastname' => issue.author.lastname,
        'author_login' => issue.author.login,
        'assigned_to_firstname' => issue.assigned_to&.firstname,
        'assigned_to_lastname' => issue.assigned_to&.lastname,
        'assigned_to_login' => issue.assigned_to&.login,
        'distance' => '0.1'
      }
    ]

    ActiveRecord::Base.connection.stubs(:execute).returns(mock_results)

    results = @service.search(@query, @user)

    assert_equal 1, results.size
    result = results.first
    assert_equal issue.id.to_s, result['issue_id']
    assert_equal issue.subject, result['subject']
    assert_equal issue.project.name, result['project_name']

    assert_nil result['distance']
    assert_nil result['author_firstname']
    assert_nil result['author_lastname']

    if issue.author.firstname.present? || issue.author.lastname.present?
      expected_author_name = [issue.author.firstname, issue.author.lastname].join(" ").strip
      assert_equal expected_author_name, result['author_name']
    else
      assert_equal issue.author.login, result['author_name']
    end

    assert_in_delta 0.909, result['similarity_score'], 0.001
  end

  def test_filter_by_visibility
    @mock_embedding_service.expects(:generate_embedding).with(@query).returns(@query_embedding)

    visible_issue = Issue.find(1)
    invisible_issue = Issue.find(2)

    visible_embedding = IssueEmbedding.new(
      issue: visible_issue,
      embedding_vector: Array.new(2000) { rand },
      content_hash: 'visible_hash',
      model_used: 'text-embedding-ada-002'
    )
    visible_embedding.save!

    invisible_embedding = IssueEmbedding.new(
      issue: invisible_issue,
      embedding_vector: Array.new(2000) { rand },
      content_hash: 'invisible_hash',
      model_used: 'text-embedding-ada-002'
    )
    invisible_embedding.save!

    regular_user = User.find(2)

    mock_results = [
      {
        'issue_id' => visible_issue.id.to_s,
        'subject' => visible_issue.subject,
        'description' => visible_issue.description,
        'project_name' => visible_issue.project.name,
        'created_on' => visible_issue.created_on.to_s,
        'updated_on' => visible_issue.updated_on.to_s,
        'tracker_id' => visible_issue.tracker_id.to_s,
        'tracker_name' => visible_issue.tracker.name,
        'status_name' => visible_issue.status.name,
        'priority_name' => visible_issue.priority.name,
        'author_firstname' => visible_issue.author.firstname,
        'author_lastname' => visible_issue.author.lastname,
        'author_login' => visible_issue.author.login,
        'assigned_to_firstname' => visible_issue.assigned_to&.firstname,
        'assigned_to_lastname' => visible_issue.assigned_to&.lastname,
        'assigned_to_login' => visible_issue.assigned_to&.login,
        'distance' => '0.1'
      },
      {
        'issue_id' => invisible_issue.id.to_s,
        'subject' => invisible_issue.subject,
        'description' => invisible_issue.description,
        'project_name' => invisible_issue.project.name,
        'created_on' => invisible_issue.created_on.to_s,
        'updated_on' => invisible_issue.updated_on.to_s,
        'tracker_id' => invisible_issue.tracker_id.to_s,
        'tracker_name' => invisible_issue.tracker.name,
        'status_name' => invisible_issue.status.name,
        'priority_name' => invisible_issue.priority.name,
        'author_firstname' => invisible_issue.author.firstname,
        'author_lastname' => invisible_issue.author.lastname,
        'author_login' => invisible_issue.author.login,
        'assigned_to_firstname' => invisible_issue.assigned_to&.firstname,
        'assigned_to_lastname' => invisible_issue.assigned_to&.lastname,
        'assigned_to_login' => invisible_issue.assigned_to&.login,
        'distance' => '0.2'
      }
    ]

    ActiveRecord::Base.connection.stubs(:execute).returns(mock_results)

    mock_relation = mock('ActiveRecord::Relation')
    Issue.expects(:where).with(id: [visible_issue.id.to_s, invisible_issue.id.to_s]).returns(mock_relation)
    mock_relation.expects(:visible).with(regular_user).returns([visible_issue])

    results = @service.search(@query, regular_user)

    assert_equal 1, results.size
    assert_equal visible_issue.id.to_s, results.first['issue_id']
  end

  def test_search_with_empty_results
    @mock_embedding_service.expects(:generate_embedding).with(@query).returns(@query_embedding)

    ActiveRecord::Base.connection.stubs(:execute).returns([])

    results = @service.search(@query, @user)

    assert_equal 0, results.size
    assert_equal [], results
  end

  def test_search_with_limit
    @mock_embedding_service.expects(:generate_embedding).with(@query).returns(@query_embedding)

    custom_limit = 5
    @service.expects(:build_search_sql).with(@query_embedding, custom_limit).returns("SELECT 1")
    ActiveRecord::Base.connection.stubs(:execute).returns([])

    @service.search(@query, @user, custom_limit)
  end

  def test_search_handles_embedding_error
    @mock_embedding_service.expects(:generate_embedding)
                           .with(@query)
                           .raises(EmbeddingService::EmbeddingError.new("Embedding generation failed"))

    assert_raises(EmbeddingService::EmbeddingError) do
      @service.search(@query, @user)
    end
  end

  def test_search_handles_database_error
    @mock_embedding_service.expects(:generate_embedding).with(@query).returns(@query_embedding)

    @service.expects(:build_search_sql).with(@query_embedding, 10).returns("SELECT 1")
    ActiveRecord::Base.connection.stubs(:execute)
                                .raises(ActiveRecord::StatementInvalid.new("Database query failed"))

    assert_raises(ActiveRecord::StatementInvalid) do
      @service.search(@query, @user)
    end
  end
end
