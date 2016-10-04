class Spree::AddressesController < Spree::StoreController
  helper Spree::AddressesHelper
  rescue_from ActiveRecord::RecordNotFound, :with => :render_404
  load_and_authorize_resource :class => Spree::Address

  before_action :instructions_idx_only, only: [:create, :update]

  def index
    @addresses = spree_current_user.addresses
  end

  def create
    # get address in local language and add to params (via another call to maps places api)
    populate_address_local(params)

    @address = spree_current_user.addresses.build(address_params)
    if @address.save  
      spree_current_user.ship_address = spree_current_user.bill_address = @address
      if spree_current_user.save
        @new_default_address = true
      end
    else
      #flash.now[:error] = Spree.t(:address_error)
    end
    respond_with(@address) do |format|
      format.html { redirect_to account_path }
      format.js
    end
  end
  
  def show
    redirect_to account_path
  end

  def edit
    session["user_return_to"] = request.env['HTTP_REFERER']
    @address.state_name ||= @address.state.name if @address.state.present?
  end

  def new
    @address = Spree::Address.default
  end

  def update
    if params[:address][:place_id] != @address.place_id
      populate_address_local(params)
    end
    if @address.editable?
      if @address.update_attributes(address_params)
        if @address.id == spree_current_user.ship_address_id
          spree_current_user.ship_address = spree_current_user.bill_address = @address
          if spree_current_user.save
            @new_default_address = true
          end
        end
      else
        flash.now[:error] = Spree.t(:address_error)
      end
    else
      new_address = @address.clone
      new_address.attributes = address_params
      @address.update_attribute(:deleted_at, Time.now)
      if new_address.save
        if @address.id == spree_current_user.ship_address_id
          spree_current_user.ship_address = spree_current_user.bill_address = new_address
          if spree_current_user.save
            @new_default_address = true
          end
        end
      else
        flash.now[:error] = Spree.t(:address_error)
      end
    end
    respond_with(@address) do |format|
      format.html { redirect_back_or_default(account_path) }
      format.js
    end
  end

  def destroy

    id = @address.id
    @address.destroy

    if (spree_current_user.ship_address.present? and id == spree_current_user.ship_address_id)
      spree_current_user.ship_address = spree_current_user.bill_address = spree_current_user.addresses.first
      if spree_current_user.save
        if spree_current_user.bill_address.blank? and spree_current_user.ship_address.blank?
          if current_order.present? and current_order.adjustments.shipping.eligible.present?
            # no addresses so remove any shipping adjustments if exist
            current_order.adjustments.shipping.eligible.destroy_all
            current_order.save # update store credit (if exists) via process_store_credit to ensure total >0 (overkill?)
          end
          @no_addresses = true
        else
          @new_default_address = true
        end
      end
    end

    flash.now[:notice] = Spree.t(:successfully_removed, :resource => Spree::Address.model_name.human)
    respond_with(@address) do |format|
      format.html { redirect_to account_path }
      format.js
    end
  end

  private

    def address_params
      # make sure place_id and street address are within str limit
      params[:address][:address1] = params[:address][:address1].truncate(255)
      params[:address][:place_id] = params[:address][:place_id].truncate(255)

      params.require(:address).permit(:firstname, :lastname, :company, :address1, :address2, :city, :state_name, :state_id, :zipcode, :country_id, :phone, :delivery_instructions, :require_cutlery, :place_id, :floor, :room, :instructions, :tower, :lat, :lng, :address_local)
    end

    def accurate_title
      Spree.t(:address_accurate_title)
    end

    def instructions_idx_only
      if params[:address][:instructions].present?
        params[:address][:instructions] = params[:address][:instructions].join.gsub(/[^0-9]/, "")
      else
        params[:address][:instructions] = ""
      end
    end

    def populate_address_local(params)
      g = Spree::AddressBook::GoogleMaps.new(Spree::Config[:local_locale])
      success, local_add, lat, lng = g.placedetails(params[:address][:place_id]) rescue [false,"",0.0,0.0]
      ( params[:address].merge!(address_local: local_add) ) if success
    end

end
