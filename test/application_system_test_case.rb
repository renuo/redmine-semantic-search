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
    visit '/login'
    fill_in 'username', with: login
    fill_in 'password', with: password
    click_button 'Login'

    # Debugging information
    puts "--- Debugging login for user: '#{login}' ---"
    sanitized_login = login.gsub(/[^0-9A-Za-z_.-]/, '_')
    # Saving to tmp/screenshots to align with existing failure screenshot path structure
    screenshot_path = "tmp/screenshots/debug_login_#{sanitized_login}_#{Time.now.to_i}.png"
    save_screenshot(screenshot_path, full: true)
    puts "Screenshot saved to: #{File.expand_path(screenshot_path, Rails.root)}"
    puts "Current URL: #{current_url}"
    puts "Page title: #{page.title}"
    if page.has_css?('body')
      # Limit the output to avoid overly verbose logs
      body_text_sample = page.find('body').text(normalize_ws: true).truncate(500, omission: '... (truncated)')
      puts "Page body (first 500 chars, normalized whitespace): #{body_text_sample}"
    else
      puts "Page body tag not found or no text content."
    end
    # Check for common error messages on the page
    if page.has_css?('#errorExplanation')
      puts "Found error explanation on page: #{page.find('#errorExplanation').text(normalize_ws: true)}"
    end
    puts "--- End debugging login for user: '#{login}' ---"

    assert_selector '#loggedas'
  end

  def logout
    if has_link?(class: 'logout')
      click_link(class: 'logout')
    end
    assert_no_selector '#loggedas'
  end
end
