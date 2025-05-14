class AddModelUsed < ActiveRecord::Migration[6.1]
  def change
    add_column :issue_embeddings, :model_used, :string
  end
end
