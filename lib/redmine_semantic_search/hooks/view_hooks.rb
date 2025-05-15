module RedmineSemanticSearch
  module Hooks
    class ViewHooks < Redmine::Hook::ViewListener
      render_on :view_issues_index_top, partial: 'redmine_semantic_search/issues_sync_button'

      render_on :view_issues_list_header, partial: 'redmine_semantic_search/issues_sync_button_toolbar'
    end
  end
end
