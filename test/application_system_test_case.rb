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
    assert_selector '#loggedas'
  end

  def logout
    visit '/logout'
    assert_no_selector '#loggedas'
  end
end
