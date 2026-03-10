# frozen_string_literal: true

module DiscoursePointsMall
  class AdminProductsController < ::Admin::AdminController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    rescue_from(StandardError) do |error|
      Rails.logger.error("[points-mall] AdminProductsController: #{error.full_message}")
      raise error
    end

    before_action :find_product, only: %i[update destroy]

    def index
      ::PointsMallProduct.ensure_makeup_card!
      products = ::PointsMallProduct.order(sort_order: :asc, created_at: :desc)
      render json: {
        products: products.map { |product| serialize_product(product) },
        makeup: makeup_status_payload,
      }
    end

    def create
      product = ::PointsMallProduct.new(permitted_product_params)

      if product.save
        render json: { product: serialize_product(product) }
      else
        render_json_error(product.errors.full_messages.join(", "), status: 422)
      end
    end

    def update
      attrs = permitted_product_params
      if @product.makeup_card?
        attrs[:product_type] = "virtual"
        attrs[:stock] = nil
      end

      if @product.update(attrs)
        render json: { product: serialize_product(@product) }
      else
        render_json_error(@product.errors.full_messages.join(", "), status: 422)
      end
    end

    def destroy
      if @product.makeup_card?
        return render_json_error(I18n.t("points_mall.admin.errors.makeup_card_protected"), status: 422)
      end

      if ::PointsMallOrder.where(product_id: @product.id).exists?
        return render_json_error(I18n.t("points_mall.admin.errors.product_has_orders"), status: 422)
      end

      @product.destroy!
      render json: success_json
    end

    private

    def find_product
      @product = ::PointsMallProduct.find(params[:id])
    end

    def permitted_product_params
      attrs =
        params.permit(
          :name,
          :description,
          :points_cost,
          :stock,
          :product_type,
          :image_url,
          :enabled,
          :sort_order,
        ).to_h

      attrs[:points_cost] = attrs[:points_cost].to_i if attrs.key?(:points_cost)
      attrs[:sort_order] = attrs[:sort_order].to_i if attrs.key?(:sort_order)

      if attrs.key?(:stock)
        stock = attrs[:stock].to_s.strip
        attrs[:stock] = stock.blank? || stock == "-1" ? nil : stock.to_i
      end

      attrs[:enabled] = to_bool(attrs[:enabled]) if attrs.key?(:enabled)
      attrs
    end

    def to_bool(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def serialize_product(product)
      {
        id: product.id,
        name: product.name,
        description: product.description,
        points_cost: product.points_cost,
        stock: product.stock || -1,
        product_type: product.product_type,
        image_url: product.image_url,
        enabled: product.enabled,
        sort_order: product.sort_order,
        product_key: (product.respond_to?(:product_key) ? product.product_key : nil),
        is_makeup_card: product.makeup_card?,
      }
    end

    def makeup_status_payload
      {
        feature_ready: ::PointsMallProduct.has_product_key? && defined?(::PointsMallMakeupCard) && ::PointsMallMakeupCard.table_exists?,
        prices: (defined?(::PointsMallMakeupCard) ? ::PointsMallMakeupCard::PRICE_TIERS : [1000, 3000, 5000]),
      }
    end
  end
end
