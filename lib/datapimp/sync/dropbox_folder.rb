module Datapimp
  class Sync::DropboxFolder < Hashie::Mash
    include Datapimp::Logging

    def run(action, options={})
      action = action.to_sym

      log "DropboxFolder run:#{action}"

      if action == :push
        run_push_action
      elsif action == :pull
        run_pull_action
      elsif action == :create
        run_create_action
      end
    end

    def run_create_action
      dropbox.mkdir(remote)
    end

    def run_pull_action
      binding.pry

      remote_path_entries.each do |entry|
        remote_dropbox_path = entry.path

        log "Syncing #{ remote_dropbox_path }"
        begin
          relative_local_path = remote_dropbox_path.gsub("#{remote}/",'')
          target = local_path.join(relative_local_path)

          next if target.exist? && target.size == entry.bytes

          if entry.is_dir
            log "Creating folder #{ relative_local_path }"
            FileUtils.mkdir_p local_path.join(relative_local_path)
          else
            log "== Syncing #{ entry.path }"
            remote_content = dropbox.download(remote_dropbox_path)
            target.open("w+") {|fh| fh.write(remote_content) }
          end
        rescue => e
          log "== Error while saving #{ remote_dropbox_path } to #{ relative_local_path }"
          log "    * Message: #{ e.message }"
        end
      end
    end

    def run_push_action
      if remote_path_missing?
        run_create_action()
      end

      Dir[local_path.join("**/*")].each do |f|
        f = Pathname(f)
        base = f.relative_path_from(local_path).to_s
        target_path = File.join(remote, base)

        log "Uploading #{ f } to #{target_path}"

        dropbox.upload(target_path, f.read, :overwrite => false)
      end
    end

    # Provides easy access to the Dropbox client
    def dropbox
      @dropbox ||= Datapimp::Sync.dropbox
    end

    # Provides access to the Dropbox API Delta which will tell us
    # how to modify the state of `local_path` to match what exists
    # on Dropbox.
    def delta
      @delta ||= dropbox.delta(cursor, remote_path)
    end

    # A Pointer to the local path we will be syncing with the Dropbox remote
    def local_path
      Pathname(local)
    end

    # The Dropbox Delta API uses a cursor to keep track of the last state
    # the local filesystem has synced with.  We store this in the syncable folder
    # itself
    def cursor
      cursor_path.exist? && cursor_path.read
    end

    def cursor_path
      local_path.join('.dropbox-cursor')
    end

    def remote_path
      dropbox.ls(remote)
    rescue(Dropbox::API::Error::NotFound)
      nil
    end

    def remote_path_parent
      parent, _ = File.split(remote)
      dropbox.ls(parent)
    rescue(Dropbox::API::Error::NotFound)
      nil
    end

    def remote_path_missing?
      remote_path.nil?
    end

    def remote_path_entries
      pather = lambda do |entry|
        if entry.is_dir
          Array(dropbox.ls(entry.path)).map(&pather)
        else
          entry
        end
      end

      remote_path.map(&pather).flatten
    end

  end
end

