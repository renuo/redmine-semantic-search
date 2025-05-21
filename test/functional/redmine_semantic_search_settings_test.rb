require File.expand_path('../../test_helper', __FILE__)

class RedmineSemanticSearchSettingsTest < Redmine::ControllerTest
  fixtures :users, :roles

  tests SettingsController

  def setup
    Setting.plugin_redmine_semantic_search = { "enabled" => "1", "base_url" => "https://api.openai.com/v1" }
  end

  def test_non_admin_cannot_access_plugin_settings
    @request.session[:user_id] = 2

    get :plugin, params: { id: 'redmine_semantic_search' }
    assert_response :forbidden

    post :plugin, params: {
      id: 'redmine_semantic_search',
      settings: {
        enabled: '1',
        base_url: 'https://malicious-api.com',
        embedding_model: 'custom-model',
        search_limit: '100'
      }
    }
    assert_response :forbidden

    original_settings = Setting.plugin_redmine_semantic_search.dup
    assert_equal original_settings, Setting.plugin_redmine_semantic_search
  end
end
