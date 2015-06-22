require 'datapimp/sync/github'
require 'datapimp/sync/pivotal'
require 'datapimp/sync/keen'

command "sync folder" do |c|
  c.description = "Synchronize the contents of a local folder with a file sharing service"
  c.syntax = "datapimp sync folder LOCAL_PATH REMOTE_PATH [OPTIONS]"

  c.option '--type TYPE', String, "Which service is hosting the folder"
  c.option '--action ACTION', String, "Which sync action to run? push, pull"
  c.option '--reset', nil, "Reset the local path (if supported by the syncable folder)"

  Datapimp::Cli.accepts_keys_for(c, :amazon, :google, :github, :dropbox)

  c.action do |args, options|
    options.default(action:"pull", type: "dropbox", reset: false)
    local, remote = args
    Datapimp::Sync.dispatch_sync_folder_action(local, remote, options.to_hash)
  end
end

command "sync data" do |c|
  c.description = "Synchronize the contents of a local data store with its remote source"
  c.syntax = "datapimp sync data [OPTIONS]"

  c.option '--type TYPE', String, "What type of source data is this? #{ Datapimp::Sync.data_source_types.join(", ") }"
  c.option '--output FILE', String, "Write the output to a file"
  c.option '--format FORMAT', String, "Which format to serialize the output in? valid options are JSON"
  c.option '--columns NAMES', Array, "Extract only these columns"
  c.option '--relations NAMES', Array, "Also fetch these relationships on the object if applicable"

  c.option '--limit LIMIT', Integer, "Limit the number of results for Pivotal resources"
  c.option '--offset OFFSET', Integer, "Offset applied when using the limit option for Pivotal resources"

  c.example "Syncing an excel file from dropbox ", "datapimp sync data --type dropbox --columns name,description --dropbox-app-key ABC --dropbox-app-secret DEF --dropbox-client-token HIJ --dropbox-client-secret JKL spreadsheets/test.xslx"
  c.example "Syncing a google spreadsheet", "datapimp sync data --type google-spreadsheet WHATEVER_THE_KEY_IS"
  c.example "Syncing Pivotal Tracker data, user activity", "datapimp sync data --type pivotal-user-activity"
  c.example "Syncing Pivotal Tracker data, project activity", "datapimp sync data --type pivotal-project-activity PROJECT_ID"
  c.example "Syncing Pivotal Tracker data, project stories", "datapimp sync data --type pivotal-project-stories PROJECT_ID"
  c.example "Syncing Pivotal Tracker data, project story notes", "datapimp sync data --type pivotal-project-story-notes PROJECT_ID STORY_ID"
  c.example "Syncing keen.io data, extraction from an event_collection", "datapimp sync data --type keen-extraction EVENT_COLLECTION"

  Datapimp::Cli.accepts_keys_for(c, :google, :github, :dropbox)

  c.action do |args, options|
    case options.type
    when "google-spreadsheet" || options.type == "google" then
      Datapimp::DataSync.sync_google_spreadsheet(options, args)

    when "github-issues" then
      repository  = args.shift

      service = Datapimp::Sync::Github.new(repository, options)
      service.sync_issues

    when "github-issue-comments" then
      repository  = args.shift
      issue       = args.shift

      service = Datapimp::Sync::Github.new(repository, options)
      service.sync_issue_comments(issue)

    when "keen-extraction" then
      event_collection = args.shift

      service = Datapimp::Sync::Keen.new(options)
      service.extraction(event_collection)

    when "pivotal-user-activity" then
      service = Datapimp::Sync::Pivotal.new(options)
      service.user_activity

    when "pivotal-project-activity" then
      project = args.shift

      service = Datapimp::Sync::Pivotal.new(options)
      service.project_activity(project)

    when "pivotal-project-stories" then
      project = args.shift

      service = Datapimp::Sync::Pivotal.new(options)
      service.project_stories(project)

    when "pivotal-project-story-notes" then
      project = args.shift
      story   = args.shift

      service = Datapimp::Sync::Pivotal.new(options)
      service.project_story_notes(project, story)

    end
  end
end
