# frozen_string_literal: true

# name: discourse-points-mall
# about: A points mall plugin that integrates with discourse-gamification for check-ins and shop
# version: 0.1.1
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

module ::DiscoursePointsMall
  PLUGIN_NAME = "discourse-points-mall"
end

require_relative "lib/discourse_points_mall/engine"
require_relative "lib/discourse_points_mall/points_manager"

after_initialize do
  add_to_class(:user, :points_balance) do
    DiscoursePointsMall::PointsManager.balance_for(self)
  end

  require_relative "app/models/points_mall_product"
  require_relative "app/models/points_mall_order"
  require_relative "app/models/points_mall_checkin"
  require_relative "app/models/points_mall_address"
  require_relative "app/models/points_mall_makeup_card"

  require_relative "app/serializers/discourse_points_mall/product_serializer"
  require_relative "app/serializers/discourse_points_mall/order_serializer"
  require_relative "app/serializers/discourse_points_mall/checkin_serializer"

  require_relative "app/controllers/discourse_points_mall/products_controller"
  require_relative "app/controllers/discourse_points_mall/orders_controller"
  require_relative "app/controllers/discourse_points_mall/checkins_controller"
  require_relative "app/controllers/discourse_points_mall/points_controller"
  require_relative "app/controllers/discourse_points_mall/addresses_controller"
  require_relative "app/controllers/discourse_points_mall/pages_controller"
  require_relative "app/controllers/discourse_points_mall/admin_products_controller"
  require_relative "app/controllers/discourse_points_mall/admin_orders_controller"
  require_relative "app/controllers/discourse_points_mall/admin_checkins_controller"

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
      resources :addresses, only: %i[index create update destroy]
    end

    scope "/admin/plugins/discourse-points-mall", constraints: AdminConstraint.new do
      get "/" => "admin/plugins#index", format: false
      get "/manage" => "admin/plugins#index", format: false

      get "/manage/products" => "discourse_points_mall/admin_products#index"
      post "/manage/products" => "discourse_points_mall/admin_products#create"
      put "/manage/products/:id" => "discourse_points_mall/admin_products#update"
      delete "/manage/products/:id" => "discourse_points_mall/admin_products#destroy"

      get "/manage/orders" => "discourse_points_mall/admin_orders#index"
      put "/manage/orders/:id" => "discourse_points_mall/admin_orders#update"

      get "/manage/checkins" => "discourse_points_mall/admin_checkins#index"
    end
  end

  add_to_serializer(:current_user, :points_balance) do
    object.points_balance
  end
end
