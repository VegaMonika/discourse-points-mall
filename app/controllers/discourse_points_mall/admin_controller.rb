# frozen_string_literal: true

module DiscoursePointsMall
  class AdminController < ::Admin::AdminController
    requires_plugin DiscoursePointsMall::PLUGIN_NAME

    def index
      render json: success_json
    end
  end
end
