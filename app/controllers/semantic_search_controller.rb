class SemanticSearchController < ApplicationController
  before_action :require_login
  before_action :authorize_semantic_search
  before_action :require_admin, only: [:settings, :update_settings, :sync_embeddings]

  def index
    @projects = Project.visible.sorted.to_a
    @question = params[:q] || ""
    @results = []

    if @question.present?
      search_service = SemanticSearchService.new
      search_limit = Setting.plugin_semantic_search['search_limit'].to_i
      @results = search_service.search(@question, User.current, search_limit)
    end

    render layout: "base"
  rescue EmbeddingService::EmbeddingError => e
    flash.now[:error] = e.message
    render layout: "base"
  end

  def settings
    @settings = Setting.plugin_semantic_search
  end

  def update_settings
    Setting.plugin_semantic_search = params[:settings]
    flash[:notice] = l(:notice_successful_update)

    # check if model was changed, if yes, schedule a job to sync embeddings
    if params[:settings][:model] != Setting.plugin_semantic_search[:model]
      SyncEmbeddingsJob.perform_later
    end

    redirect_to action: "settings"
  end

  def sync_embeddings
    issue_count = Issue.count

    SyncEmbeddingsJob.perform_later

    flash[:notice] = l(:notice_sync_embeddings_started, count: issue_count)
    redirect_back(fallback_location: { controller: "issues", action: "index" })
  end

  private

  def authorize_semantic_search
    unless User.current.allowed_to?(:use_semantic_search, nil, global: true)
      deny_access
    end
  end
end
