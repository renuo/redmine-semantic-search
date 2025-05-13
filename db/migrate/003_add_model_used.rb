class AddModelUsed < ActiveRecord::Migration[7.2]
  def change
    add_column :issue_embeddings, :model_used, :string
  end
end
