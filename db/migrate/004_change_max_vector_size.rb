class ChangeMaxVectorSize < ActiveRecord::Migration[6.1]
  def up
    execute "DROP INDEX IF EXISTS issue_embeddings_vector_idx"
    execute "ALTER TABLE issue_embeddings ALTER COLUMN embedding_vector TYPE vector(2000)"
    execute "CREATE INDEX issue_embeddings_vector_idx ON issue_embeddings USING ivfflat (embedding_vector vector_l2_ops) WITH (lists = 100)"
  end

  def down
    execute "DROP INDEX IF EXISTS issue_embeddings_vector_idx"
    execute "ALTER TABLE issue_embeddings ALTER COLUMN embedding_vector TYPE vector(1536)"
    execute "CREATE INDEX issue_embeddings_vector_idx ON issue_embeddings USING ivfflat (embedding_vector vector_l2_ops) WITH (lists = 100)"
  end
end
