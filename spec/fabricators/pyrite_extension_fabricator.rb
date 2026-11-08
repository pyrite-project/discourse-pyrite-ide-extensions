# frozen_string_literal: true

Fabricator(:pyrite_extension, class_name: 'PyriteExtensions::Extension') do
  ext_id { sequence(:pyrite_ext_id) { |n| "com.example.ext#{n}" } }
  name 'Hello'
  summary 'Says hello'
  owner(fabricator: :user)
  topic
end

Fabricator(:pyrite_release, class_name: 'PyriteExtensions::Release') do
  extension(fabricator: :pyrite_extension)
  version '1.0.0'
  sha256 { SecureRandom.hex(32) }
  size 1234
  manifest { { 'type' => 'ui', 'platforms' => %w[windows linux], 'permissions' => %w[ui.view] } }
  published_at { Time.zone.now }
end
