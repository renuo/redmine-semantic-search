class RedmineSemanticSearchController < ApplicationController
  before_action :require_login
  before_action :authorize_semantic_search
  before_action :authorize_sync_embeddings, only: [:sync_embeddings]
  before_action :check_if_enabled

  def index
    @projects = Project.visible.sorted.to_a
    @question = params[:q] || ""
    @results = []

    if @question.present?
      search_service = RedmineSemanticSearchService.new
      search_limit = Setting.plugin_redmine_semantic_search["search_limit"].to_i
      @results = search_service.search(@question, User.current, search_limit)
    end

    render layout: "base"
  rescue EmbeddingService::EmbeddingError => e
    flash.now[:error] = e.message
    render layout: "base"
  end

  def sync_embeddings
    issue_count = Issue.count

    SyncEmbeddingsJob.perform_later
    flash[:notice] = l(:notice_redmine_semantic_search_sync_embeddings_started, count: issue_count)

    redirect_back(fallback_location: { controller: "issues", action: "index" })
  end

  private

  def authorize_semantic_search
    unless User.current.admin? || User.current.allowed_to?(:use_semantic_search, nil, global: true)
      deny_access
    end
  end

  def authorize_sync_embeddings
    user = User.current
    plugin_enabled = Setting.plugin_redmine_semantic_search["enabled"] == "1"

    unless plugin_enabled
      flash[:error] = l(:error_redmine_semantic_search_plugin_disabled)
      redirect_back(fallback_location: { controller: "issues", action: "index" })
      return
    end

    can_access_sync = user.admin?

    unless can_access_sync
      deny_access
    end
  end

  def check_if_enabled
    unless User.current.admin? || Setting.plugin_redmine_semantic_search["enabled"] == "1"
      render_404
    end
  end
end
