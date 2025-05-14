import streamlit as st
import pandas as pd
import psycopg2
import numpy as np
from dotenv import load_dotenv
import os

load_dotenv()

st.set_page_config(
    page_title="Redmine Embeddings Viewer",
    page_icon="🔍",
    layout="wide"
)

db_params = {
    "host": os.getenv("DB_HOST", "localhost"),
    "database": os.getenv("DB_NAME", "redmine"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "postgres"),
    "port": os.getenv("DB_PORT", "5432")
}

def connect_to_db():
    try:
        conn = psycopg2.connect(**db_params)
        return conn
    except Exception as e:
        st.error(f"Error connecting to the database: {e}")
        return None

def fetch_embeddings(conn, limit=1000, project_id=None, issue_id=None):
    cursor = conn.cursor()

    query = """
    SELECT
        ie.id,
        ie.issue_id,
        ie.model_used,
        ie.original_dimension,
        i.subject,
        p.name as project_name,
        t.name as tracker_name,
        ie.content_hash,
        ie.created_at,
        ie.updated_at,
        ie.embedding_vector
    FROM
        issue_embeddings ie
    JOIN
        issues i ON ie.issue_id = i.id
    JOIN
        projects p ON i.project_id = p.id
    JOIN
        trackers t ON i.tracker_id = t.id
    WHERE 1=1
    """

    params = []

    if project_id:
        query += " AND p.id = %s"
        params.append(project_id)

    if issue_id:
        query += " AND ie.issue_id = %s"
        params.append(issue_id)

    query += f" LIMIT {limit}"

    cursor.execute(query, params)
    columns = [desc[0] for desc in cursor.description]
    data = cursor.fetchall()
    cursor.close()

    return columns, data

def fetch_projects(conn):
    cursor = conn.cursor()
    cursor.execute("SELECT id, name FROM projects ORDER BY name")
    projects = cursor.fetchall()
    cursor.close()
    return projects

def main():
    st.title("🔍 Embeddings Viewer")

    conn = connect_to_db()
    if not conn:
        st.stop()

    st.sidebar.header("Filters")
    projects = fetch_projects(conn)
    project_options = [("All Projects", None)] + [(p[1], p[0]) for p in projects]
    # i dont need project name
    _, selected_project_id = st.sidebar.selectbox(
        "Select Project",
        options=project_options,
        format_func=lambda x: x[0]
    )

    issue_id = st.sidebar.text_input("Issue ID (optional)", "")
    issue_id = int(issue_id) if issue_id.isdigit() else None

    limit = st.sidebar.slider("Max Embeddings to Show", 10, 14000, 100)

    columns, data = fetch_embeddings(conn, limit, selected_project_id, issue_id)

    df = pd.DataFrame(data, columns=columns)

    st.subheader("Embeddings Data")

    display_df = df.drop(columns=['embedding_vector'])
    st.dataframe(display_df)

    if not df.empty:
        # show sample
        st.subheader("Random Embedding Vector (first 10 dimensions)")
        sample_vector = df.iloc[0]['embedding_vector']
        if isinstance(sample_vector, str):
            try:
                sample_vector = eval(sample_vector)
            except:
                sample_vector = sample_vector[:100] + "..."

        if isinstance(sample_vector, list) or isinstance(sample_vector, np.ndarray):
            st.write(sample_vector[:10])
        else:
            st.write("Embedding vector format not recognized")

    conn.close()

if __name__ == "__main__":
    main()
