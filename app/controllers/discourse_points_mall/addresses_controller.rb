# frozen_string_literal: true

module DiscoursePointsMall
  class AddressesController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :find_address, only: %i[update destroy]

    def index
      addresses = ::PointsMallAddress.for_user(current_user.id).ordered
      render json: { addresses: addresses.map { |address| serialize_address(address) } }
    end

    def create
      attrs = permitted_address_params
      attrs[:user_id] = current_user.id
      attrs[:is_default] = true if first_address_for_user?

      address = ::PointsMallAddress.new(attrs)

      if address.save
        render json: { address: serialize_address(address) }
      else
        render_json_error(address.errors.full_messages.join(", "), status: 422)
      end
    end

    def update
      unless @address.user_id == current_user.id
        return render_json_error(I18n.t("points_mall.errors.unauthorized"), status: 403)
      end

      if @address.update(permitted_address_params)
        render json: { address: serialize_address(@address) }
      else
        render_json_error(@address.errors.full_messages.join(", "), status: 422)
      end
    end

    def destroy
      unless @address.user_id == current_user.id
        return render_json_error(I18n.t("points_mall.errors.unauthorized"), status: 403)
      end

      @address.destroy!
      render json: success_json
    end

    private

    def first_address_for_user?
      ::PointsMallAddress.for_user(current_user.id).empty?
    end

    def find_address
      @address = ::PointsMallAddress.find(params[:id])
    end

    def permitted_address_params
      attrs = params.permit(:recipient_name, :phone, :address_line, :is_default).to_h
      attrs[:is_default] = ActiveModel::Type::Boolean.new.cast(attrs[:is_default]) if attrs.key?(:is_default)
      attrs
    end

    def serialize_address(address)
      {
        id: address.id,
        recipient_name: address.recipient_name,
        phone: address.phone,
        address_line: address.address_line,
        full_text: address.full_text,
        is_default: address.is_default,
        created_at: address.created_at,
      }
    end
  end
end
