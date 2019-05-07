# frozen_string_literal: true

require 'aws-sdk-s3'

module Lib
  # Not found backup exception
  class BackupNotFound < StandardError; end

  # External backup service class
  class BackupService
    attr_reader :service, :client, :bucket, :prefix

    REQUIRED_KEYS = %w[
      amazon_access_key_id
      amazon_secret_access_key
      amazon_region
    ].freeze

    def initialize(bucket, prefix)
      @client = build_client
      @bucket = bucket
      @prefix = prefix
    end

    def download_url_by(search_key)
      backup = remote_objects.find { |item| item.key.include?(search_key) }

      backup.presigned_url :get, expires_in: 1200
    rescue NoMethodError
      raise BackupNotFound
    end

    def remote_objects
      remote_bucket = client.bucket bucket

      remote_bucket.objects prefix: prefix
    end

    def remote_objects_keys
      remote_objects.collect(&:key)
    end

    private

    def build_client
      exception_message = I18n.t 'backupservice.credentials.not_defined'
      raise ArgumentError, exception_message unless validate_credentials

      credentials = ::Aws::Credentials.new Settings.amazon_access_key_id,
                                           Settings.amazon_secret_access_key
      ::Aws.config = {
        region: Settings.amazon_region,
        credentials: credentials
      }

      ::Aws::S3::Resource.new
    end

    def validate_credentials
      REQUIRED_KEYS.each do |required_key|
        return false unless Settings.send required_key
      end
    end
  end
end
