# Setup Guide

This Guide will give you a step-by-step Tutorial on how to set this Plugin up.

## Pre-requisites

Before we get started, make sure you have the following done already.

✅ Optional: Your OpenAI API Key. Get it [here](https://platform.openai.com/api-keys).
<br />
✅ A valid Redmine 5.1 or 6.0 instance (see [Setting Up Redmine](#setting-up-redmine))

# Plugin Setup

First, clone the plugin repository into the `plugins` directory of your Redmine instance.
It's assumed you are in your Redmine root directory when you run the following command:

```bash
git clone https://github.com/renuo/redmine_semantic_search plugins/redmine_semantic_search
```

Next, install the required system-wide dependencies (this will install both `postgresql` and `pgvector` if you don't have them):

```bash
brew install postgresql@16 pgvector
```

Then, navigate into the newly cloned plugin's directory and install its specific Ruby dependencies using Bundler:

```bash
cd plugins/redmine_semantic_search
bundle install
```

After the plugin's dependencies are installed, navigate back to your Redmine root directory. From the Redmine root, run the plugin's database migrations:

```bash
cd ../.. # This command takes you from 'plugins/redmine_semantic_search' to the Redmine root.
         # Ensure you are in the Redmine root directory before running the next command.
RAILS_ENV=production bin/rake redmine:plugins:migrate NAME=redmine_semantic_search
```

Finally, restart your Redmine application server for the plugin to be loaded and active.
If you are running the standard Rails development server, you can typically stop it (usually with `Ctrl+C` in the terminal where it's running) and then restart it. For example:

```bash
# Stop your current server (e.g., Ctrl+C)
# Then restart it, for example:
RAILS_ENV=production bundle exec rails server
```

# Setting up Redmine

If you haven't set up Redmine, refer to this guide.

1. Make sure you have `ruby-3.2.8` installed.

There are multiple ways to install this ruby verison, but the one I recommend is the following

- Install `rbenv`, a ruby installation manager: `brew install rbenv`
- Install `ruby` version 3.2.8 using: `rbenv install 3.2.8`

2. After `ruby` is ready, clone redmine into a directory of your choice, preferrably `~`.

```bash
git clone https://github.com/redmine/redmine.git # This is a GitHub mirror of Redmine, not the official one
cd redmine
```

3. Once you have redmine locally, configure `database.yml`:

```bash
cp config/database.yml.example config/database.yml
vim config/database.yml # or any other editor of choice
```

Then paste in the following contents:

```yaml
production:
  adapter: postgresql
  database: redmine
  encoding: unicode

development:
  adapter: postgresql
  database: redmine_development
  encoding: unicode

test:
  adapter: postgresql
  database: redmine_test
  encoding: unicode
```

4. Now set the local ruby version to 3.2.8.

```bash
rbenv local 3.2.8
```

5. After that, install the dependencies with `bundle`.

```bash
bundle install
```

6. In order to setup our database, we now need to create the database, then run the migrations.

```bash
export RAILS_ENV=production
bundle exec rake generate_secret_token
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake redmine:load_default_data
```

7. Then, run the development server.

```bash
RAILS_ENV=production bundle exec rails server
```

8. Visit `http://localhost:3000` in your browser, and enter `admin` as the login and `admin` as the password.

9. Next you will be prompted to change your password, choose one and write it down for later.

## Ollama setup

```bash
brew install ollama
brew services start ollama
ollama pull nomic-embed-text:latest
ollama serve
```

# Todo:

- [ ] Add bin/setup script
- [ ] Guide to add test data
- [ ] Tell that it's disabled by default
- [ ] Remove useless checkboxes
- [ ] Let user know about how to configure ollama
