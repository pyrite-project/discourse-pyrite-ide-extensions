# frozen_string_literal: true

require_relative "../../../support/pyrite_package_helper"

RSpec.describe PyriteExtensions::Extension::UploadPackage do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:file) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:category)
    fab!(:user) { Fabricate(:user, trust_level: TrustLevel[1]) }

    let(:params) { { file: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:file) { uploaded_zip }

    before do
      SiteSetting.pyrite_extensions_enabled = true
      SiteSetting.pyrite_extensions_category = category.id
    end

    context "when the contract is not valid" do
      context "with no file" do
        let(:file) { nil }

        it { is_expected.to fail_a_contract }
      end

      context "with an unsupported file extension" do
        let(:file) { uploaded_zip(nil, "package.exe") }

        it { is_expected.to fail_a_contract }
      end

      context "with a file larger than the maximum package size" do
        before { SiteSetting.pyrite_extensions_max_package_size_mb = 1 }

        let(:file) do
          uploaded_zip(
            "plugin.toml" => PyritePackageHelper::VALID_MANIFEST,
            "__main__.py" => SecureRandom.random_bytes(2.megabytes),
          )
        end

        it { is_expected.to fail_a_contract }
      end
    end

    context "when the user cannot publish" do
      let(:dependencies) do
        { guardian: Guardian.new(Fabricate(:user, trust_level: TrustLevel[0])) }
      end

      it { is_expected.to fail_a_policy(:can_publish) }
    end

    context "when the package is not valid" do
      let(:file) { uploaded_zip("__main__.py" => "x") }

      it { is_expected.to fail_a_policy(:valid_package) }

      it "explains why" do
        expect(result["result.policy.valid_package"].reason).to eq(
          I18n.t("pyrite_extensions.package.errors.manifest_missing"),
        )
      end
    end

    context "when the extension id belongs to another user" do
      before { Fabricate(:pyrite_extension, ext_id: "com.example.hello") }

      it { is_expected.to fail_a_policy(:extension_id_available) }
    end

    context "when the version is already published" do
      before do
        extension = Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user)
        Fabricate(:pyrite_release, extension:, version: "0.1.0")
      end

      it { is_expected.to fail_a_policy(:version_not_published) }
    end

    context "when uploading a scoped extension" do
      let(:file) do
        uploaded_zip(
          "plugin.toml" => manifest_toml("id" => "@alice/hello"),
          "__main__.py" => "print(1)",
        )
      end

      it "does not claim an unused scope just by staging a package" do
        expect { result }.not_to change { PyriteExtensions::Scope.count }
        expect(result).to run_successfully
      end

      it "rejects a scope owned by another user before storing the upload" do
        PyriteExtensions::Scope.claim_for("@alice/other", Fabricate(:user))

        expect { result }.not_to change { Upload.count }
        expect(result).to fail_a_policy(:scope_available)
      end

      it "allows another package from the scope owner" do
        PyriteExtensions::Scope.claim_for("@alice/other", user)

        expect(result).to run_successfully
      end
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "stores the package as an upload owned by the user" do
        expect { result }.to change { Upload.where(user_id: user.id).count }.by(1)
        expect(result.upload).to have_attributes(
          user_id: user.id,
          original_filename: "package.pyrix",
        )
      end

      it "exposes the parsed package" do
        expect(result.package.manifest.id).to eq("com.example.hello")
        expect(result.extension).to be_nil
      end

      it "finds the existing extension when the owner publishes a new version" do
        extension = Fabricate(:pyrite_extension, ext_id: "com.example.hello", owner: user)
        Fabricate(:pyrite_release, extension:, version: "0.0.9")

        expect(result.extension).to eq(extension)
      end
    end
  end
end
