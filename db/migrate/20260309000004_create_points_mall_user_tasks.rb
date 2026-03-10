# frozen_string_literal: true

class CreatePointsMallUserTasks < ActiveRecord::Migration[7.0]
  def change
    create_table :points_mall_user_tasks do |t|
      t.integer :user_id, null: false
      t.integer :task_id, null: false
      t.integer :progress, default: 0
      t.boolean :completed, default: false
      t.datetime :completed_at
      t.date :task_date
      t.timestamps
    end

    add_index :points_mall_user_tasks, [:user_id, :task_id, :task_date], name: 'index_user_tasks_on_user_task_date'
    add_index :points_mall_user_tasks, :user_id
    add_index :points_mall_user_tasks, :completed
  end
end
