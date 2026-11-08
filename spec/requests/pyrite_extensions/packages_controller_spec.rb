# frozen_string_literal: true

require_relative "../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::PackagesController do
  fab!(:category)
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }

  before do
    SiteSetting.pyrite_extensions_enabled = true
    SiteSetting.pyrite_extensions_category = category.id
  end

  describe "#create" do
    it "rejects anonymous users" do
      post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

      expect(response.status).to eq(403)
    end

    it "returns 404 when the plugin is disabled" do
      SiteSetting.pyrite_extensions_enabled = false
      sign_in(user)

      post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

      expect(response.status).to eq(404)
    end

    context "when signed in" do
      before { sign_in(user) }

      it "stages the package and returns the manifest the server found" do
        post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

        expect(response.status).to eq(200)
        expect(response.parsed_body["package"]).to include(
          "upload_id" => Upload.find_by(user_id: user.id).id,
          "existing_extension" => false,
          "size" => be_a(Integer),
        )
        expect(response.parsed_body["package"]["sha256"]).to match(/\A\h{64}\z/)
        expect(response.parsed_body["package"]["manifest"]).to include(
          "id" => "com.example.hello",
          "version" => "0.1.0",
        )
      end

      it "flags an existing extension owned by the user" do
        Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user)

        post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

        expect(response.parsed_body["package"]["existing_extension"]).to eq(true)
      end

      it "returns 422 with the reason when the package is invalid" do
        post "/pyrite/registry/packages.json", params: { file: uploaded_zip("__main__.py" => "x") }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("pyrite_extensions.package.errors.manifest_missing")],
        )
      end

      it "returns 403 when the extension id is owned by another user" do
        Fabricate(:pyrite_extension, ext_id: "com.example.hello")

        post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("pyrite_extensions.errors.ext_id_taken")],
        )
      end

      it "returns 403 when another user owns the scope even with no remaining plugins" do
        extension = Fabricate(:pyrite_extension, ext_id: "@alice/old")
        extension.destroy!
        file = uploaded_zip(
          "plugin.toml" => manifest_toml("id" => "@alice/new"),
          "__main__.py" => "print(1)",
        )

        post "/pyrite/registry/packages.json", params: { file: }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to eq(
          [I18n.t("pyrite_extensions.errors.scope_taken")],
        )
      end

      it "returns 409 when the version is already published" do
        extension = Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user)
        Fabricate(:pyrite_release, extension:, version: "0.1.0")

        post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

        expect(response.status).to eq(409)
      end

      it "returns 400 when no file is sent" do
        post "/pyrite/registry/packages.json"

        expect(response.status).to eq(400)
      end

      it "returns 403 for users below the minimum trust level" do
        sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

        post "/pyrite/registry/packages.json", params: { file: uploaded_zip }

        expect(response.status).to eq(403)
      end
    end
  end
end
