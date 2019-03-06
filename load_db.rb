#!/usr/bin/env ruby

require 'aws-sdk'
require 'colorize'
require_relative 'settings'

def check_amazon_keys
  return if amazon_credentials_defined?

  puts 'You need to configure amazon credentials in the environment variables:'
  puts '$ export AMAZON_ACCESS_KEY_ID=<access_key_id>'
  puts '$ export AMAZON_SECRET_ACCESS_KEY=<secret_access_key>'
  puts ''
  exit
end

def amazon_credentials_defined?
  !ENV['AMAZON_ACCESS_KEY_ID'].nil? && !ENV['AMAZON_SECRET_ACCESS_KEY'].nil?
end

def show_backups(options)
  puts '=' * 40
  puts ' Choose an option'
  puts '-' * 40

  client = /(?<=\/)[^_]+/.match(options[0])
  Dir[$root + client.to_s + '*.gz'].each_with_index do |el, _index|
    options << el
  end
  options << 'exit'
  options.each_with_index do |el, index|
    index = (index + 1).to_s.rjust(2)
    puts " [ #{index} ]".blue + " #{el}".green
  end
  puts '=' * 40
  puts ' > Which?: '.green
  id = $stdin.gets.chomp.to_i until (1..(options.length)).cover?(id)

  options[id - 1]
end

check_amazon_keys

client = ARGV[0]

if client.nil?
  puts 'I need a client name, enter any...'
  client = $stdin.gets.chomp
end

s3 = AWS::S3.new(
  access_key_id: ENV['AMAZON_ACCESS_KEY_ID'],
  secret_access_key: ENV['AMAZON_SECRET_ACCESS_KEY']
)
bucket = s3.buckets[$bucket]
tree   = bucket.as_tree(prefix: client.to_s)

backups = tree.children.select(&:leaf?).collect(&:key)
backup_name = show_backups backups

if backup_name == 'exit'
  puts 'Bye!'.green
else
  if !File.exist?(backup_name)
    backup_date = backup_name.match(/(\d{4}\-\d{2}\-\d{2})/)[0].delete('-')
    download_url = bucket.objects[backup_name].url_for(:read, expires: 20 * 60)
    $db['{client}'] = client
    db = $db

    system "mkdir #{$root}" unless Dir.exist?($root)

    file_exists = false
    download_again = nil

    if File.exist?("#{$root}#{client}_#{backup_date}.tar.gz")
      file_exists = true
      puts 'Database exists, download again? (y/n)'
      download_again = $stdin.gets.chomp
    end

    if !file_exists || download_again == 'y'
      system "rm -f #{$root}#{client}_#{backup_date}.tar.gz"
      system "wget '#{download_url}' -O #{$root}#{client}_#{backup_date}.tar.gz"
    end

    puts 'Importing Database...'.green

    system "pv #{$root}#{client}_#{backup_date}.tar.gz | gunzip > #{$root}#{client}_#{backup_date}.sql"
    system "perl -pi -w -e \"s/ROW_FORMAT=FIXED//g;\" #{$root}#{client}_#{backup_date}.sql"

    system "#{$mysqlCmd} -e 'DROP DATABASE IF EXISTS `#{db}`'"
    system "#{$mysqlCmd} -e 'CREATE DATABASE `#{db}`'"
    system "pv #{$root}#{client}_#{backup_date}.sql | #{$mysqlCmd} #{db}"
  else
    $db['{client}'] = client
    db = $db

    puts 'Importing Database...'.green

    system "pv #{backup_name} | gunzip > #{$root}#{client}_#{backup_date}.sql"
    system "perl -pi -w -e \"s/ROW_FORMAT=FIXED//g;\" #{$root}#{client}_#{backup_date}.sql"

    system "#{$mysqlCmd} -e 'DROP DATABASE IF EXISTS `#{db}`'"
    system "#{$mysqlCmd} -e 'CREATE DATABASE `#{db}`'"
    system "pv #{$root}#{client}_#{backup_date}.sql | #{$mysqlCmd} #{db}"

  end

  system "rm -f #{$root}#{client}_#{backup_date}.sql"

  puts 'Done :P!'.green
end
