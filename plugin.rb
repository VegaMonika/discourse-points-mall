# frozen_string_literal: true

# name: discourse-points-mall
# about: A points mall plugin that integrates with discourse-gamification for check-ins and shop
# version: 0.2.1
# authors: VegaMonika
# url: https://github.com/VegaMonika/discourse-points-mall
# required_version: 2.7.0

enabled_site_setting :points_mall_enabled

register_asset "stylesheets/common/points-mall.scss"
register_asset "stylesheets/mobile/points-mall.scss", :mobile

register_svg_icon "gift"
register_svg_icon "calendar-check"
register_svg_icon "list"
register_svg_icon "shopping-cart"
register_svg_icon "inbox"
register_svg_icon "clock-rotate-left"
register_svg_icon "circle-info"
register_svg_icon "box"
register_svg_icon "bolt"
register_svg_icon "user"
register_svg_icon "rotate-right"
register_svg_icon "plus"
register_svg_icon "save"
register_svg_icon "trash-can"
register_svg_icon "trophy"
register_svg_icon "wallet"
register_svg_icon "minus"
register_svg_icon "coins"
register_svg_icon "magnifying-glass"
register_svg_icon "receipt"
register_svg_icon "box-open"

module ::DiscoursePointsMall
  PLUGIN_NAME = "discourse-points-mall"

  COSMETIC_EXPIRY_FIELDS = {
    "jn_cosmetic_title_expires_at" => %w[
      jn_cosmetic_title
      jn_cosmetic_title_expires_at
      jn_previous_title_before_cosmetic
    ],
    "jn_cosmetic_avatar_frame_expires_at" => %w[
      jn_cosmetic_avatar_frame
      jn_cosmetic_avatar_frame_expires_at
    ],
    "jn_cosmetic_card_border_expires_at" => %w[
      jn_cosmetic_card_border
      jn_cosmetic_card_border_expires_at
    ],
    "jn_cosmetic_profile_background_expires_at" => %w[
      jn_cosmetic_profile_background
      jn_cosmetic_profile_background_expires_at
    ],
    "jn_cosmetic_post_signature_expires_at" => %w[
      jn_cosmetic_post_signature
      jn_cosmetic_post_signature_expires_at
    ],
    "jn_cosmetic_svip_glow_expires_at" => %w[
      jn_cosmetic_svip_glow
      jn_cosmetic_svip_glow_expires_at
    ],
    "jn_cosmetic_theme_skin_expires_at" => %w[
      jn_cosmetic_theme_skin
      jn_cosmetic_theme_skin_expires_at
    ],
  }.freeze
end

require_relative "lib/discourse_points_mall/engine"
require_relative "lib/discourse_points_mall/points_manager"
require_relative "lib/discourse_points_mall/makeup_pricing"

after_initialize do
  add_to_class(:user, :points_balance) do
    DiscoursePointsMall::PointsManager.balance_for(self)
  end

  require_relative "app/models/points_mall_product"
  require_relative "app/models/points_mall_order"
  require_relative "app/models/points_mall_checkin"
  require_relative "app/models/points_mall_address"
  require_relative "app/models/points_mall_makeup_card"
  require_relative "app/models/points_mall_shout"

  require_relative "app/serializers/discourse_points_mall/product_serializer"
  require_relative "app/serializers/discourse_points_mall/order_serializer"
  require_relative "app/serializers/discourse_points_mall/checkin_serializer"

  require_relative "app/controllers/discourse_points_mall/products_controller"
  require_relative "app/controllers/discourse_points_mall/orders_controller"
  require_relative "app/controllers/discourse_points_mall/checkins_controller"
  require_relative "app/controllers/discourse_points_mall/points_controller"
  require_relative "app/controllers/discourse_points_mall/addresses_controller"
  require_relative "app/controllers/discourse_points_mall/inventory_controller"
  require_relative "app/controllers/discourse_points_mall/pages_controller"
  require_relative "app/controllers/discourse_points_mall/admin_products_controller"
  require_relative "app/controllers/discourse_points_mall/admin_orders_controller"
  require_relative "app/controllers/discourse_points_mall/admin_checkins_controller"
  require_relative "app/controllers/discourse_points_mall/shouts_controller"

  add_admin_route(
    "points_mall.admin.title",
    "discourse-points-mall",
    { use_new_show_route: true },
  )

  Discourse::Application.routes.append do
    scope module: "discourse_points_mall", path: "/points-mall" do
      get "/" => "pages#index", format: false
      resources :products, only: [:index, :show]
      resources :orders, only: [:index, :create, :show]
      resources :checkins, only: [:index, :create]
      get "/checkins/summary" => "checkins#summary"
      post "/checkins/makeup" => "checkins#makeup"
      get "/points/ledger" => "points#ledger"
      get "/shouts" => "shouts#index"
      post "/shouts" => "shouts#create"
      delete "/shouts/:id" => "shouts#destroy"
      get "/inventory" => "inventory#index"
      post "/inventory/equip" => "inventory#equip"
      post "/inventory/unequip" => "inventory#unequip"
      resources :addresses, only: %i[index create update destroy]
    end

    scope "/admin/plugins/discourse-points-mall", constraints: AdminConstraint.new do
      get "/" => "admin/plugins#index", format: false
      get "/manage" => "admin/plugins#index", format: false

      get "/manage/products" => "discourse_points_mall/admin_products#index"
      post "/manage/products" => "discourse_points_mall/admin_products#create"
      put "/manage/products/:id" => "discourse_points_mall/admin_products#update"
      delete "/manage/products/:id" => "discourse_points_mall/admin_products#destroy"
      put "/manage/makeup-config" => "discourse_points_mall/admin_products#update_makeup_config"

      get "/manage/orders" => "discourse_points_mall/admin_orders#index"
      put "/manage/orders/:id" => "discourse_points_mall/admin_orders#update"

      get "/manage/checkins" => "discourse_points_mall/admin_checkins#index"
    end
  end

  add_to_serializer(:current_user, :points_balance) do
    object.points_balance
  end

  module ::Jobs
    class PointsMallExpireCosmetics < ::Jobs::Scheduled
      every 1.day

      def execute(_args)
        now = Time.zone.now

        DiscoursePointsMall::COSMETIC_EXPIRY_FIELDS.each do |expires_field, fields|
          ::UserCustomField
            .where(name: expires_field)
            .where("value IS NOT NULL AND value != ''")
            .find_each do |expires_custom_field|
              expires_at = Time.zone.parse(expires_custom_field.value) rescue nil
              next unless expires_at && expires_at <= now

              user = ::User.find_by(id: expires_custom_field.user_id)
              next unless user

              if expires_field == "jn_cosmetic_title_expires_at"
                previous_title = user.custom_fields["jn_previous_title_before_cosmetic"].to_s.presence
                user.title = previous_title
                user.save!
              end

              ::UserCustomField.where(user_id: user.id, name: fields).destroy_all
            end
        end
      end
    end

    # 小喇叭：每小时清理超过设定时长（默认 24 小时）的留言，实现"满一天自动重置"
    class PointsMallCleanupShouts < ::Jobs::Scheduled
      every 1.hour

      def execute(_args)
        hours = SiteSetting.points_mall_shout_ttl_hours.to_i
        return if hours <= 0

        PointsMallShout.where("created_at < ?", hours.hours.ago).delete_all
      end
    end
  end
end
