# Setup Guide

This Guide will give you a step-by-step Tutorial on how to set this Plugin up.

## Pre-requisites

Before we get started, make sure you have the following done already.

✅ An Enviornment Variable called `OPENAI_API_KEY`, with your OpenAI API Key. Get it [here](https://platform.openai.com/api-keys).
✅ A valid Redmine 5.1 or 6.0 instance (see [Setting Up Redmine](#setting-up-redmine))

# Plugin Setup

First, clone the plugin repository into the `plugins` directory of your redmine instance.

```bash
git clone https://github.com/renuo/redmine_semantic_search plugins/redmine_semantic_search
cd plugins/redmine_semantic_search
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
  host: localhost
  username: postgres
  password: "postgres"
  encoding: unicode

development:
  adapter: postgresql
  database: redmine_development
  host: localhost
  username: postgres
  password: "postgres"
  encoding: unicode

test:
  adapter: postgresql
  database: redmine_test
  host: localhost
  username: postgres
  password: "postgres"
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
bundle exec rake generate_secret_toke
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
