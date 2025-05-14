require_relative "semantic_search_result_processor"

class SemanticSearchService
  include SemanticSearchResultProcessor

  def initialize
    @embedding_service = EmbeddingService.new
  end

  def search(query, user, limit = 10, _debug: false)
    Rails.logger.info("Performing semantic search for query: #{query}")

    query_embedding, original_dimension = @embedding_service.generate_embedding(query)

    log_msg = "Query embedding generated with dim: #{query_embedding.length}, " \
              "original: #{original_dimension}"
    Rails.logger.info(log_msg)

    query_embedding = DimensionReductionService.validate_vector_dimension(
      query_embedding,
      EmbeddingService::TARGET_DIMENSION
    )

    Rails.logger.info("Validated query embedding dimension: #{query_embedding.length}")

    results = fetch_raw_results(query_embedding, limit)
    processed_results = process_results(results)

    Rails.logger.info("Found #{processed_results.length} results before visibility filtering")

    filtered_results = filter_by_visibility(processed_results, user)

    Rails.logger.info("Returning #{filtered_results.length} visible results")

    filtered_results
  end

  private

  def fetch_raw_results(query_embedding, limit)
    sql = build_search_sql(query_embedding, limit)

    sql.gsub(/ARRAY\[.*?\]::vector/, "ARRAY[...vector values...]::vector")

    begin
      ActiveRecord::Base.connection.execute(sql)
    rescue StandardError
      begin
        db_dim_query = <<~SQL.squish
          SELECT pg_catalog.format_type(atttypid, atttypmod-4)
          FROM pg_catalog.pg_attribute
          WHERE attrelid = 'issue_embeddings'::regclass AND attname = 'embedding_vector'
        SQL
        db_dimension = ActiveRecord::Base.connection.execute(db_dim_query).first["format_type"]

        Rails.logger.error("Database column type: #{db_dimension}")
        Rails.logger.error("Provided vector length: #{query_embedding.length}")
      rescue StandardError => debug_error
        Rails.logger.error("Error getting debug info: #{debug_error.message}")
      end

      raise
    end
  end

  # rubocop:disable Metrics/MethodLength
  def build_search_sql(query_embedding, limit)
    vector_string = query_embedding.join(",")

    <<-SQL
      SELECT issue_embeddings.issue_id,
             issues.subject,
             issues.description,
             projects.name AS project_name,
             issues.created_on,
             issues.updated_on,
             issues.tracker_id,
             trackers.name AS tracker_name,
             issue_statuses.name AS status_name,
             enumerations.name AS priority_name,
             author_users.firstname AS author_firstname,
             author_users.lastname AS author_lastname,
             author_users.login AS author_login,
             assigned_users.firstname AS assigned_to_firstname,
             assigned_users.lastname AS assigned_to_lastname,
             assigned_users.login AS assigned_to_login,
             issue_embeddings.embedding_vector <-> ARRAY[#{vector_string}]::vector(#{EmbeddingService::TARGET_DIMENSION}) AS distance
      FROM issue_embeddings
      INNER JOIN issues ON issues.id = issue_embeddings.issue_id
      INNER JOIN projects ON projects.id = issues.project_id
      INNER JOIN trackers ON trackers.id = issues.tracker_id
      INNER JOIN issue_statuses ON issue_statuses.id = issues.status_id
      INNER JOIN enumerations ON enumerations.id = issues.priority_id AND enumerations.type = 'IssuePriority'
      INNER JOIN users AS author_users ON author_users.id = issues.author_id
      LEFT JOIN users AS assigned_users ON assigned_users.id = issues.assigned_to_id
      WHERE issue_embeddings.embedding_vector IS NOT NULL
      ORDER BY distance ASC
      LIMIT #{limit}
    SQL
  end
  # rubocop:enable Metrics/MethodLength

  def filter_by_visibility(processed_results, user)
    issue_ids = processed_results.map { |r| r["issue_id"] }
    visible_issues = Issue.where(id: issue_ids).visible(user)
    visible_issue_ids = visible_issues.pluck(:id).map(&:to_s)

    processed_results.select { |r| visible_issue_ids.include?(r["issue_id"].to_s) }
  end
end
