# frozen_string_literal: true

require 'colorize'

module Lib
  # System management class
  class SystemService
    attr_reader :database, :db_command
    attr_accessor :selected_backup

    def initialize(client)
      @database = client
      @db_command = Settings.db_command
    end

    def local_backups
      Dir["#{Settings.rootdir}/#{database}*.#{Settings.local_extension}"]
    end

    def local_backup?
      local_backups.include? selected_backup
    end

    def download_backup(url)
      system "wget '#{url}' -O #{build_filename}"
    end

    def backup_exists?
      File.exist? build_filename
    end

    def backup_date
      selected_backup.match(/(\d{4}\-\d{2}\-\d{2})/)[0]
    end

    def import_backup
      filename = build_filename 'sql'

      system "perl -pi -w -e \'s/ROW_FORMAT=FIXED//g;\' #{filename}"
      system "#{db_command} -e 'DROP DATABASE IF EXISTS `#{database}`'"
      system "#{db_command} -e 'CREATE DATABASE `#{database}`'"
      system "pv #{filename} | #{db_command} #{database}"
    end

    def remove_uncompressed_file
      filename = build_filename 'sql'

      system "rm -f #{filename}"
    end

    def uncompress_backup
      filename = build_filename 'sql'

      system "pv #{build_filename} | gunzip > #{filename}"
    end

    def build_filename(extension = Settings.local_extension)
      "#{filename_without_extension}.#{extension}"
    end

    def filename_without_extension
      "#{Settings.rootdir}/#{database}_#{backup_date}"
    end

    # execute before load backup commands
    def before_load_commands
      return unless Settings.before_load_commands

      Settings.before_load_commands.each do |command|
        execute_db_command command
      end
    end

    # execute after load backup commands
    def after_load_commands
      return unless Settings.after_load_commands

      Settings.after_load_commands.each do |command|
        execute_db_command command
      end
    end

    private

    # Execute command on database
    def execute_db_command(command)
      return unless command

      puts "    * #{command.light_green}"
      system "#{db_command} -e 'USE #{database}; #{command}'"
    end
  end
end
