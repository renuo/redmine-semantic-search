class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |driver_options|
    driver_options.add_argument 'no-sandbox'
    driver_options.add_argument 'disable-dev-shm-usage'
    driver_options.add_argument 'disable-gpu'
  end

  include LoginHelpers::System

  setup do
    EmbeddingService.any_instance.stubs(:generate_embedding).returns(Array.new(2000) { 0.1 })
  end

  def log_user(login, password)
    visit '/login'
    fill_in 'username', with: login
    fill_in 'password', with: password
    click_button 'Login', wait: 5

    # Enhanced debugging for login failure
    unless page.has_css?('#loggedas', wait: 0.1) # Quick check, real wait is in assert_selector
      puts "DEBUG: Login failed for user '#{login}'. Current URL: #{current_url}"
      puts "DEBUG: Current page HTML snapshot (also saved to tmp/capybara/login_failure.html):"
      puts page.html
      # Ensure tmp/capybara directory exists
      FileUtils.mkdir_p(Rails.root.join('tmp/capybara'))
      save_page Rails.root.join('tmp/capybara/login_failure.html')
      # It might also be useful to see if there are any flash error messages
      if page.has_css?('#errorExplanation')
        puts "DEBUG: Found #errorExplanation: #{find('#errorExplanation').text}"
      end
      if page.has_css?('.flash.error')
        puts "DEBUG: Found .flash.error: #{find('.flash.error').text}"
      end
    end

    assert_selector '#loggedas', wait: 5
  end

  def logout
    if has_link?(class: 'logout')
      click_link(class: 'logout', wait: 5)
    end
    assert_no_selector '#loggedas', wait: 5
  end
end
