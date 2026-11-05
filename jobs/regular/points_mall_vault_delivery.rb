# frozen_string_literal: true
module Jobs
  class PointsMallVaultDelivery < ::Jobs::Base
    def execute(args)
      DiscoursePointsMall::StarVaultDelivery.perform(args[:draw_id])
    end
  end
end
