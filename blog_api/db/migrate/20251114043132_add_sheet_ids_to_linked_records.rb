class AddSheetIdsToLinkedRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :linked_records, :source_sheet_id, :string, null: false , default: 'xxxxxx'
    add_column :linked_records, :target_sheet_id, :string, null: false, default: 'xxxxxx'
  end
end
