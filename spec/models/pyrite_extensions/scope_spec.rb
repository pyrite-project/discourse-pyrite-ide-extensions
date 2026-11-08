# frozen_string_literal: true

RSpec.describe PyriteExtensions::Scope do
  fab!(:owner, :user)
  fab!(:stranger, :user)

  it "assigns a new scope to the first extension creator" do
    Fabricate(:pyrite_extension, ext_id: '@alice/first', owner:)

    expect(described_class.find_by!(name: '@alice').owner_id).to eq(owner.id)
  end

  it "allows its owner to create another extension in the same scope" do
    Fabricate(:pyrite_extension, ext_id: '@alice/first', owner:)

    expect(Fabricate(:pyrite_extension, ext_id: '@alice/second', owner:)).to be_persisted
    expect(described_class.where(name: '@alice').count).to eq(1)
  end

  it "rejects another creator even after the last extension and release are deleted" do
    extension = Fabricate(:pyrite_extension, ext_id: '@alice/first', owner:)
    Fabricate(:pyrite_release, extension:)
    extension.destroy!

    replacement = Fabricate.build(:pyrite_extension, ext_id: '@alice/second', owner: stranger)
    expect(replacement.save).to eq(false)
    expect(replacement.errors[:ext_id]).to include(I18n.t('pyrite_extensions.errors.scope_taken'))
    expect(described_class.find_by!(name: '@alice').owner_id).to eq(owner.id)
    expect(Fabricate(:pyrite_extension, ext_id: '@alice/first', owner:)).to be_persisted
  end

  it "allows another user to create a different scope" do
    Fabricate(:pyrite_extension, ext_id: '@alice/first', owner:)

    expect(Fabricate(:pyrite_extension, ext_id: '@bob/first', owner: stranger)).to be_persisted
  end

  it "does not reserve a scope for an invalid extension" do
    extension = Fabricate.build(:pyrite_extension, ext_id: '@alice/first', owner:, name: '')

    expect { extension.save }.not_to change { described_class.count }
  end

  it "does not claim scopes for unscoped ids" do
    expect { Fabricate(:pyrite_extension, ext_id: 'hello', owner:) }.not_to change {
      described_class.count
    }
  end
end
