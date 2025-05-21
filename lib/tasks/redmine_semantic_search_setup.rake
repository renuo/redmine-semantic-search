namespace :redmine_semantic_search do
  desc "Sets up initial project and issue data for redmine_semantic_search plugin development and testing."
  task setup_dev_data: :environment do
    colors = {
      red: "\e[31m",
      green: "\e[32m",
      yellow: "\e[33m",
      blue: "\e[34m",
      magenta: "\e[35m",
      cyan: "\e[36m",
      reset: "\e[0m"
    }

    puts "#{colors[:cyan]}Starting Redmine development data setup for Semantic Search plugin...#{colors[:reset]}"

    admin_user = User.find_by(admin: true) || User.find_by(login: 'admin') || User.first
    unless admin_user
      puts "#{colors[:red]}Error: Could not find an admin user to assign as author. Please ensure at least one user exists.#{colors[:reset]}"
      exit 1
    end
    puts "Using user '#{colors[:yellow]}#{admin_user.login}#{colors[:reset]}' (ID: #{admin_user.id}) as author for issues."

    initial_issue_status = IssueStatus.order(:position).first
    unless initial_issue_status
      puts "#{colors[:red]}Error: No issue statuses found in the system. Please ensure Redmine has default statuses configured (e.g., via Administration > Issue Statuses).#{colors[:reset]}"
      exit 1
    end
    puts "Using initial issue status '#{colors[:yellow]}#{initial_issue_status.name}#{colors[:reset]}' (ID: #{initial_issue_status.id}) as the default for new trackers and new issues."

    bug_tracker = Tracker.find_or_create_by!(name: "Bug") do |t|
      t.default_status_id = initial_issue_status.id
    end
    feature_tracker = Tracker.find_or_create_by!(name: "Feature") do |t|
      t.default_status_id = initial_issue_status.id
    end

    puts "Found/Created Tracker '#{colors[:yellow]}Bug#{colors[:reset]}' (ID: #{bug_tracker.id})"
    puts "Found/Created Tracker '#{colors[:yellow]}Feature#{colors[:reset]}' (ID: #{feature_tracker.id})"

    default_trackers = [bug_tracker, feature_tracker]

    default_priority = IssuePriority.find_by(name: "Normal") || IssuePriority.order(:position).first
    unless default_priority
      puts "#{colors[:red]}Error: No issue priorities found. Please ensure Redmine has default priorities configured.#{colors[:reset]}"
      exit 1
    end
    puts "Using default priority '#{colors[:yellow]}#{default_priority.name}#{colors[:reset]}' (ID: #{default_priority.id}) for new issues."

    projects_data = [
      {
        name: "AI-Powered Content Moderation System",
        identifier: "ai-content-mod-#{Time.now.to_i}",
        description: "Develop an AI system to automatically moderate user-generated content, flag inappropriate submissions, and reduce manual review workload.",
        issues: [
          { subject: "Develop hate speech detection model", description: "Research and implement a machine learning model for detecting hate speech in text.", tracker: feature_tracker },
          { subject: "Integrate profanity filter API", description: "Connect with a third-party profanity filter service.", tracker: feature_tracker },
          { subject: "Image recognition for inappropriate content", description: "Build or integrate a module to identify nudity or violence in images.", tracker: feature_tracker },
          { subject: "User reporting and appeal system", description: "Allow users to report content and appeal moderation decisions.", tracker: feature_tracker },
          { subject: "Dashboard for moderators", description: "Create an admin interface for moderators to review flagged content and manage rules.", tracker: feature_tracker },
          { subject: "Performance testing for high volume", description: "Ensure the system can handle a large number of submissions per second.", tracker: bug_tracker },
          { subject: "Multilingual support for text analysis", description: "Extend text analysis capabilities to support Spanish and French.", tracker: feature_tracker },
          { subject: "False positive rate analysis", description: "Monitor and work on reducing the false positive rate of the AI models.", tracker: bug_tracker },
          { subject: "Documentation for API endpoints", description: "Provide clear documentation for the system\'s APIs.", tracker: feature_tracker },
          { subject: "Setup CI/CD pipeline for model deployment", description: "Automate the training and deployment process for new model versions.", tracker: feature_tracker }
        ]
      },
      {
        name: "Smart City Environmental Monitoring",
        identifier: "smartcity-envmon-#{Time.now.to_i}",
        description: "A project to deploy IoT sensors across the city for real-time environmental data collection (air quality, noise pollution, temperature) and analysis.",
        issues: [
          { subject: "Select and procure IoT sensor hardware", description: "Evaluate and purchase sensors for air quality, noise, and temperature.", tracker: feature_tracker },
          { subject: "Develop sensor data ingestion platform", description: "Build a scalable platform to receive and store data from thousands of sensors.", tracker: feature_tracker },
          { subject: "Create real-time data visualization dashboard", description: "Display sensor data on a map and through charts for public and city official access.", tracker: feature_tracker },
          { subject: "Implement alert system for pollution thresholds", description: "Notify authorities when pollution levels exceed predefined safety limits.", tracker: feature_tracker },
          { subject: "Data analytics for trend identification", description: "Develop algorithms to identify pollution trends and sources.", tracker: feature_tracker },
          { subject: "Mobile app for citizen reporting", description: "Allow citizens to report environmental issues via a mobile application.", tracker: bug_tracker },
          { subject: "Ensure data security and privacy", description: "Implement robust security measures for the collected data.", tracker: feature_tracker },
          { subject: "Integrate with existing city GIS systems", description: "Overlay environmental data on current city geographical information systems.", tracker: feature_tracker },
          { subject: "Power management for remote sensors", description: "Optimize power consumption for sensors in locations without direct power access.", tracker: bug_tracker },
          { subject: "Long-term data archiving strategy", description: "Plan for the storage and accessibility of historical environmental data.", tracker: feature_tracker }
        ]
      }
    ]

    projects_data.each_with_index do |p_data, index|
      puts "\n#{colors[:blue]}--- Creating Project #{index + 1}: #{p_data[:name]} ---#{colors[:reset]}"
      project = Project.find_by(identifier: p_data[:identifier])
      unless project
        project = Project.new(
          name: p_data[:name],
          identifier: p_data[:identifier],
          description: p_data[:description],
          is_public: true,
          enabled_module_names: ['issue_tracking']
        )
        project.trackers = default_trackers
        if project.save
          puts "#{colors[:green]}Project '#{project.name}' created successfully with ID: #{project.id}.#{colors[:reset]}"
        else
          puts "#{colors[:red]}Failed to create project '#{p_data[:name]}': #{project.errors.full_messages.join(', ')}#{colors[:reset]}"
          next
        end
      else
        puts "#{colors[:yellow]}Project '#{p_data[:name]}' (identifier: #{p_data[:identifier]}) already exists. ID: #{project.id}.#{colors[:reset]}"
      end

      puts "Creating issues for project '#{colors[:magenta]}#{p_data[:name]}#{colors[:reset]}' (ID: #{project.id})..."
      p_data[:issues].each do |issue_data|
        existing_issue = Issue.find_by(project_id: project.id, subject: issue_data[:subject])
        if existing_issue
          puts "#{colors[:yellow]}Issue '#{issue_data[:subject]}' already exists in project '#{project.name}'. Skipping.#{colors[:reset]}"
          next
        end

        issue = Issue.new(
          project_id: project.id,
          subject: issue_data[:subject],
          description: issue_data[:description],
          tracker_id: issue_data[:tracker].id,
          author_id: admin_user.id,
          status_id: initial_issue_status.id,
          priority_id: default_priority.id,
          start_date: Date.today
        )
        if issue.save
          puts "#{colors[:green]}Issue '#{issue.subject}' created successfully for project '#{project.name}'.#{colors[:reset]}"
        else
          puts "#{colors[:red]}Failed to create issue '#{issue_data[:subject]}' for project '#{project.name}': #{issue.errors.full_messages.join(', ')}#{colors[:reset]}"
        end
      end
    end

    puts "\n#{colors[:cyan]}Redmine development data setup finished.#{colors[:reset]}"
  end
end
