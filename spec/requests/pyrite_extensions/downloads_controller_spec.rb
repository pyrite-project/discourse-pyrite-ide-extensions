# frozen_string_literal: true

require_relative "../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::DownloadsController do
  fab!(:user)
  fab!(:admin)
  fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user) }

  let(:upload) { stage_pyrite_upload(user) }
  let!(:release) { Fabricate(:pyrite_release, extension:, version: "0.1.0", upload:) }

  before { SiteSetting.pyrite_extensions_enabled = true }

  describe "#show" do
    %w[pyrix zip].each do |format|
      it "serves the package as .#{format} and counts the download" do
        expect {
          get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.#{format}"
        }.to change { release.reload.downloads_count }.by(1)

        expect(response.status).to eq(200)
        expect(response.headers["Content-Disposition"]).to include(
          "com.example.hello-0.1.0.#{format}",
        )
        expect(response.body.b).to eq(File.binread(Discourse.store.path_for(upload)))
      end
    end

    it "returns 404 for other package formats" do
      get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.tar"

      expect(response.status).to eq(404)
    end

    it "returns 404 when the release has no stored upload" do
      release.update_columns(upload_id: nil)

      get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.pyrix"

      expect(response.status).to eq(404)
    end

    it "returns 410 with the moderation message for a withdrawn release and does not count it" do
      release.update!(moderation_level: :withdrawn, moderation_message: "Broken build")

      expect {
        get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.pyrix"
      }.not_to change { release.reload.downloads_count }

      expect(response.status).to eq(410)
      expect(response.parsed_body["errors"]).to eq(["Broken build"])
    end

    it "returns 410 when the whole extension is withdrawn" do
      extension.update!(moderation_level: :withdrawn)

      get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.zip"

      expect(response.status).to eq(410)
    end

    it "still serves a withdrawn release to staff" do
      release.update!(moderation_level: :withdrawn)
      sign_in(admin)

      get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.pyrix"

      expect(response.status).to eq(200)
    end

    it "returns 404 for a delisted extension for the public" do
      extension.update!(moderation_level: :delisted)

      get "/pyrite/api/v1/extensions/com.example.hello/versions/0.1.0/package.pyrix"

      expect(response.status).to eq(404)
    end
  end
end
