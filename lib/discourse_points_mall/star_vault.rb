# frozen_string_literal: true

require "securerandom"

module DiscoursePointsMall
  class StarVault
    class Unavailable < StandardError; end
    TIME_ZONE = "Asia/Shanghai"
    # 2026-11-05 v2：加入 11 个新动态头像框（1 天体验），权重总和仍为 100
    POOL_VERSION = "daily-v2"
    NEW_ANIM_FRAMES = %w[star_orbit_gold sakura_spring snow_crystal heart_ribbon_red cyber_neon_cyan firefly_forest flame_orange ocean_wave_blue blue_ribbon_heart].freeze
    POOL = [
      { key: "cosmetic_avatar_frame_chibi_blue_heart_30d", days: 1, weight: 20, rarity: "blue", tier: "星尘", kind: "cosmetic" },
      { key: "cosmetic_avatar_frame_orange_heart_guard_30d", days: 1, weight: 15, rarity: "blue", tier: "星尘" },
      *NEW_ANIM_FRAMES.map { |k| { key: "cosmetic_avatar_frame_anim_#{k}_30d", days: 1, weight: 3, rarity: "purple", tier: "月辉" } },
      { key: "cosmetic_avatar_frame_cloud_ink_sword_30d", days: 3, weight: 8, rarity: "purple", tier: "月辉" },
      { key: "cosmetic_avatar_frame_purple_moon_tea_30d", days: 3, weight: 5, rarity: "purple", tier: "月辉" },
      { key: "cosmetic_avatar_frame_crimson_spear_30d", days: 7, weight: 5, rarity: "gold", tier: "星耀" },
      { key: "cosmetic_avatar_frame_anim_silver_wings_30d", days: 1, weight: 1, rarity: "gold", tier: "星耀" },
      { key: "cosmetic_avatar_frame_anim_royal_crown_gold_30d", days: 1, weight: 1, rarity: "gold", tier: "星耀" },
      { key: "pokerogue_voucher_regular", weight: 13, rarity: "purple", tier: "游戏道具", kind: "game", voucher_type: 0, count: 1 },
      { key: "pokerogue_voucher_plus", weight: 3, rarity: "gold", tier: "游戏道具", kind: "game", voucher_type: 1, count: 1 },
      { key: "netdisk_traffic_1gb", weight: 2, rarity: "gold", tier: "云盘流量", kind: "traffic", mb: 1024, valid_days: 0 },
    ].map(&:freeze).freeze

    def self.day(time = Time.current)
      time.in_time_zone(TIME_ZONE).to_date
    end

    def self.next_reset(time = Time.current)
      time.in_time_zone(TIME_ZONE).tomorrow.beginning_of_day.iso8601
    end

    def self.pool
      products = PointsMallProduct.where(enabled: true, product_key: POOL.map { |p| p[:key] }).index_by(&:product_key)
      POOL.map do |entry|
        product = products[entry[:key]]
        kind = entry[:kind] || "cosmetic"
        config = Cosmetics.config_for(product)
        raise Unavailable, "奖池正在维护，今日机会不会扣除。" unless product && (kind != "cosmetic" || (config && !config[:requires_group]))
        {
          key: entry[:key], product_id: product.id,
          name: entry[:days] ? "#{product.name} · #{entry[:days]}天体验" : product.name,
          image_url: product.image_url, days: entry[:days],
          probability: entry[:weight], rarity: entry[:rarity], tier: entry[:tier],
          kind: kind, voucher_type: entry[:voucher_type], count: entry[:count], mb: entry[:mb], valid_days: entry[:valid_days],
        }
      end
    end

    def self.pick(pool, roll: SecureRandom.random_number(100))
      raise ArgumentError, "invalid draw" unless (0...100).cover?(roll) && roll.is_a?(Integer)
      total = 0
      pool.find { |item| total += item[:probability]; roll < total } || raise(Unavailable, "奖池配置无效")
    end

    def self.present(draw)
      return nil unless draw
      delivery = draw.delivery_state
      delivery = "needs_review" if delivery == "delivering" && draw.attempted_at && draw.attempted_at < 3.minutes.ago
      draw.reward.merge("draw_id" => draw.id, "order_id" => draw.order_id, "draw_on" => draw.draw_on.iso8601, "delivery_state" => delivery, "delivery_error" => draw.last_error)
    end

    def self.status(user)
      now = Time.current
      enabled = SiteSetting.points_mall_star_vault_enabled
      today = PointsMallVaultDraw.find_by(user_id: user.id, draw_on: day(now))
      available_pool = pool
      {
        enabled: enabled, available: enabled && today.nil?, pool: available_pool,
        today: present(today), next_reset_at: next_reset(now), timezone: TIME_ZONE,
        recent: PointsMallVaultDraw.where(user_id: user.id).order(id: :desc).limit(8).map { |draw| present(draw) },
      }
    rescue Unavailable => e
      { enabled: false, available: false, pool: [], today: present(today), error: e.message, next_reset_at: next_reset(now), recent: [] }
    end

    def self.open!(user)
      raise Unavailable, "宝箱活动暂未开放。" unless SiteSetting.points_mall_star_vault_enabled
      draw = nil
      created = false
      PointsMallVaultDraw.transaction do
        locked_user = User.lock.find(user.id)
        now = Time.current
        draw = PointsMallVaultDraw.find_by(user_id: locked_user.id, draw_on: day(now))
        unless draw
          reward = pick(pool)
          product = PointsMallProduct.lock.find(reward[:product_id])
          raise Unavailable, "奖池正在维护，今日机会不会扣除。" unless product.enabled?
          cosmetic = reward[:kind] == "cosmetic"
          expires_at = cosmetic ? (now + reward[:days].days).iso8601 : nil
          notes = {
            source: "star_vault", pool_version: POOL_VERSION, reward_name: reward[:name],
            granted_at: now.iso8601, expires_at: expires_at,
          }
          order = PointsMallOrder.create!(user: locked_user, product: product, points_spent: 0, status: cosmetic ? "completed" : "processing", notes: notes.to_json)
          draw = PointsMallVaultDraw.create!(user: locked_user, order: order, draw_on: day(now), delivery_state: cosmetic ? "completed" : "pending", reward: reward.merge(granted_at: now.iso8601, expires_at: expires_at, pool_version: POOL_VERSION))
          created = true
        end
      end
      { result: present(draw), created: created, next_reset_at: next_reset }
    end
  end
end
