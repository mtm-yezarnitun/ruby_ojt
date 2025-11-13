class CreateLinkedRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :linked_records do |t|
      t.string :source_spreadsheet_id, null: false
      t.string :source_sheet_name, null: false
      t.string :source_column, null: false
      t.string :target_spreadsheet_id, null: false
      t.string :target_sheet_name, null: false
      t.string :target_column, null: false
      t.timestamps
    end
  end
end
