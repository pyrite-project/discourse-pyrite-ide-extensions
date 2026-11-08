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

  describe "#index" do
    it "lists releases newest first under a semantic root" do
      Fabricate(:pyrite_release, extension:, version: "2.0.0")

      get "/pyrite/registry/extensions/com.example.hello/releases.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["releases"].map { |entry| entry["version"] }).to eq(
        ["2.0.0", "1.0.0-rc.1"],
      )
    end

    it "hides taken down releases from the public but includes them for staff" do
      release.update!(moderation_level: :takedown)

      get "/pyrite/registry/extensions/com.example.hello/releases.json"
      expect(response.parsed_body["releases"]).to eq([])

      sign_in(admin)
      get "/pyrite/registry/extensions/com.example.hello/releases.json"
      expect(response.parsed_body["releases"].first["version"]).to eq(release.version)
    end

    it "does not expose releases of a hidden extension" do
      extension.update!(moderation_level: :delisted)

      get "/pyrite/registry/extensions/com.example.hello/releases.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#show" do
    it "returns the release, including versions containing dots and dashes" do
      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["release"]).not_to have_key("download_url")
      expect(response.parsed_body["release"]).to include(
        "extension_id" => "com.example.hello",
        "version" => "1.0.0-rc.1",
        "artifact" => { "sha256" => release.sha256, "size" => 1234 },
        "manifest" => {
          "type" => "ui",
          "platforms" => %w[windows],
          "permissions" => %w[ui.view],
          "author" => "Ann",
        },
        "changelog" => "Initial",
        "installable" => true,
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

      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"

      expect(response.parsed_body["release"]).to include("installable" => false)
      expect(response.parsed_body["release"]["moderation"]).to include(
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

      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"

      expect(response.parsed_body["release"]["moderation"]).to include(
        "level" => "advisory",
        "severity" => "high",
        "scope" => "package",
      )
      expect(response.parsed_body["release"]["installable"]).to eq(true)
    end

    it "returns 404 for an unknown version" do
      get "/pyrite/registry/extensions/com.example.hello/releases/9.9.9.json"

      expect(response.status).to eq(404)
    end

    it "hides a taken down release from non-staff only" do
      release.update!(moderation_level: :takedown)

      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"
      expect(response.status).to eq(404)

      sign_in(admin)
      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"
      expect(response.status).to eq(200)
    end

    it "hides releases of a delisted extension from the public but not from the owner" do
      extension.update!(moderation_level: :delisted)

      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"
      expect(response.status).to eq(404)

      sign_in(user)
      get "/pyrite/registry/extensions/com.example.hello/releases/1.0.0-rc.1.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["release"]["installable"]).to eq(false)
    end
  end
end
