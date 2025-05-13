class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |driver_options|
    driver_options.add_argument 'no-sandbox'
    driver_options.add_argument 'disable-dev-shm-usage'
    driver_options.add_argument 'disable-gpu'
  end

  setup do
    EmbeddingService.any_instance.stubs(:generate_embedding).returns(Array.new(1536) { 0.1 })
  end

  def log_user(login, password)
    # Ensure we're starting from a clean session
    Capybara.reset_sessions!

    visit '/login'

    # Take a screenshot of the login page for debugging
    path = Rails.root.join('tmp/screenshots', "login_page_#{login}_#{Time.now.to_i}.png")
    page.save_screenshot(path)
    puts "Login page screenshot saved to: #{path}"
    puts "Login page URL: #{current_url}"

    # Debug the form structure
    puts "Form elements on page: #{page.all('form').map { |f| f[:id] || 'no-id' }.join(', ')}"

    # Wait for login page to load, without checking for a specific form ID
    assert_selector 'input[name=username]', wait: 5
    assert_selector 'input[name=password]', wait: 5

    puts "--- Attempting login for user: '#{login}' ---"

    fill_in 'username', with: login
    fill_in 'password', with: password

    # Find the login button without relying on specific text
    login_button = find('input[type=submit], button[type=submit]')
    puts "Found login button: #{login_button.value || login_button.text}"

    login_button.click

    # Wait for login to complete
    begin
      assert_selector '#loggedas', wait: 10, message: "Failed to login as #{login}"

      # Debug successful login
      puts "--- Debugging login for user: '#{login}' ---"
      puts "Current URL: #{current_url}"
      puts "Page title: #{page.title}"
      puts "Page body (first 500 chars, normalized whitespace): #{page.body.gsub(/\s+/, ' ').strip[0..500]}"
      path = Rails.root.join('tmp/screenshots', "login_success_#{login}_#{Time.now.to_i}.png")
      page.save_screenshot(path)
      puts "--- End debugging login for user: '#{login}' ---"
    rescue Minitest::Assertion => e
      # Capture failure details
      puts "Login failed for user: #{login}"
      puts "Current URL: #{current_url}"
      puts "Page content: #{page.body.gsub(/\s+/, ' ').strip[0..200]}"
      path = Rails.root.join('tmp/screenshots', "login_failed_#{login}_#{Time.now.to_i}.png")
      page.save_screenshot(path)
      puts "Error screenshot saved to: #{path}"
      raise e
    end
  end

  def logout
    puts "Attempting to log out"

    # Take screenshot before logout
    path = Rails.root.join('tmp/screenshots', "before_logout_#{Time.now.to_i}.png")
    page.save_screenshot(path)

    # Check if we're logged in
    if has_css?('#loggedas')
      puts "User is logged in, logging out"

      # Try to find the logout link
      if has_link?(class: 'logout')
        puts "Found logout link, clicking it"
        click_link(class: 'logout')
      elsif has_css?('a.logout')
        puts "Found logout link by CSS, clicking it"
        find('a.logout').click
      else
        puts "No logout link found, resetting session"
        Capybara.reset_sessions!
      end

      # Wait for logout to complete
      begin
        assert_no_selector '#loggedas', wait: 10
        puts "Successfully logged out"
      rescue Minitest::Assertion => e
        puts "Logout failed, forcibly resetting session"
        Capybara.reset_sessions!
      end
    else
      puts "Not logged in, skipping logout"
      Capybara.reset_sessions!
    end

    # Take screenshot after logout
    path = Rails.root.join('tmp/screenshots', "after_logout_#{Time.now.to_i}.png")
    page.save_screenshot(path)
  end

  def take_debug_screenshot(name)
    filename = "debug_#{name}_#{Time.now.to_i}.png"
    path = Rails.root.join('tmp/screenshots', filename)
    page.save_screenshot(path)
    puts "Screenshot saved to: #{path}"
    puts "Current URL: #{current_url}"
    puts "Page title: #{page.title}"
  end
end
