module SemanticSearchResultProcessor
  extend self

  def process_results(results)
    results.map do |result|
      result = process_author_info(result)
      result = process_assignee_info(result)
      result = calculate_similarity_score(result)
      remove_temporary_fields(result)
    end
  end

  private

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
end
