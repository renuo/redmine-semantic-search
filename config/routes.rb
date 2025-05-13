# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

RedmineApp::Application.routes.draw do
  get 'semantic_search', to: 'semantic_search#index'

  post 'semantic_search/sync_embeddings', to: 'semantic_search#sync_embeddings'
end
