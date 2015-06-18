module Datapimp::Sync
  class Github
    attr_reader :options, :repository

    def initialize(repository, options)
      @repository = repository
      @options    = options
    end

    def sync_issues
      issues = client.issues(repository, filter: "all")
      issues.map! do |issue|
        %w(comments events labels).each do |rel|
          issue[rel] = issue.rels[rel].get.data if relations.include?(rel)
        end
        issue
      end
      serve_output(issues)
    end

    def sync_issue_comments(issue_id)
      comments = client.issue_comments(repository, issue_id)
      serve_output(comments)
    end

    private

    def client
      @_client ||= Datapimp::Sync.github.api
    end

    def relations
      @_relations ||= @options.relations.to_a
    end

    def serve_output(output)
      if output.is_a?(Array)
        output.map! do |o|
          o.respond_to?(:to_attrs) ? o.send(:to_attrs) : o
        end
      end

      if @options.format && @options.format == "json"
        output = JSON.generate(output)
      end

      if @options.output
        Pathname(options.output).open("w+") do |f|
          f.write(output)
        end
      else
        puts output.to_s
      end
    end
  end
end