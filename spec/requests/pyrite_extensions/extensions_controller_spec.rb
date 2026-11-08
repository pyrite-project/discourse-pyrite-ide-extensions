# frozen_string_literal: true

require_relative "../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::ExtensionsController do
  fab!(:category)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:admin)

  before do
    SiteSetting.pyrite_extensions_enabled = true
    SiteSetting.pyrite_extensions_category = category.id
  end

  describe "#create" do
    let(:upload) { stage_pyrite_upload(user) }
    let(:params) do
      {
        upload_id: upload.id,
        title: "Hello extension for Pyrite",
        summary: "Says hello",
        description: "Details",
      }
    end

    it "rejects anonymous users" do
      post "/pyrite/api/v1/extensions", params: params

      expect(response.status).to eq(403)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "publishes the extension and its registry topic" do
        post "/pyrite/api/v1/extensions", params: params

        extension = PyriteExtensions::Extension.find_by!(ext_id: "com.example.hello")
        expect(response.status).to eq(200)
        expect(response.parsed_body).to include(
          "ext_id" => "com.example.hello",
          "topic_url" => extension.topic.url,
        )
        expect(extension.topic.category_id).to eq(category.id)
        expect(extension.releases.pluck(:version)).to eq(["0.1.0"])
      end

      it "returns 403 for users below the minimum trust level" do
        sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

        post "/pyrite/api/v1/extensions", params: params

        expect(response.status).to eq(403)
      end

      it "returns 400 for missing params" do
        post "/pyrite/api/v1/extensions", params: params.merge(title: "")

        expect(response.status).to eq(400)
      end

      it "returns 404 for an unknown upload id" do
        post "/pyrite/api/v1/extensions", params: params.merge(upload_id: 0)

        expect(response.status).to eq(404)
      end

      it "returns 404 for another user's upload" do
        foreign =
          stage_pyrite_upload(
            admin,
            "plugin.toml" => PyritePackageHelper::VALID_MANIFEST,
            "__main__.py" => "other",
          )

        post "/pyrite/api/v1/extensions", params: params.merge(upload_id: foreign.id)

        expect(response.status).to eq(404)
      end

      it "accepts a de-duplicated upload that another user staged first" do
        shared = stage_pyrite_upload(admin)
        expect(stage_pyrite_upload(user)).to eq(shared)

        post "/pyrite/api/v1/extensions", params: params.merge(upload_id: shared.id)

        expect(response.status).to eq(200)
      end

      it "returns 422 with a message when the package is invalid" do
        invalid = stage_pyrite_upload(user, "__main__.py" => "x")

        post "/pyrite/api/v1/extensions", params: params.merge(upload_id: invalid.id)

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("pyrite_extensions.package.errors.manifest_missing")],
        )
      end

      it "returns 422 when the extension id is taken by another user" do
        Fabricate(:pyrite_extension, ext_id: "com.example.hello")

        post "/pyrite/api/v1/extensions", params: params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(
          ["Plugin id #{I18n.t("pyrite_extensions.errors.ext_id_taken_validation")}"],
        )
        expect(Topic.where(category_id: category.id).count).to eq(0)
      end

      it "returns 422 with the failure message when the topic cannot be created" do
        post "/pyrite/api/v1/extensions", params: params.merge(title: "x")

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].join).to be_present
        expect(PyriteExtensions::Extension.count).to eq(0)
      end
    end
  end

  describe "#show" do
    fab!(:extension) { Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user) }
    fab!(:older) { Fabricate(:pyrite_release, extension:, version: "1.0.0") }
    fab!(:newer) { Fabricate(:pyrite_release, extension:, version: "1.2.0") }

    before { extension.update!(latest_release: newer) }

    it "returns the extension with versions newest first, without a .json suffix" do
      get "/pyrite/api/v1/extensions/com.example.hello"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "ext_id" => "com.example.hello",
        "name" => "Hello",
        "summary" => "Says hello",
        "owner_username" => user.username,
        "topic_url" => extension.topic.url,
        "latest_version" => "1.2.0",
        "moderation" => {
          "level" => "none",
          "severity" => nil,
          "message" => nil,
        },
      )
      expect(response.parsed_body["versions"].map { |version| version["version"] }).to eq(
        %w[1.2.0 1.0.0],
      )
    end

    it "returns 404 for an unknown extension" do
      get "/pyrite/api/v1/extensions/com.example.missing"

      expect(response.status).to eq(404)
    end

    it "hides taken down extensions from everyone except staff" do
      extension.update!(moderation_level: :takedown)

      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(404)

      sign_in(user)
      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(404)

      sign_in(admin)
      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(200)
      expect(response.parsed_body["moderation"]["level"]).to eq("takedown")
    end

    it "hides delisted extensions from the public but not from the owner or staff" do
      extension.update!(moderation_level: :delisted)

      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(404)

      sign_in(Fabricate(:user))
      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(404)

      sign_in(user)
      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(200)

      sign_in(admin)
      get "/pyrite/api/v1/extensions/com.example.hello"
      expect(response.status).to eq(200)
    end
  end
end
