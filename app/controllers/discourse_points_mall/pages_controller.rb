# frozen_string_literal: true

module DiscoursePointsMall
  class PagesController < ::ApplicationController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME
    skip_before_action :check_xhr

    before_action :ensure_logged_in

    def index
      raise Discourse::NotFound unless SiteSetting.points_mall_enabled

      render "default/empty"
    end
  end
end
