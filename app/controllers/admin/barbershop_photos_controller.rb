class Admin::BarbershopPhotosController < Admin::BaseController
  before_action :set_photo, only: [ :edit, :update, :destroy ]

  def index
    @photos = BarbershopPhoto.order(:position, :created_at)
  end

  def new
    @photo = BarbershopPhoto.new(active: true)
  end

  def edit
  end

  def create
    @photo = BarbershopPhoto.new(photo_params)

    if @photo.save
      redirect_to admin_barbershop_photos_path, notice: t(".success")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @photo.update(photo_params)
      redirect_to admin_barbershop_photos_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @photo.destroy
      redirect_to admin_barbershop_photos_path, notice: t(".success")
    else
      redirect_to admin_barbershop_photos_path, alert: t(".failure")
    end
  end

  private

  def set_photo
    @photo = BarbershopPhoto.find(params.expect(:id))
  end

  def photo_params
    params.expect(barbershop_photo: [ :image, :caption, :active, :position ])
  end
end
