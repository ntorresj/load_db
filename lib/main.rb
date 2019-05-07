require 'config'
require 'i18n'
require './lib/backup_service.rb'
require './lib/system_service.rb'

module Lib
  # Main class
  class Main
    attr_reader :client, :backup_service, :system_service

    def initialize(client)
      I18n.load_path = Dir['config/locales/*.yml']
      I18n.backend.load_translations
      Config.load_and_set_settings 'config/application.yml'
      @client = client

      if client.nil?
        puts 'Type any client name...'

        @client = read_from_cli
      end
    end

    def perform
      @backup_service = Lib::BackupService.new Settings.bucket, @client
      @system_service = Lib::SystemService.new @client
      backup_list = backups

      header backup_list
      system_service.selected_backup = backup_list[read_from_cli.to_i - 1]

      manage_selected_backup
    end

    private

    def manage_selected_backup
      answer = 'y'

      if system_service.backup_exists? && system_service.local_backup?
        puts 'Download again? (y/n)'
        answer = read_from_cli
      end

      answer == 'y' ? download_backup : load_local_backup
    end

    def download_backup
      download_url = backup_service.download_url_by system_service.backup_date

      system_service.download_backup(download_url)
      load_local_backup
    end

    def load_local_backup
      puts 'Executing before load commands...'.light_blue
      system_service.before_load_commands

      puts 'Uncompressing backup...'.blue
      system_service.uncompress_backup

      puts 'Loading backup...'.green
      system_service.import_backup

      puts 'Removing uncompressed backup...'.red
      system_service.remove_uncompressed_file

      puts 'Executing after load commands...'.light_blue
      system_service.after_load_commands
    end

    def header(backup_list)
      draw '=', 64
      puts 'Choose an option'
      draw '=', 64
      backup_list.each_with_index do |backup, index|
        print "[#{(index + 1).to_s.rjust(2)}] ".blue
        print backup.green
        print "\n"
      end
      draw '=', 64
      puts ' > Which?'.yellow
    end

    def backups
      (remote_backups << local_backups).uniq.flatten
    end

    def remote_backups
      backup_service.remote_objects_keys
    end

    def local_backups
      system_service.local_backups
    end

    def draw(string, times = 1)
      puts string * times
    end

    def read_from_cli
      $stdin.gets.chomp
    end
  end
end
