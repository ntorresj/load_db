#!/usr/bin/env ruby

require 'aws-sdk'
require 'colorize'
require 'dotenv'

class LoadDb
  attr_accessor :bucket,
                :rootdir,
                :database,
                :mysql_cmd,
                :backup_selected,
                :local_extension,
                :amazon_access_key_id,
                :amazon_secret_access_key

  def initialize(client)
    (Dotenv.load "#{__dir__}/.env").each { |key, value| send "#{key}=", value }

    @s3 = s3
    @client = client
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

  def local_backups
    backups = []
    Dir["#{@rootdir}#{@client}*.gz"].each_with_index do |el, _index|
      backups << el
    end
    backups
  end

  def local_backup?
    local_backups.include? @backup_selected
  end

  def backups
    @bucket = s3.buckets[@bucket]
    tree = bucket.as_tree(prefix: @client)
    tree = tree.children.select(&:leaf?).collect(&:key)

    local_backups.each { |local_backup| tree << local_backup }
    tree
  end

  def backup_date
    @backup_selected.match(/(\d{4}\-\d{2}\-\d{2})/)[0]
  end

  def download_url
    @bucket.objects[@backup_selected].url_for(:read, expires: 20 * 60)
  end

  def file_name_without_extension
    "#{@rootdir}#{@client}_#{backup_date}"
  end

  def file_name(extension)
    "#{file_name_without_extension}.#{extension}"
  end

  def backup_exists?
    File.exist? file_name(@local_extension)
  end

  def download
    file = file_name(@local_extension)
    system "wget '#{download_url}' -O #{file}"
  end

  def extract_database
    system "pv #{file_name @local_extension} | gunzip > #{file_name 'sql'}"
  end

  def import_database
    system "perl -pi -w -e \'s/ROW_FORMAT=FIXED//g;\' #{file_name 'sql'}"
    system "#{@mysql_cmd} -e 'DROP DATABASE IF EXISTS `#{@database}`'"
    system "#{@mysql_cmd} -e 'CREATE DATABASE `#{@database}`'"
    system "pv #{file_name 'sql'} | #{@mysql_cmd} #{@database}"
  end

  def remove_sql_file
    system "rm -f #{file_name('sql')}"
  end
end

client = ARGV[0]
if client.nil?
  puts 'I need a client name, enter any... '
  client = $stdin.gets.chomp
end

ldb = LoadDb.new client
backups = ldb.backups

exit if backups.empty?

puts '=' * 64
puts ' Choose an option'
puts '-' * 64
backups.each_with_index do |backup, index|
  print "[#{(index + 1).to_s.rjust(2)}] ".blue
  print backup.green
  print "\n"
end
puts '=' * 64
puts ' > Which ?'.yellow

backup_selected = $stdin.gets.chomp.to_i
ldb.backup_selected = backups[backup_selected - 1]

answer = 'y'
if ldb.backup_exists? && !ldb.local_backup?
  puts 'Download again ? (y/n)'
  answer = $stdin.gets.chomp
end
ldb.download if answer == 'y' && !ldb.local_backup?

puts 'Extracting database...'.blue
ldb.extract_database
puts 'Importing database...'.green
ldb.import_database
ldb.remove_sql_file
puts 'Done :)'.green
