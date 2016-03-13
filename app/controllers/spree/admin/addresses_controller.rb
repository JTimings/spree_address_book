module Spree
  module Admin
    class AddressesController < Spree::Admin::BaseController

      helper Spree::AddressesHelper

      before_filter :load_user
      before_action :instructions_idx_only, only: [:create, :update]

      def new
        @address = Spree::Address.default
      end

      def create
        @address = @user.addresses.build(address_params)
        if @address.save   
          @user.ship_address = @user.bill_address = @address
          if @user.save
            @new_default_address = true
          end
        end
        respond_with(@address) do |format|
          format.html { redirect_to spree.admin_users_path(@user) }
          format.js
        end
      end

      def edit
        @address = Spree::Address.find(params[:id])
      end

      def update
        @address = Spree::Address.find(params[:id])
        if @address.editable?
          if @address.update_attributes(address_params)
            if @address.id == @user.ship_address_id
              @user.ship_address = @user.bill_address = @address
              if @user.save
                @new_default_address = true
              end
            end
          else
            @error = true
          end
        else
          new_address = @address.clone
          new_address.attributes = address_params
          @address.update_attribute(:deleted_at, Time.now)
          if new_address.save
            if @address.id == @user.ship_address_id
              @user.ship_address = @user.bill_address = new_address
              if @user.save
                @new_default_address = true
              end
            end
          else
            @error = true
          end
        end
        respond_with(@address) do |format|
          format.html { redirect_to spree.admin_users_path(@user) }
          format.js
        end 
      end

      def destroy
        @address = Spree::Address.find(params[:id])
        id = @address.id
        @address.destroy

        if (@user.ship_address_id.present? and id == @user.ship_address_id)
          @user.ship_address = @user.bill_address = @user.addresses.first
          if @user.save
            if @user.bill_address.blank? and @user.ship_address.blank?
              @no_addresses = true
            else
              @new_default_address = true
            end
          end
        end
        respond_with(@address) do |format|
          format.html { redirect_to spree.admin_users_path(@user) }
          format.js
        end
      end


      private

        def load_user
          @user = Spree::User.find_by_id(params[:user_id])
        end

        def address_params
          params.require(:address).permit(:firstname, :lastname, :company, :address1, :address2, :city, :state_name, :state_id, :zipcode, :country_id, :phone, :delivery_instructions, :require_cutlery, :place_id, :floor, :room, :instructions)
        end

        def instructions_idx_only
          if params[:user_binstructions].present?
            params[:address][:instructions] = params[:user_binstructions].join.gsub(/[^0-9]/, "")
          else
            params[:address][:instructions] = ""
          end
        end

    end
  end
end
