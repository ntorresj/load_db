#!/usr/bin/env ruby

# frozen_string_literal: true

require './lib/main.rb'

main = Lib::Main.new ARGV[0]

main.perform
