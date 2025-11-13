class LinkedRecord < ApplicationRecord
  validates :source_spreadsheet_id, :source_sheet_name, :source_column,
            :target_spreadsheet_id, :target_sheet_name, :target_column,
            presence: true

  validates :source_spreadsheet_id, uniqueness: {
    scope: [:source_sheet_name, :target_sheet_name, :source_column, :target_column],
    message: "link between these sheets and columns already exists"
  }
end