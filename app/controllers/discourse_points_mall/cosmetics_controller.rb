# frozen_string_literal: true

module DiscoursePointsMall
  # 公开：所有人当前装备的装饰（游客也能看到别人的头像框）。结果缓存 2 分钟，装备/卸下/购买时会清缓存。
  class CosmeticsController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    skip_before_action :check_xhr, raise: false
    skip_before_action :redirect_to_login_if_required, raise: false

    def equipped
      response.headers["Cache-Control"] = "public, max-age=60"
      render json: { users: DiscoursePointsMall::Cosmetics.equipped_map }
    end
  end
end
