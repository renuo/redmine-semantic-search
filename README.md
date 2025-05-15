# Semantic Search Plugin for Redmine

[![CI](https://github.com/renuo/redmine_semantic_search/actions/workflows/ci.yml/badge.svg)](https://github.com/renuo/redmine_semantic_search/actions/workflows/ci.yml)
[![Tests](https://github.com/renuo/redmine_semantic_search/actions/workflows/test.yml/badge.svg)](https://github.com/renuo/redmine_semantic_search/actions/workflows/test.yml)

This Redmine plugin enables AI-based semantic search functionality using OpenAI embeddings and PostgreSQL's pgvector extension. It allows users to search for tickets using natural language queries rather than exact keyword matches.

## Features

- Semantic search across issue content (subject, description, comments, time entries)
- Vector similarity search using OpenAI embeddings
- Background processing for embedding generation
- Role-based access control (Developer and Manager roles)
- Compatible with Redmine 5.1.x and 6.0.x

## Domain Model

For the rendered Mermaid Domain Model, have a look at [this file](repo/domain_model.md).

## Requirements

- PostgreSQL installed
- Valid OpenAI API key

More information in [Setup Guide](#installation).

## Installation

Check out [SETUP.md](SETUP.md) for a step-by-step guide on how to set the Plugin up.

## Configuration

1. Log in as an administrator
2. Go to Administration > Plugins
3. Click "Configure" next to the Semantic Search plugin
4. Adjust settings as needed

## Usage

1. Ensure your user has a Developer or Manager role in at least one project
2. Click on "Semantic Search" in the top menu
3. Enter a natural language query (e.g., "Issues about login problems with the mobile app")
4. View the results ordered by semantic relevance

## How It Works

1. The plugin creates embeddings for issues when they are created or updated
2. Embeddings are stored in a separate database table using pgvector
3. When a search is performed, the query is converted to an embedding
4. PostgreSQL's vector similarity search finds the most semantically similar issues
5. Results are filtered based on user permissions

## Testing

> [!IMPORTANT]
> Make sure you are in Redmine's root directory before running the tests

The tests are written with MiniTest, the default testing framework for Ruby on Rails.

```bash
bundle exec rake redmine:plugins:test NAME=semantic_search
```

## Linting

In order to lint the application, run the following command:

```bash
bin/lint
```

## Continuous Integration

This project uses GitHub Actions for continuous integration and testing:

- **CI Workflow**: Runs linting and syntax checks on every push and pull request
- **Test Workflow**: Sets up a complete Redmine environment and runs all plugin tests

To run the workflows locally, you can use [act](https://github.com/nektos/act).

### GitHub Secrets

The test workflow requires the following GitHub secret to be configured:

- `OPENAI_API_KEY`: A random string of characters. It does not have to be a valid OpenAI API Key.

## License

This plugin is licensed under the MIT License.

## Author

- [Sami Hindi](https://samihindi.com)

<!--
## Redmine Credentials

- `admin:Thisisatestpassword123!` -->

## Help

If at any point while using this plugin you face certain problems, just open an issue.

## Copyright

© 2025 Renuo AG
