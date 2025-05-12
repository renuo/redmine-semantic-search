class SemanticSearchService
  def initialize
    @embedding_service = EmbeddingService.new
  end

  def search(query, user, limit = 10)
    query_embedding = @embedding_service.generate_embedding(query)
    results = fetch_raw_results(query_embedding, limit)
    processed_results = process_results(results)
    filter_by_visibility(processed_results, user)
  end

  private

  def fetch_raw_results(query_embedding, limit)
    sql = build_search_sql(query_embedding, limit)
    ActiveRecord::Base.connection.execute(sql)
  end

  def build_search_sql(query_embedding, limit)
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
             issue_embeddings.embedding_vector <-> ARRAY[#{query_embedding.join(',')}]::vector AS distance
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

  def process_results(results)
    results.map do |result|
      result = process_author_info(result)
      result = process_assignee_info(result)
      result = calculate_similarity_score(result)
      remove_temporary_fields(result)
    end
  end

  def process_author_info(result)
    result["author_name"] = [result["author_firstname"], result["author_lastname"]].join(" ").strip
    result["author_name"] = result["author_login"] if result["author_name"].blank?
    result
  end

  def process_assignee_info(result)
    if result["assigned_to_firstname"] || result["assigned_to_lastname"] || result["assigned_to_login"]
      result["assigned_to_name"] = [result["assigned_to_firstname"], result["assigned_to_lastname"]].join(" ").strip
      result["assigned_to_name"] = result["assigned_to_login"] if result["assigned_to_name"].blank?
    else
      result["assigned_to_name"] = nil
    end
    result
  end

  def calculate_similarity_score(result)
    distance = result["distance"].to_f
    result["similarity_score"] = 1.0 / (1.0 + distance)
    result
  end

  def remove_temporary_fields(result)
    %w[author_firstname author_lastname author_login assigned_to_firstname assigned_to_lastname assigned_to_login
       distance].each do |key|
      result.delete(key)
    end
    result
  end

  def filter_by_visibility(processed_results, user)
    issue_ids = processed_results.map { |r| r["issue_id"] }
    visible_issues = Issue.where(id: issue_ids).visible(user)
    visible_issue_ids = visible_issues.pluck(:id).map(&:to_s)

    processed_results.select { |r| visible_issue_ids.include?(r["issue_id"].to_s) }
  end
end
