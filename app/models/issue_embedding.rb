class IssueEmbedding < ActiveRecord::Base
  belongs_to :issue

  # we can do this using neighbor gem (+ pgvector)
  has_neighbors :embedding_vector

  validates :issue, presence: true
  validates :embedding_vector, presence: true
  validates :content_hash, presence: true

  def self.calculate_content_hash(issue)
    content = [
      issue.subject,
      issue.description,
      issue.journals.map { |j| j.notes if j.notes.present? }.compact.join(" "),
      issue.time_entries.map { |te| te.comments if te.comments.present? }.compact.join(" ")
    ].join(" ")

    Digest::SHA256.hexdigest(content)
  end

  def needs_update?(issue)
    content_hash != self.class.calculate_content_hash(issue)
  end
end
