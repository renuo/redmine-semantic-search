class UpdateExistingEmbeddingsForPca < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:issue_embeddings) &&
                  column_exists?(:issue_embeddings, :embedding_vector)

    unless column_exists?(:issue_embeddings, :original_dimension)
      add_column :issue_embeddings, :original_dimension, :integer, default: 1536
    end

    execute "SELECT id, issue_id FROM issue_embeddings WHERE embedding_vector IS NOT NULL"
  end
end
