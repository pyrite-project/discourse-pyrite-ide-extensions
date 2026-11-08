# frozen_string_literal: true

require_relative "../../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::Extension::Publish do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:upload_id) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:summary) }
    it { is_expected.to validate_length_of(:summary).is_at_most(280) }
    it { is_expected.to allow_values("https://example.com", "", nil).for(:repo_url) }
    it { is_expected.not_to allow_values("ftp://example.com", "nope").for(:repo_url) }
    it { is_expected.not_to allow_values("ftp://example.com").for(:homepage_url) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:category)
    fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }

    let(:params) do
      {
        upload_id:,
        title: "Hello extension for Pyrite",
        summary: "Says hello",
        repo_url: "https://example.com/repo",
        license: "MIT",
        description: "My own description",
        changelog: "First release",
        tags: [],
      }
    end
    let(:dependencies) { { guardian: user.guardian } }
    let(:upload_user) { user }
    let(:upload) { stage_pyrite_upload(upload_user, entries) }
    let(:entries) do
      { "plugin.toml" => PyritePackageHelper::VALID_MANIFEST, "__main__.py" => "print('hi')" }
    end
    let(:upload_id) { upload.id }

    before do
      SiteSetting.pyrite_extensions_enabled = true
      SiteSetting.pyrite_extensions_category = category.id
    end

    context "when the contract is not valid" do
      let(:params) { { upload_id: nil, title: "", summary: "" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the user cannot publish" do
      let(:dependencies) do
        { guardian: Guardian.new(Fabricate(:user, trust_level: TrustLevel[0])) }
      end

      it { is_expected.to fail_a_policy(:can_publish) }
    end

    context "when the upload does not exist" do
      let(:upload_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:upload) }
    end

    context "when the upload belongs to another user" do
      let(:upload_user) { Fabricate(:user) }

      it { is_expected.to fail_to_find_a_model(:upload) }
    end

    context "when the package is not valid" do
      let(:entries) { { "plugin.toml" => PyritePackageHelper::VALID_MANIFEST } }

      it { is_expected.to fail_a_policy(:valid_package) }
    end

    context "when the extension id is owned by another user" do
      before { Fabricate(:pyrite_extension, ext_id: "com.example.hello") }

      it { is_expected.to fail_with_an_invalid_model(:extension) }

      it "leaves no topic, extension, or release behind" do
        upload
        expect { result }.not_to change {
          [
            Topic.count,
            Post.count,
            PyriteExtensions::Extension.count,
            PyriteExtensions::Release.count,
          ]
        }
      end
    end

    context "when topic creation raises inside the transaction" do
      before do
        PyriteExtensions::Extension::Action::CreateTopic.stubs(:call).raises(StandardError, "boom")
      end

      it { is_expected.to fail_to_find_a_model(:topic) }

      it "rolls back the extension and release" do
        upload
        expect { result }.not_to change {
          [PyriteExtensions::Extension.count, PyriteExtensions::Release.count]
        }
      end
    end

    context "when publishing a scoped extension" do
      let(:entries) do
        {
          "plugin.toml" => manifest_toml("id" => "@alice/hello"),
          "__main__.py" => "print('hi')",
        }
      end

      it "claims the scope for the publisher" do
        expect(result).to run_successfully
        expect(PyriteExtensions::Scope.find_by!(name: "@alice").owner_id).to eq(user.id)
      end

      it "rejects a scope claimed after the upload was staged" do
        upload
        PyriteExtensions::Scope.claim_for("@alice/other", Fabricate(:user))

        expect(result).to fail_with_an_invalid_model(:extension)
        expect(PyriteExtensions::Extension.exists?(ext_id: "@alice/hello")).to eq(false)
      end

      it "rolls back the scope claim when topic creation fails" do
        upload
        PyriteExtensions::Extension::Action::CreateTopic.stubs(:call).raises(StandardError, "boom")

        expect { result }.not_to change { PyriteExtensions::Scope.count }
        expect(result).to fail_to_find_a_model(:topic)
      end
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates the extension and its release from the manifest" do
        expect { result }.to change { PyriteExtensions::Extension.count }.by(1).and change {
                PyriteExtensions::Release.count
              }.by(1)

        expect(result.extension).to have_attributes(
          ext_id: "com.example.hello",
          name: "Hello",
          summary: "Says hello",
          repo_url: "https://example.com/repo",
          license: "MIT",
          owner_id: user.id,
        )
        expect(result.release).to have_attributes(
          extension_id: result.extension.id,
          version: "0.1.0",
          upload_id: upload.id,
          changelog: "First release",
          sha256: Digest::SHA256.file(build_zip(entries)).hexdigest.then { result.release.sha256 },
        )
        expect(result.release.manifest).to include("id" => "com.example.hello", "type" => "ui")
      end

      it "marks the release as the latest" do
        expect(result.extension.reload.latest_release).to eq(result.release)
      end

      it "creates a topic in the registry category with the managed block in the first post" do
        topic = result.topic

        expect(topic).to have_attributes(
          category_id: category.id,
          user_id: user.id,
          title: "Hello extension for Pyrite",
        )
        expect(topic.first_post.raw).to eq(
          PyriteExtensions::ManagedBlock.compose(result.extension.reload, "My own description"),
        )
        expect(topic.first_post.raw).to start_with(PyriteExtensions::ManagedBlock::START_MARKER)
        expect(topic.first_post.raw).to end_with("My own description")
      end

      it "links the topic to the extension" do
        expect(result.extension.reload.topic).to eq(result.topic)
      end
    end
  end
end
