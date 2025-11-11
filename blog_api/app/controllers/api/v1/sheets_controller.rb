require 'httparty'
module Api::V1
  class SheetsController < ApplicationController
    before_action :authenticate_user!
    
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
            email: file.owners&.first&.email_address,
            modified_at: file.modified_time,
            link: file.web_view_link
          }
        end

        render json: { success: 'Fetched Successfully!', spreadsheets: spreadsheets }, status: :ok
      rescue Google::Apis::AuthorizationError => e
        Rails.logger.error "Drive auth error: #{e.message}"
        render json: { error: 'Google authorization expired. Please reconnect.' }, status: :unauthorized
      rescue StandardError => e
        Rails.logger.error "Drive fetch error: #{e.message}"
        render json: { error: 'Failed to fetch spreadsheets.' }, status: :internal_server_error
      end
    end
    
    def create_spreadsheet
      sheet_service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if sheet_service.nil?

      title = params[:title].presence || "Untitled Spreadsheet"

      begin
        spreadsheet = Google::Apis::SheetsV4::Spreadsheet.new(
          properties: { title: title }
        )

        created_spreadsheet = sheet_service.create_spreadsheet(spreadsheet)
        render json: { success: 'Spreadsheet created!', spreadsheet: created_spreadsheet }, status: :created
      rescue Google::Apis::ClientError => e
        render json: { error: e.message }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheets create error: #{e.message}"
        render json: { error: 'Failed to create spreadsheet.' }, status: :internal_server_error
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
          sheets: sheets,
          link: spreadsheet.spreadsheet_url 
        }, status: :ok

      rescue Google::Apis::ClientError => e
        render json: { error: 'Invalid spreadsheet ID or access denied.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheets error: #{e.message}"
        render json: { error: 'Failed to load sheet data.' }, status: :internal_server_error
      end
    end

    def add_new_sheet
      spreadsheet_id = params[:id]  
      sheet_title = params.dig(:sheet, :title) || params[:title]

      if sheet_title.blank?
        return render json: { success: false, error: "Sheet title cannot be blank" }, status: :bad_request
      end

      service = current_user.google_sheets_service
      
      request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
        requests: [
          { add_sheet: { properties: { title: sheet_title } } }
        ]
      )

      service.batch_update_spreadsheet(spreadsheet_id, request)

      render json: { success: true, sheet_title: sheet_title }
      rescue Google::Apis::ClientError => e
        render json: { success: false, error: e.message }, status: :bad_request
      rescue => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end

    def duplicate_sheet
      spreadsheet_id = params[:id]
      sheet_id = params[:sheet_id]
      new_title = params[:new_title]

      service = current_user.google_sheets_service 
      spreadsheet = service.get_spreadsheet(spreadsheet_id)
      sheet = spreadsheet.sheets.find { |s| s.properties.sheet_id == sheet_id.to_i }
      if(!sheet)
        return render json: { success: false, error: "Sheet cannot be found" }, status: :bad_request
      end
      
      requests = [
        {
          duplicate_sheet: {
            source_sheet_id: sheet_id.to_i,
            new_sheet_name: new_title
          }
        }
      ]

      result =  service.batch_update_spreadsheet(spreadsheet_id, { requests: requests })
      render json: result
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
    end

    def copy_sheet_to_spreadsheet
      access_token = current_user.google_access_token
      source_spreadsheet_id = params[:source_spreadsheet_id]
      sheet_id = params[:sheet_id]
      destination_spreadsheet_id = params[:destination_spreadsheet_id]

      url = "https://sheets.googleapis.com/v4/spreadsheets/#{source_spreadsheet_id}/sheets/#{sheet_id}:copyTo"
      body = { destinationSpreadsheetId: destination_spreadsheet_id }.to_json

      response = HTTParty.post(url,
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        body: body
      )

      render json: { success: true, copied_sheet: response.parsed_response }, status: :ok
    rescue => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end

    def preview
      drive_service = current_user.google_drive_service
      return render json: { error: 'Google Drive not connected' }, status: :unauthorized if drive_service.nil?

      sheet_service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if sheet_service.nil?

      spreadsheet_id = params[:id]
      sheet_name = params[:sheet_name] 

      begin

        file = drive_service.get_file(spreadsheet_id, fields: 'owners')
        email = file.owners&.first&.email_address

        spreadsheet_ttl= sheet_service.get_spreadsheet(spreadsheet_id, fields: 'properties(title)')
        spreadsheet_title = spreadsheet_ttl.properties.title

        spreadsheet = sheet_service.get_spreadsheet(
          spreadsheet_id,
          ranges: ["#{sheet_name}!A1:Z55"],
          fields: 'sheets.properties,sheets.data.rowData.values.formattedValue,sheets.data.rowData.values.effectiveFormat.backgroundColor,sheets.data.rowData.values.effectiveFormat.textFormat,sheets.merges'
        )
        
        sheet_obj = spreadsheet.sheets.find { |s| s.properties && s.properties.title == sheet_name }

        render json: { 
          success: 'Fetched Successfully!', 
          owner: email, 
          spreadsheet_id: spreadsheet_id, 
          spreadsheet_title: spreadsheet_ttl, 
          spreadsheet: spreadsheet, 
          sheet_name: sheet_name,
          sheet_id: sheet_obj.properties&.sheet_id
          }, status: :ok
      rescue Google::Apis::ClientError => e
        render json: { error: 'Invalid spreadsheet or sheet access denied.' }, status: :bad_request

      rescue StandardError => e
        Rails.logger.error "Sheets preview error: #{e.message}"
        render json: { error: 'Failed to load sheet preview.' }, status: :internal_server_error
      end
    end

    def update
      sheet_service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if sheet_service.nil?

      spreadsheet_id = params[:id]
      sheet_name = params[:sheet_name]
      updates = params[:updates] 

      begin
        body = Google::Apis::SheetsV4::BatchUpdateValuesRequest.new(
          data: updates,
          value_input_option: 'USER_ENTERED'
        )

        response = sheet_service.batch_update_values(spreadsheet_id, body)
        render json: { success: 'Sheet updated successfully', response: response }, status: :ok
      rescue Google::Apis::ClientError => e
        render json: { error: 'Invalid sheet or range.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheets update error: #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Failed to update sheet.' }, status: :internal_server_error
      end
    end

    def rename_sheet
      service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if service.nil?

      spreadsheet_id = params[:id]
      sheet_id = params[:sheet_id]
      new_title = params[:new_title]

      if new_title.blank?
        return render json: { success: false, error: 'New sheet title cannot be blank' }, status: :bad_request
      end

      begin
        request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
          requests: [
            {
              update_sheet_properties: {
                properties: {
                  sheet_id: sheet_id.to_i,
                  title: new_title
                },
                fields: 'title'
              }
            }
          ]
        )
        service.batch_update_spreadsheet(spreadsheet_id, request)
        render json: { success: true, new_title: new_title }, status: :ok
      rescue Google::Apis::ClientError => e
        Rails.logger.error "Sheets rename error: #{e.message}"
        render json: { error: 'Sheet not found or unauthorized.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheet rename error: #{e.message}"
        render json: { error: 'Failed to rename sheet.' }, status: :internal_server_error
      end
    end

    def destroy
      drive_service = current_user.google_drive_service
      return render json: { error: 'Google Drive not connected' }, status: :unauthorized if drive_service.nil?

      spreadsheet_id = params[:id]

      begin
        drive_service.delete_file(spreadsheet_id)
        render json: { success: 'Spreadsheet deleted successfully.' }, status: :ok
      rescue Google::Apis::ClientError => e
        Rails.logger.error "Drive API error: #{e.message}"
        render json: { error: 'Spreadsheet not found or unauthorized.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheets delete error: #{e.message}"
        render json: { error: 'Failed to delete spreadsheet.' }, status: :internal_server_error
      end
    end
    
    def delete_sheet
      service = current_user.google_sheets_service
      return render json: { error: 'Google Sheets not connected' }, status: :unauthorized if service.nil?

      spreadsheet_id = params[:id]
      sheet_id = params[:sheet_id]

      begin
        request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new(
          requests: [
            { delete_sheet: { sheet_id: sheet_id.to_i } }
          ]
        )
        service.batch_update_spreadsheet(spreadsheet_id,request)
        render json: { success: 'Sheet Deleted Successfully.' }, status: :ok
      rescue Google::Apis::ClientError => e
        Rails.logger.error "Sheets API error: #{e.message}"
        render json: { error: 'Sheet not found or unauthorized.' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Sheet delete error: #{e.message}"
        render json: { error: 'Failed to delete sheet.' }, status: :internal_server_error
      end
    end
  end
end
