require "ruby/openai"

class EmbeddingService
  class EmbeddingError < StandardError; end

  MAX_DIMENSION = 1536

  def initialize
    @client = OpenAI::Client.new(access_token: api_key, uri_base: base_url)
  end

  # Generate embeddings for a given text
  def generate_embedding(text)
    response = @client.embeddings(
      parameters: {
        model: embedding_model,
        input: text
      }
    )

    if response["error"]
      Rails.logger.error("OpenAI API error: #{response['error']}")
      raise EmbeddingError, "Failed to generate embedding: #{response['error']['message']}"
    end

    pad_embedding(response.dig("data", 0, "embedding"))
  rescue Faraday::Error => e
    Rails.logger.error("OpenAI API connection error: #{e.message}")
    raise EmbeddingError, "Connection error while generating embedding: #{e.message}"
  end

  def pad_embedding(vector)
    return vector if vector.nil? || vector.length >= MAX_DIMENSION

    vector + Array.new(MAX_DIMENSION - vector.length, 0.0)
  end

  def model_dimensions
    # we have different vector sizes for different models
    case embedding_model
    when "nomic-embed-text" # ollama
      768
    when "text-embedding-ada-002" # openai
      1536
    # rubocop:disable Lint/DuplicateBranch
    else
      1536
    end
    # rubocop:enable Lint/DuplicateBranch
  end

  def prepare_issue_content(issue)
    [
      "Issue ##{issue.id} - #{issue.subject}",
      "Description: #{issue.description}",
      issue.journals.map { |j| "Comment: #{j.notes}" if j.notes.present? }.compact.join("\n"),
      issue.time_entries.map { |te| "Time entry note: #{te.comments}" if te.comments.present? }.compact.join("\n")
    ].join("\n").strip
  end

  private

  def api_key
    key = ENV.fetch("OPENAI_API_KEY", nil)
    raise EmbeddingError, "OpenAI API key not found. Please set OPENAI_API_KEY environment variable." if key.blank?

    key
  end

  def base_url
    Setting.plugin_semantic_search["base_url"] || "https://api.openai.com/v1"
  end

  def embedding_model
    Setting.plugin_semantic_search["embedding_model"] || "text-embedding-ada-002"
  end
end
