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
      redeemed_counts = ::PointsMallOrder.group(:product_id).count
      groups = ::Group.where(automatic: false).order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } }
      render json: {
        products: products.map { |product| serialize_product(product, redeemed_counts[product.id].to_i) },
        makeup: makeup_status_payload,
        groups: groups,
      }
    end

    def create
      product = ::PointsMallProduct.new(permitted_product_params)

      if product.save
        render json: { product: serialize_product(product, 0) }
      else
        render_json_error(product.errors.full_messages.join(", "), status: 422)
      end
    end

    def update_makeup_config
      tiers = permitted_makeup_config_params
      validate_makeup_tiers!(tiers)

      SiteSetting.points_mall_makeup_price_tier_1 = tiers[:tier_1]
      SiteSetting.points_mall_makeup_price_tier_2 = tiers[:tier_2]
      SiteSetting.points_mall_makeup_price_tier_3 = tiers[:tier_3]

      ::PointsMallProduct.ensure_makeup_card!

      render json: { makeup: makeup_status_payload }
    rescue ArgumentError => error
      render_json_error(error.message, status: 422)
    end

    def update
      attrs = permitted_product_params
      if @product.makeup_card?
        attrs[:product_type] = "virtual"
        attrs[:stock] = nil
        attrs[:points_cost] = DiscoursePointsMall::MakeupPricing.first_tier
      end

      if @product.update(attrs)
        redeemed_count = ::PointsMallOrder.where(product_id: @product.id).count
        render json: { product: serialize_product(@product, redeemed_count) }
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
          :category,
          :featured,
          :badge_text,
          :image_url,
          :enabled,
          :price_brl,
          :external_url,
          :grant_group_id,
          :grant_duration_days,
          :sort_order,
        ).to_h

      attrs[:points_cost] = attrs[:points_cost].to_i if attrs.key?(:points_cost)
      attrs[:price_brl] = attrs[:price_brl].present? ? attrs[:price_brl].to_f : nil if attrs.key?(:price_brl)
      attrs[:external_url] = attrs[:external_url].to_s.strip.presence if attrs.key?(:external_url)
      attrs[:sort_order] = attrs[:sort_order].to_i if attrs.key?(:sort_order)
      attrs[:category] = attrs[:category].to_s.strip.presence if attrs.key?(:category)
      attrs[:badge_text] = attrs[:badge_text].to_s.strip.presence if attrs.key?(:badge_text)

      if attrs.key?(:grant_group_id)
        gid = attrs[:grant_group_id].to_s.strip
        attrs[:grant_group_id] = gid.present? ? gid.to_i : nil
      end

      if attrs.key?(:grant_duration_days)
        days = attrs[:grant_duration_days].to_s.strip
        attrs[:grant_duration_days] = days.present? ? days.to_i : nil
      end

      if attrs.key?(:stock)
        stock = attrs[:stock].to_s.strip
        attrs[:stock] = stock.blank? || stock == "-1" ? nil : stock.to_i
      end

      unless ::PointsMallProduct.has_category?
        attrs.delete(:category)
      end

      unless ::PointsMallProduct.has_featured?
        attrs.delete(:featured)
      end

      unless ::PointsMallProduct.has_badge_text?
        attrs.delete(:badge_text)
      end

      attrs[:enabled] = to_bool(attrs[:enabled]) if attrs.key?(:enabled)
      attrs[:featured] = to_bool(attrs[:featured]) if attrs.key?(:featured)
      attrs
    end

    def permitted_makeup_config_params
      attrs = params.permit(:tier_1, :tier_2, :tier_3).to_h.symbolize_keys
      {
        tier_1: attrs[:tier_1].to_i,
        tier_2: attrs[:tier_2].to_i,
        tier_3: attrs[:tier_3].to_i,
      }
    end

    def validate_makeup_tiers!(tiers)
      invalid = tiers.any? { |_key, value| value <= 0 }
      raise ArgumentError, "补签卡阶梯价格必须大于 0" if invalid
    end

    def to_bool(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end

    def serialize_product(product, redeemed_count = 0)
      {
        id: product.id,
        name: product.name,
        description: product.description,
        points_cost: product.points_cost,
        stock: product.stock || -1,
        product_type: product.product_type,
        category: (::PointsMallProduct.has_category? ? product.category : nil),
        featured: (::PointsMallProduct.has_featured? ? product.featured : false),
        badge_text: (::PointsMallProduct.has_badge_text? ? product.badge_text : nil),
        image_url: product.image_url,
        enabled: product.enabled,
        price_brl: (product.respond_to?(:price_brl) ? product.price_brl : nil),
        external_url: (product.respond_to?(:external_url) ? product.external_url : nil),
        grant_group_id: (product.respond_to?(:grant_group_id) ? product.grant_group_id : nil),
        grant_duration_days: (product.respond_to?(:grant_duration_days) ? product.grant_duration_days : nil),
        sort_order: product.sort_order,
        redeemed_count: redeemed_count,
        product_key: (product.respond_to?(:product_key) ? product.product_key : nil),
        is_makeup_card: product.makeup_card?,
      }
    end

    def makeup_status_payload
      DiscoursePointsMall::MakeupPricing.payload.merge(
        feature_ready: ::PointsMallProduct.has_product_key? && defined?(::PointsMallMakeupCard) && ::PointsMallMakeupCard.table_exists?,
      )
    end
  end
end
