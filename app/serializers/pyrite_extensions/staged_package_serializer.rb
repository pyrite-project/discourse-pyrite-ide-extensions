# frozen_string_literal: true

module PyriteExtensions
  # What the publishing wizard shows after the first step: the manifest the server found in the upload.
  class StagedPackageSerializer < ApplicationSerializer
    attributes :upload_id, :sha256, :size, :manifest, :existing_extension

    def upload_id
      object.id
    end

    def sha256
      @options[:package].sha256
    end

    def size
      @options[:package].size
    end

    def manifest
      @options[:package].manifest.to_h
    end

    def existing_extension
      @options[:extension].present?
    end
  end
end
