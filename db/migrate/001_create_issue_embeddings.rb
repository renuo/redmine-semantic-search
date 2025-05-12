class CreateIssueEmbeddings < ActiveRecord::Migration[7.2]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    create_table :issue_embeddings do |t|
      t.references :issue, null: false, foreign_key: true
      t.text :content_hash
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    execute "ALTER TABLE issue_embeddings ADD COLUMN embedding_vector vector(1536)"

    execute "CREATE INDEX issue_embeddings_vector_idx ON issue_embeddings USING ivfflat (embedding_vector vector_l2_ops) WITH (lists = 100)"
  end

  def down
    drop_table :issue_embeddings
  end
end
