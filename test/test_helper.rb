require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

require 'mocha/minitest'

ActiveJob::Base.queue_adapter = :test

class EmbeddingServiceMock
  def initialize
    # TODO: is no init necessary?
  end

  def generate_embedding(text)
    vector = Array.new(1536) { 0.1 }
    reduced_vector = DimensionReductionService.reduce_dimensions(
      DimensionReductionService.pad_vector(vector, 5500),
      5500,
      2000
    )
    return reduced_vector, 1536
  end

  def prepare_issue_content(issue)
    [
      "Issue ##{issue.id} - #{issue.subject}",
      "Description: #{issue.description}",
      issue.journals.map { |j| "Comment: #{j.notes}" if j.notes.present? }.compact.join("\n"),
      issue.time_entries.map { |te| "Time entry note: #{te.comments}" if te.comments.present? }.compact.join("\n")
    ].join("\n").strip
  end
end

ActiveSupport::TestCase.setup do |test|
  # TODO: implement?
end
