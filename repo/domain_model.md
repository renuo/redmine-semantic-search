# Semantic Search Domain Model

This Markdown file contains the Mermaid Diagram for the Semantic Search Domain Model. The diagram shows the relationships between Issues, Issue Embeddings, Projects, Users, Trackers and Issue Statuses.

> [!NOTE]
> While Redmine has many other attributes available, only the necessary attributes are shown.

```mermaid
classDiagram
    class Issue {
        +int id
        +string subject
        +text description
        +datetime created_on
        +datetime updated_on
        +int tracker_id
        +int status_id
        +int priority_id
        +int project_id
        +int author_id
        +int assigned_to_id
    }

    class IssueEmbedding {
        +int id
        +int issue_id
        +vector(1536) embedding_vector
        +string content_hash
        +datetime created_at
        +datetime updated_at
        +calculate_content_hash(issue)
        +needs_update?(issue)
    }

    class Project {
        +int id
        +string name
    }

    class User {
        +int id
        +string login
        +string firstname
        +string lastname
    }

    class Tracker {
        +int id
        +string name
    }

    class IssueStatus {
        +int id
        +string name
    }

    class IssuePriority {
        +int id
        +string name
    }

    class Journal {
        +int id
        +int journalized_id
        +string notes
    }

    class TimeEntry {
        +int id
        +int issue_id
        +text comments
    }

    Issue "1" -- "1" IssueEmbedding : has
    Issue "n" -- "1" Project : belongs to
    Issue "n" -- "1" Tracker : has type
    Issue "n" -- "1" IssueStatus : has status
    Issue "n" -- "1" IssuePriority : has priority
    Issue "n" -- "1" User : authored by
    Issue "n" -- "0..1" User : assigned to
    Issue "1" -- "n" Journal : has
    Issue "1" -- "n" TimeEntry : has

    class EmbeddingService {
        +generate_embedding(text)
        +create_or_update_embedding(issue)
        +setup_client()
    }

    class SemanticSearchService {
        +search(query, user, limit)
        -fetch_raw_results(query_embedding, limit)
        -build_search_sql(query_embedding, limit)
        -process_results(results)
        -filter_by_visibility(processed_results, user)
    }

    SemanticSearchService -- EmbeddingService : uses
    SemanticSearchService -- IssueEmbedding : queries
```

## Model Relationships

- **Issue**: Central entity in Redmine, representing a task, bug, feature, etc.
- **IssueEmbedding**: Stores vector embeddings of issue content for semantic search
- **Project**: Container for issues, representing a project or product
- **User**: Represents system users who can author or be assigned to issues
- **Tracker**: Categorizes issues (e.g., Bug, Feature, Task)
- **IssueStatus**: Represents the current state of an issue (e.g., New, In Progress, Resolved)
- **IssuePriority**: Indicates the priority level of an issue
- **Journal**: Stores updates and comments on issues
- **TimeEntry**: Records time spent on issues with optional comments

## Services

- **EmbeddingService**: Handles generation of vector embeddings via OpenAI API
- **SemanticSearchService**: Performs semantic search using vector similarity
