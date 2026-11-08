# frozen_string_literal: true

RSpec.describe PyriteExtensions::ReleasesController do
  fab!(:user)
  fab!(:admin)
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user) }
  fab!(:release) do
    Fabricate(
      :pyrite_release,
      extension:,
      version: "1.0.0-rc.1",
      changelog: "Initial",
      manifest: {
        "type" => "ui",
        "platforms" => %w[windows],
        "permissions" => %w[ui.view],
        "author" => "Ann",
      },
    )
  end

  before { SiteSetting.pyrite_extensions_enabled = true }

  describe "#show" do
    it "returns the release, including versions containing dots and dashes" do
      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "ext_id" => "com.example.hello",
        "name" => "Hello",
        "version" => "1.0.0-rc.1",
        "sha256" => release.sha256,
        "size" => 1234,
        "type" => "ui",
        "platforms" => %w[windows],
        "permissions" => %w[ui.view],
        "author" => "Ann",
        "changelog" => "Initial",
        "installable" => true,
        "download_url" =>
          "#{Discourse.base_url}/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1/package.pyrix",
        "moderation" => {
          "level" => "none",
          "severity" => nil,
          "message" => nil,
          "scope" => "release",
        },
      )
    end

    it "reports the effective moderation state and that a withdrawn release is not installable" do
      extension.update!(moderation_level: :deprecated, moderation_message: "package")
      release.update!(moderation_level: :withdrawn, moderation_message: "bad build")

      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"

      expect(response.parsed_body).to include("installable" => false)
      expect(response.parsed_body["moderation"]).to include(
        "level" => "withdrawn",
        "message" => "bad build",
        "scope" => "release",
      )
    end

    it "reports an extension-wide advisory with package scope and severity" do
      extension.update!(
        moderation_level: :advisory,
        moderation_severity: "high",
        moderation_message: "CVE",
      )

      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"

      expect(response.parsed_body["moderation"]).to include(
        "level" => "advisory",
        "severity" => "high",
        "scope" => "package",
      )
      expect(response.parsed_body["installable"]).to eq(true)
    end

    it "returns 404 for an unknown version" do
      get "/pyrite/api/v1/extensions/com.example.hello/versions/9.9.9"

      expect(response.status).to eq(404)
    end

    it "hides a taken down release from non-staff only" do
      release.update!(moderation_level: :takedown)

      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"
      expect(response.status).to eq(404)

      sign_in(admin)
      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"
      expect(response.status).to eq(200)
    end

    it "hides releases of a delisted extension from the public but not from the owner" do
      extension.update!(moderation_level: :delisted)

      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"
      expect(response.status).to eq(404)

      sign_in(user)
      get "/pyrite/api/v1/extensions/com.example.hello/versions/1.0.0-rc.1"
      expect(response.status).to eq(200)
      expect(response.parsed_body["installable"]).to eq(false)
    end
  end
end
