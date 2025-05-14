require File.expand_path(File.dirname(__FILE__) + '/../../../test/test_helper')

require 'mocha/minitest'

ActiveJob::Base.queue_adapter = :test

class EmbeddingServiceMock
  def initialize
    # TODO: is no init necessary?
  end

  def generate_embedding(text)
    Array.new(2000) { 0.1 }
  end

  def prepare_issue_content(issue)
    [
      "Issue ##{issue.id} - #{issue.subject}",
      "Description: #{issue.description}",
      issue.journals.map { |j| "Comment: #{j.notes}" if j.notes.present? }.compact.join("\n"),
      issue.time_entries.map { |te| "Time entry note: #{te.comments}" if te.comments.present? }.compact.join("\n")
    ].join("\n").strip
  end
end

ActiveSupport::TestCase.setup do |test|
  # TODO: implement?
end

# Login helper methods for different test types
module LoginHelpers
  module Integration
    def log_user(login, password)
      get '/login'
      assert_response :success
      post '/login', params: {
        username: login,
        password: password
      }
      assert_redirected_to '/my/page'
      follow_redirect!
      assert_equal login, User.find(session[:user_id]).login
    end
  end

  module System
    def log_user(login, password)
      visit '/login'
      fill_in 'username', with: login
      fill_in 'password', with: password
      click_button 'Login', wait: 3
      assert_selector '#loggedas', wait: 3
    end

    def logout
      if has_link?(class: 'logout')
        click_link(class: 'logout', wait: 3)
      end
      assert_no_selector '#loggedas', wait: 3
    end
  end
end
