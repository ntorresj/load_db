#!/usr/bin/env ruby
require 'aws-sdk'
require 'colorize'
require 'dotenv'

class LoadDb
  attr_accessor :bucket,
                :rootdir,
                :database,
                :mysql_cmd,
                :option_selected,
                :local_extension,
                :amazon_access_key_id,
                :amazon_secret_access_key

  def initialize
    (Dotenv.load "#{__dir__}/.env").each { |key, value| send "#{key}=", value }

    @s3 = s3
    @client = read_client
    @tree = backups_tree
    @database['{client}'] = @client

    system "mkdir #{@rootdir}" unless Dir.exist? @rootdir
  end

  def s3
    exception_msg = 'Amazon keys not defined in your .env file'
    raise ArgumentError, exception_msg unless amazon_credentials_defined?
    AWS::S3.new(access_key_id:     @amazon_access_key_id,
                secret_access_key: @amazon_secret_access_key)
  end

  def amazon_credentials_defined?
    !@amazon_access_key_id.nil? && !@amazon_secret_access_key.nil?
  end

  def print_backups
    puts '=' * 40
    puts ' Choose an option'
    puts '-' * 40
    @tree.each_with_index do |el, index|
      puts " [#{(index + 1).to_s.rjust(2)}]".blue + " #{el}".green
    end
    puts '=' * 40
  end

  def select_backup
    print_backups
    puts ' > Which?: '.green
    id = $stdin.gets.chomp.to_i until (1...(@tree.length + 1)).cover? id
    @option_selected = @tree[id - 1]
  end

  def local_backups
    backups = []
    Dir["#{@rootdir}#{@client}*.gz"].each_with_index do |el, _index|
      backups << el
    end
    backups
  end

  def backups_tree
    @bucket = s3.buckets[@bucket]
    tree = bucket.as_tree(prefix: @client)
    tree = tree.children.select(&:leaf?).collect(&:key)

    local_backups.each { |local_backup| tree << local_backup }
    tree << 'exit'
    tree
  end

  def read_client
    return ARGV[0] unless ARGV[0].nil?
    puts 'I need a client name, enter any...'
    $stdin.gets.chomp
  end

  def backup_date
    @option_selected.match(/(\d{4}\-\d{2}\-\d{2})/)[0].delete('-')
  end

  def download_url
    @bucket.objects[@option_selected].url_for(:read, expires: 20 * 60)
  end

  def file_name_without_extension
    "#{@rootdir}#{@client}_#{backup_date}"
  end

  def file_name(extension)
    "#{file_name_without_extension}.#{extension}"
  end

  def download
    file = file_name @local_extension
    file_exists = false

    if File.exist? file
      file_exists = true
      puts 'Database exists, download again ? (y/n)'
      download_again = $stdin.gets.chomp
    end

    return false unless !file_exists || download_again == 'y'
    remove_sql_file
    system "wget '#{download_url}' -O #{file}"
  end

  def extract_database
    puts 'Extracting database...'.blue
    system "pv #{file_name @local_extension} | gunzip > #{file_name 'sql'}"
  end

  def import_database
    puts 'Importing database...'.green

    system "perl -pi -w -e \'s/ROW_FORMAT=FIXED//g;\' #{file_name 'sql'}"
    system "#{@mysql_cmd} -e 'DROP DATABASE IF EXISTS `#{@database}`'"
    system "#{@mysql_cmd} -e 'CREATE DATABASE `#{@database}`'"
    system "pv #{file_name 'sql'} | #{@mysql_cmd} #{@database}"
  end

  def remove_sql_file
    system "rm -f #{file_name('sql')}"
  end
end

load_db = LoadDb.new
load_db.select_backup
load_db.download
load_db.extract_database
load_db.import_database
load_db.remove_sql_file
