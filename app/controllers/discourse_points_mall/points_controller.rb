# frozen_string_literal: true

module DiscoursePointsMall
  class PointsController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    before_action :ensure_logged_in

    MAX_EVENTS = 200
    SCORABLE_LOOKBACK_DAYS = 90

    SCORABLE_LABELS = {
      "post_created" => "Publicou resposta",
      "topic_created" => "Criou tópico",
      "like_received" => "Recebeu curtida",
      "like_given" => "Deu curtida",
      "day_visited" => "Acesso diário",
      "post_read" => "Leu postagem",
      "time_read" => "Tempo de leitura",
      "solutions" => "Solução aceita",
      "flag_created" => "Sinalização aceita",
      "user_invited" => "Convidou usuário",
      "chat_message_created" => "Mensagem no chat",
      "chat_reaction_given" => "Reação dada no chat",
      "chat_reaction_received" => "Reação recebida no chat",
      "reaction_given" => "Deu reação",
      "reaction_received" => "Recebeu reação",
    }.freeze

    def ledger
      entries = (load_events.map { |e| serialize_event(e) } + load_scorable_entries)
      entries.sort_by! { |e| [e[:date].to_s, e[:created_at].to_s] }
      entries.reverse!
      entries = entries.first(MAX_EVENTS)

      render json: {
        summary: ledger_summary(entries),
        events: entries,
      }
    end

    private

    def load_events
      return [] unless defined?(::DiscourseGamification::GamificationScoreEvent)

      ::DiscourseGamification::GamificationScoreEvent
        .where(user_id: current_user.id)
        .order(date: :desc, created_at: :desc)
        .limit(MAX_EVENTS)
        .to_a
    rescue StandardError => e
      Rails.logger.warn("[points-mall] load ledger events failed: #{e.class} #{e.message}")
      []
    end

    # 把 gamification 的自动积分（发帖、点赞等 scorable）合并进明细
    def load_scorable_entries
      return [] unless defined?(::DiscourseGamification::Scorable)

      leaderboard = PointsManager.default_leaderboard
      return [] if leaderboard.blank?

      since = SCORABLE_LOOKBACK_DAYS.days.ago.to_date
      entries = []

      ::DiscourseGamification::Scorable.subclasses.each do |scorable|
        next unless scorable.enabled?(leaderboard: leaderboard)

        key = scorable.scorable_key
        label = SCORABLE_LABELS[key] || key

        begin
          rows = DB.query(<<~SQL, since: since, current_user_id: current_user.id)
            SELECT s.date, s.points
            FROM ( #{scorable.query(leaderboard: leaderboard)} ) AS s
            WHERE s.user_id = :current_user_id
          SQL

          rows.each do |row|
            points = row.points.to_i
            next if points.zero?

            entries << {
              id: nil,
              date: row.date.to_date,
              created_at: row.date,
              points: points,
              description: label,
              category: "community",
              direction: points.negative? ? "expense" : "income",
            }
          end
        rescue StandardError => e
          Rails.logger.warn("[points-mall] scorable #{key} ledger failed: #{e.class} #{e.message}")
        end
      end

      entries
    rescue StandardError => e
      Rails.logger.warn("[points-mall] load scorable entries failed: #{e.class} #{e.message}")
      []
    end

    def ledger_summary(entries)
      category_counts = Hash.new(0)
      income_count = 0
      expense_count = 0

      entries.each do |entry|
        category_counts[entry[:category]] += 1
        points = entry[:points].to_i
        income_count += 1 if points.positive?
        expense_count += 1 if points.negative?
      end

      {
        current_points: current_user.points_balance.to_i,
        total_count: entries.length,
        income_count: income_count,
        expense_count: expense_count,
        checkin_count: category_counts["checkin"],
        shop_count: category_counts["shop"],
        community_count: category_counts["community"],
        other_count: category_counts["other"],
      }
    end

    def serialize_event(event)
      points = event.points.to_i
      category = event_category(event.description)

      {
        id: event.id,
        date: event.date,
        created_at: event.created_at,
        points: points,
        description: translate_description(event.description.presence || I18n.t("points_mall.points.unknown_description")),
        category: category,
        direction: points.negative? ? "expense" : "income",
      }
    end

    def translate_description(description)
      text = description.to_s.strip
      return "Check-in Diário" if text.include?("每日签到") || text.include?("签到奖励") || text == "签到"
      return "Recuperação de Check-in" if text.include?("补签卡") || text == "补签"
      return "Compra de Cartão de Check-in" if text.include?("积分商城购买补签卡")
      return "Resgate de Tráfego / Nuvem" if text.include?("积分商城兑换网盘流量")
      return "Resgate de Cosmético / Insígnia" if text.include?("积分商城兑换身份装饰")
      return "Compra na Loja de Pontos" if text.include?("积分商城兑换商品") || text.include?("购买商品")
      return "Envio de Megafone" if text.include?("小喇叭发言") || text == "小喇叭"
      return "Publicou resposta" if text == "发布回复"
      return "Criou tópico" if text == "发布主题"
      return "Recebeu curtida" if text == "获得点赞"
      return "Deu curtida" if text == "送出点赞"
      return "Acesso diário" if text == "每日访问"
      text
    end

    def event_category(description)
      text = description.to_s.downcase
      return "checkin" if text.include?("签到") || text.include?("check-in") || text.include?("checkin") || text.include?("每日")
      return "shop" if text.include?("商城") || text.include?("兑换商品") || text.include?("补签卡") || text.include?("loja") || text.include?("compra")
      return "community" if text.include?("社区") || text.include?("topic") || text.include?("reply") || text.include?("like") || text.include?("点赞") || text.include?("resposta") || text.include?("tópico")
      "other"
    end
  end
end
