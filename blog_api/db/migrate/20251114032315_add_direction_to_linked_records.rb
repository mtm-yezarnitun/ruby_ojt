class AddDirectionToLinkedRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :linked_records, :direction, :string, null: false, default: 'source_to_target'
  end
end
