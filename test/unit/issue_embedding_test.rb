require File.expand_path('../../test_helper', __FILE__)

class IssueEmbeddingTest < ActiveSupport::TestCase
  fixtures :projects, :users, :issues, :journals, :time_entries

  def setup
    @issue = Issue.find(1)
    @embedding = IssueEmbedding.new(
      issue: @issue,
      embedding_vector: [0.1] * 2000,
      content_hash: 'test_hash',
      model_used: 'text-embedding-ada-002'
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

    @embedding.embedding_vector = [0.1] * 2000
    @embedding.content_hash = nil
    assert_not @embedding.valid?
    assert_includes @embedding.errors[:content_hash], 'cannot be blank'
  end

  def test_calculate_content_hash_all_variations
    issue = Issue.find(1)
    issue.journals.destroy_all
    issue.time_entries.destroy_all

    issue_subject = 'Subject for hash calculation with variations'
    issue_description = 'Description for hash calculation with variations'
    issue.update_columns(
      subject: issue_subject,
      description: issue_description
    )

    journal_note1 = 'First journal note present.'
    journal_note2 = 'Second journal note present.'
    Journal.create!(journalized: issue, user_id: User.find(2).id, notes: nil) # Should be skipped by .present?
    Journal.create!(journalized: issue, user_id: User.find(2).id, notes: journal_note1)
    Journal.create!(journalized: issue, user_id: User.find(2).id, notes: '') # Should be skipped by .present?
    Journal.create!(journalized: issue, user_id: User.find(2).id, notes: journal_note2)

    time_comment1 = 'First time entry comment present.'
    time_comment2 = 'Second time entry comment present.'
    activity_id = TimeEntryActivity.find(9).id
    project_id = issue.project_id

    TimeEntry.create!(issue: issue, user_id: User.find(2).id, hours: 1, spent_on: Date.today, activity_id: activity_id, project_id: project_id, comments: nil)
    TimeEntry.create!(issue: issue, user_id: User.find(2).id, hours: 1, spent_on: Date.today, activity_id: activity_id, project_id: project_id, comments: time_comment1)
    TimeEntry.create!(issue: issue, user_id: User.find(2).id, hours: 1, spent_on: Date.today, activity_id: activity_id, project_id: project_id, comments: '')
    TimeEntry.create!(issue: issue, user_id: User.find(2).id, hours: 1, spent_on: Date.today, activity_id: activity_id, project_id: project_id, comments: time_comment2)

    issue.reload

    expected_journal_notes_string = [journal_note1, journal_note2].join(" ")
    expected_time_comments_string = [time_comment1, time_comment2].join(" ")

    expected_content_parts = [
      issue.subject,
      issue.description,
      expected_journal_notes_string,
      expected_time_comments_string
    ]
    expected_content = expected_content_parts.join(" ")
    expected_hash = Digest::SHA256.hexdigest(expected_content)

    calculated_hash = IssueEmbedding.calculate_content_hash(issue)
    assert_equal expected_hash, calculated_hash
  end

  def test_calculate_content_hash_with_no_journals_or_time_entries
    project = Project.find(1)
    tracker = Tracker.first || Tracker.create(name: 'Test Tracker', default_status_id: IssueStatus.first.id)
    author = User.find(1)
    status = IssueStatus.first || IssueStatus.create(name: 'New')
    priority = IssuePriority.first || IssuePriority.create(name: 'Normal')

    issue_subject = 'Subject for no journals/time entries'
    issue_description = 'Description for no journals/time entries'

    issue = Issue.create!(
      project: project,
      tracker: tracker,
      author: author,
      status: status,
      priority: priority,
      subject: issue_subject,
      description: issue_description
    )

    issue.reload

    expected_journal_notes_string = ""
    expected_time_comments_string = ""

    expected_content_parts = [
      issue.subject,
      issue.description,
      expected_journal_notes_string,
      expected_time_comments_string
    ]
    expected_content = expected_content_parts.join(" ")
    expected_hash = Digest::SHA256.hexdigest(expected_content)

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
      embedding_vector: [0.1] * 2000,
      content_hash: current_hash,
      model_used: 'text-embedding-ada-002'
    )

    assert_not embedding.needs_update?(issue)

    issue.update!(subject: 'Updated subject')

    assert embedding.needs_update?(issue)
  end
end
