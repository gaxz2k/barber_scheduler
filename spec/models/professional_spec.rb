require 'rails_helper'

RSpec.describe Professional, type: :model do
  it "is valid with name" do
    professional = described_class.new(name: "Gustavo")
    expect(professional).to be_valid
  end

  it "is invalid without name" do
    professional = described_class.new(name: nil)
    expect(professional).not_to be_valid
  end

  it "is invalid with a duplicate name" do
    described_class.create!(name: "Gustavo")
    professional = described_class.new(name: "Gustavo")
    expect(professional).not_to be_valid
  end

  it "is invalid with empty name" do
    professional = described_class.new(name: "")
    expect(professional).not_to be_valid
  end

  describe "photo_upload" do
    def upload(content_type: "image/png", filename: "barbershop.png")
      fixture_file_upload(filename, content_type)
    end

    it "stores the uploaded file's signed_id on the photo column" do
      professional = described_class.new(name: "Gustavo", photo_upload: upload)

      expect { professional.save! }.to change(professional, :photo).from(nil)
    end

    it "resolves the stored photo to a blob" do
      professional = described_class.create!(name: "Gustavo", photo_upload: upload)

      expect(professional.photo_blob).to be_a(ActiveStorage::Blob)
    end

    it "rejects non-image content types" do
      professional = described_class.new(name: "Gustavo",
        photo_upload: fixture_file_upload("barbershop.png", "text/plain"))

      expect(professional).not_to be_valid
    end

    it "explains that non-image content types must be PNG, JPG or WEBP" do
      professional = described_class.new(name: "Gustavo",
        photo_upload: fixture_file_upload("barbershop.png", "text/plain"))
      professional.validate

      expect(professional.errors[:photo_upload]).to include("deve ser PNG, JPG ou WEBP")
    end

    def mislabeled_text_file
      io = Tempfile.new([ "fake", ".png" ]).tap { |f| f.write("not an image"); f.rewind }
      ActionDispatch::Http::UploadedFile.new(tempfile: io, filename: "fake.png", type: "image/png")
    end

    it "rejects a mislabeled text file" do
      professional = described_class.new(name: "Gustavo", photo_upload: mislabeled_text_file)

      expect(professional).not_to be_valid
    end

    it "explains that a mislabeled text file's content isn't a valid image" do
      professional = described_class.new(name: "Gustavo", photo_upload: mislabeled_text_file)
      professional.validate

      expect(professional.errors[:photo_upload]).to include("o conteúdo não corresponde a uma imagem PNG, JPG ou WEBP válida")
    end

    it "removes the photo when remove_photo is checked and no new upload is sent" do
      professional = described_class.create!(name: "Gustavo", photo_upload: upload)

      professional.update!(remove_photo: "1")

      expect(professional.reload.photo).to be_nil
    end

    it "lets a new upload win over remove_photo in the same submit" do
      professional = described_class.create!(name: "Gustavo", photo_upload: upload)

      professional.update!(remove_photo: "1", photo_upload: upload)

      expect(professional.reload.photo).to be_present
    end

    it "replaces the signed_id when a new upload wins over remove_photo" do
      professional = described_class.create!(name: "Gustavo", photo_upload: upload)
      old_photo = professional.photo

      professional.update!(remove_photo: "1", photo_upload: upload)

      expect(professional.reload.photo).not_to eq(old_photo)
    end
  end
end
