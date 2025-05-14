class UpdateVectorDimensionForPca < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:issue_embeddings, :original_dimension)
      add_column :issue_embeddings, :original_dimension, :integer, default: 1536
    end
  end
end
