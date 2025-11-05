module Api::V1
  class SheetsController < ApplicationController

    def index
      drive_service = current_user.google_drive_service
      return render json: { error: 'Google Drive not connected' }, status: :unauthorized if drive_service.nil?


      begin
        results = drive_service.list_files(
          q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed = false",
          fields: 'files(id, name, modifiedTime, owners, webViewLink)'
        )

        spreadsheets = results.files.map do |file|
          {
            id: file.id,
            name: file.name,
            owner: file.owners&.first&.display_name,
            modified_at: file.modified_time,
            link: file.web_view_link
          }
        end

        render json: { success: 'Fetched Successfully!', spreadsheets: spreadsheets }
      rescue Google::Apis::AuthorizationError => e
        Rails.logger.error "Drive auth error: #{e.message}"
        render json: { error: 'Google authorization expired. Please reconnect.' }, status: :unauthorized
      rescue StandardError => e
        Rails.logger.error "Drive fetch error: #{e.message}"
        render json: { error: 'Failed to fetch spreadsheets.' }, status: :internal_server_error
      end
    end

    def show
      sheet_service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if sheet_service.nil?

      spreadsheet_id = params[:id]

      begin
        spreadsheet = sheet_service.get_spreadsheet(spreadsheet_id)
        sheets = spreadsheet.sheets.map do |s|
          {
            title: s.properties.title,
            sheet_id: s.properties.sheet_id
          }
        end

        render json: {
          success: 'Fetched Successfully!',
          id: spreadsheet_id,
          spreadsheet_title: spreadsheet.properties.title,
          sheets: sheets
        }

      rescue Google::Apis::ClientError => e
        render json: { error: 'Invalid spreadsheet ID or access denied.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheets error: #{e.message}"
        render json: { error: 'Failed to load sheet data.' }, status: :internal_server_error
      end
    end

    def preview
      sheet_service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if sheet_service.nil?

      spreadsheet_id = params[:id]
      sheet_name = params[:sheet_name] 

      begin
        result = sheet_service.get_spreadsheet_values(spreadsheet_id, "#{sheet_name}")
        values = result.values || []

        render json: { success: 'Fetched Successfully!' , sheet_name: sheet_name, values: values }
      rescue Google::Apis::ClientError => e
        render json: { error: 'Invalid spreadsheet or sheet access denied.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheets preview error: #{e.message}"
        render json: { error: 'Failed to load sheet preview.' }, status: :internal_server_error
      end
    end

  end
end
