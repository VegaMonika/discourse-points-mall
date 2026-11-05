# frozen_string_literal: true

module ::DiscoursePointsMall
  module Cosmetics
    AVATAR_FRAME_KEY = /\Acosmetic_avatar_frame_(?<value>[a-z0-9_]+)_(?<days>\d+)d\z/.freeze

    STATIC_PRODUCTS = {
      "cosmetic_title_launch_trainer_30d" => {
        kind: "title",
        title: "开服训练家",
        value: "开服训练家",
        duration_days: 30,
      },
      "cosmetic_title_shiny_collector_30d" => {
        kind: "title",
        title: "闪光收藏家",
        value: "闪光收藏家",
        duration_days: 30,
      },
      "cosmetic_title_zenless_resident_30d" => {
        kind: "title",
        title: "绝区零居民",
        value: "绝区零居民",
        duration_days: 30,
      },
      "cosmetic_avatar_frame_neon_30d" => {
        kind: "avatar_frame",
        value: "neon_aqua",
        duration_days: 30,
      },
      "cosmetic_card_border_holo_30d" => {
        kind: "card_border",
        value: "holo_gold",
        duration_days: 30,
      },
      "cosmetic_profile_bg_zzz_30d" => {
        kind: "profile_background",
        value: "zenless_blue",
        duration_days: 30,
      },
      "cosmetic_post_signature_sakura_30d" => {
        kind: "post_signature",
        value: "sakura_tail",
        duration_days: 30,
      },
      "cosmetic_svip_glow_30d" => {
        kind: "svip_glow",
        value: "aurora",
        duration_days: 30,
        requires_group: "SVIP",
      },
      "cosmetic_theme_skin_ticket" => {
        kind: "theme_skin",
        value: "starrail_neon",
        duration_days: nil,
      },
    }.freeze

    module_function

    def config_for(product_or_key)
      key = product_or_key.respond_to?(:product_key) ? product_or_key.product_key : product_or_key
      key = key.to_s
      return STATIC_PRODUCTS[key] if STATIC_PRODUCTS.key?(key)

      match = AVATAR_FRAME_KEY.match(key)
      return nil unless match

      {
        kind: "avatar_frame",
        value: match[:value],
        duration_days: match[:days].to_i,
      }
    end

    def configured?(product_or_key)
      config_for(product_or_key).present?
    end

    def product_for(kind, value)
      return nil unless defined?(::PointsMallProduct)

      ::PointsMallProduct.where(enabled: true).order(:sort_order, :id).detect do |product|
        config = config_for(product)
        config && config[:kind].to_s == kind.to_s && cosmetic_value(config).to_s == value.to_s
      end
    end

    def cosmetic_value(config)
      config[:value] || config[:title]
    end

    # 公开装备表：所有人当前戴着且没过期的装饰（给前端在帖子、资料卡、列表里画头像框等用）
    EQUIPPED_CACHE_KEY = "jn-points-mall-equipped-v1"
    PUBLIC_KINDS = %w[avatar_frame card_border profile_background post_signature svip_glow].freeze

    def equipped_map
      Discourse.cache.fetch(EQUIPPED_CACHE_KEY, expires_in: 2.minutes) { build_equipped_map }
    end

    def bust_equipped_cache!
      Discourse.cache.delete(EQUIPPED_CACHE_KEY)
    end

    def build_equipped_map
      value_fields = PUBLIC_KINDS.map { |k| "jn_cosmetic_#{k}" }
      expiry_fields = value_fields.map { |f| "#{f}_expires_at" }
      rows = ::UserCustomField.where(name: value_fields + expiry_fields).where.not(value: [nil, ""]).pluck(:user_id, :name, :value)
      by_user = Hash.new { |h, k| h[k] = {} }
      rows.each { |uid, name, value| by_user[uid][name] = value }
      usernames = ::User.where(id: by_user.keys).pluck(:id, :username_lower).to_h
      images = {}
      now = Time.zone.now
      result = {}
      by_user.each do |uid, fields|
        entry = {}
        PUBLIC_KINDS.each do |kind|
          value = fields["jn_cosmetic_#{kind}"].presence or next
          expires = (Time.zone.parse(fields["jn_cosmetic_#{kind}_expires_at"].to_s) rescue nil)
          next if expires && expires <= now
          entry[kind] = value
          if %w[avatar_frame profile_background].include?(kind)
            images[[kind, value]] ||= product_for(kind, value)&.image_url
            entry["#{kind}_image"] = images[[kind, value]] if images[[kind, value]]
          end
        end
        result[usernames[uid]] = entry if entry.present? && usernames[uid]
      end
      result
    end

    # 订单备注原来直接显示 JSON，这里转成人话
    def notes_text(raw)
      text = raw.to_s
      return text unless text.start_with?("{")
      data = JSON.parse(text) rescue (return text)
      parts = []
      parts << "星辉宝库奖励" if data["source"] == "star_vault"
      if data["expires_at"].present?
        t = (Time.zone.parse(data["expires_at"]) rescue nil)
        parts << "有效期至 #{t.in_time_zone("Asia/Shanghai").strftime("%Y-%m-%d %H:%M")}" if t
      elsif data["kind"].present? || data["source"] == "star_vault"
        parts << "长期有效"
      end
      parts.join(" · ").presence || ""
    end
  end
end
