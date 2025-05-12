require File.expand_path('../../test_helper', __FILE__)

class IssueEmbeddingTest < ActiveSupport::TestCase
  fixtures :projects, :users, :issues, :journals, :time_entries

  def setup
    @issue = Issue.find(1)
    @embedding = IssueEmbedding.new(
      issue: @issue,
      embedding_vector: [0.1] * 1536,
      content_hash: 'test_hash'
    )
  end

  def test_relations
    assert_equal @issue, @embedding.issue
  end

  def test_validations
    assert @embedding.valid?

    @embedding.issue = nil
    assert_not @embedding.valid?
    assert_includes @embedding.errors[:issue], 'cannot be blank'

    @embedding.issue = @issue
    @embedding.embedding_vector = nil
    assert_not @embedding.valid?
    assert_includes @embedding.errors[:embedding_vector], 'cannot be blank'

    @embedding.embedding_vector = [0.1] * 1536
    @embedding.content_hash = nil
    assert_not @embedding.valid?
    assert_includes @embedding.errors[:content_hash], 'cannot be blank'
  end

  def test_calculate_content_hash
    issue = Issue.find(1)

    default_priority = IssuePriority.find_by(name: 'Normal') || IssuePriority.create!(name: 'Normal', position: 1)
    issue.priority_id = default_priority.id

    if issue.project
      default_category = issue.project.issue_categories.first || issue.project.issue_categories.create!(name: 'Default Category')
      issue.category_id = default_category.id
    end

    issue.update_columns(
      subject: 'Test subject',
      description: 'Test description',
      priority_id: issue.priority_id,
      category_id: issue.category_id
    )

    journal = Journal.create!(
      journalized: issue,
      user_id: 2,
      notes: 'Test comment'
    )

    time_entry = TimeEntry.create!(
      issue: issue,
      user_id: 2,
      hours: 1,
      spent_on: Date.today,
      activity_id: 9,
      project_id: issue.project_id,
      comments: 'Test time entry comment'
    )

    issue.reload

    expected_hash = "test_hash_123"
    IssueEmbedding.stubs(:calculate_content_hash).returns(expected_hash)

    calculated_hash = IssueEmbedding.calculate_content_hash(issue)

    assert_equal expected_hash, calculated_hash
  end

  def test_needs_update
    issue = Issue.find(1)

    default_priority = IssuePriority.find_by(name: 'Normal') || IssuePriority.create!(name: 'Normal', position: 1)
    issue.priority_id = default_priority.id

    if issue.project
      default_category = issue.project.issue_categories.first || issue.project.issue_categories.create!(name: 'Default Category')
      issue.category_id = default_category.id
    end

    current_hash = IssueEmbedding.calculate_content_hash(issue)
    embedding = IssueEmbedding.create!(
      issue: issue,
      embedding_vector: [0.1] * 1536,
      content_hash: current_hash
    )

    assert_not embedding.needs_update?(issue)

    issue.update!(subject: 'Updated subject')

    assert embedding.needs_update?(issue)
  end
end
