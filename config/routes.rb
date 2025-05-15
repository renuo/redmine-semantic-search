# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

RedmineApp::Application.routes.draw do
  get 'semantic_search', to: 'redmine_semantic_search#index'

  post 'semantic_search/sync_embeddings', to: 'redmine_semantic_search#sync_embeddings'
end
