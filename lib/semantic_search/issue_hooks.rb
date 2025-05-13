module SemanticSearch
  class IssueHooks < Redmine::Hook::Listener
    include Singleton

    def controller_issues_new_after_save(context = {})
      issue = context[:issue]
      schedule_embedding_job(issue.id) if issue.present? && plugin_enabled?
    end

    def controller_issues_edit_after_save(context = {})
      issue = context[:issue]
      schedule_embedding_job(issue.id) if issue.present? && plugin_enabled?
    end

    def controller_journals_edit_post(context = {})
      journal = context[:journal]
      if journal.present? && journal.journalized_type == 'Issue' && plugin_enabled?
        schedule_embedding_job(journal.journalized_id)
      end
    end

    def controller_journals_new_after_save(context = {})
      journal = context[:journal]
      if journal.present? && journal.journalized_type == 'Issue' && plugin_enabled?
        schedule_embedding_job(journal.journalized_id)
      end
    end

    def controller_timelog_edit_after_save(context = {})
      time_entry = context[:time_entry]
      if time_entry.present? && time_entry.issue_id.present? && plugin_enabled?
        schedule_embedding_job(time_entry.issue_id)
      end
    end

    private

    def schedule_embedding_job(issue_id)
      IssueEmbeddingJob.perform_later(issue_id)
    end

    def plugin_enabled?
      Setting.plugin_semantic_search["enabled"] == "1"
    end
  end
end
