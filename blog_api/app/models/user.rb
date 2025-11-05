require 'signet/oauth_2/client'
require 'google/apis/sheets_v4'
require 'google/apis/drive_v3'
require 'google/apis/calendar_v3'
require 'signet/oauth_2/client'

class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  enum :role, { user: 0, admin: 1 }

  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy

  def google_calendar_service
    unless google_access_token
      return nil
    end

    if token_expired?
      if google_refresh_token.present?
        if refresh_google_token
          Rails.logger.info "✅ Token refreshed successfully"
        else
          Rails.logger.error "❌ Token refresh failed"
          return nil
        end
      else
        update(google_access_token: nil, google_token_expires_at: nil)
        return nil
      end
    end

    begin
      service = Google::Apis::CalendarV3::CalendarService.new
      service.client_options.application_name = 'My App'
      service.authorization = google_access_token
      
      service.list_calendar_lists(max_results: 1)
      
      service
      
    rescue Google::Apis::AuthorizationError => e
      update(google_access_token: nil, google_refresh_token: nil, google_token_expires_at: nil)
      nil
    rescue => e
      nil
    end
  end

  def google_sheets_service
    return nil unless google_access_token

    refresh_google_token if token_expired? && google_refresh_token.present?

    client = Signet::OAuth2::Client.new(
      access_token: google_access_token,
      refresh_token: google_refresh_token,
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      token_credential_uri: "https://oauth2.googleapis.com/token"
    )

    client.refresh! if token_expired? && google_refresh_token.present?

    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = "My App"
    service.authorization = client

    service
  rescue Google::Apis::AuthorizationError
    update(google_access_token: nil, google_refresh_token: nil, google_token_expires_at: nil)
    nil
  end

  def google_drive_service
    unless google_access_token
      return nil
    end

    if token_expired?
      if google_refresh_token.present?
        if refresh_google_token
          Rails.logger.info "✅ Token refreshed successfully"
        else
          Rails.logger.error "❌ Token refresh failed"
          return nil
        end
      else
        update(google_access_token: nil, google_token_expires_at: nil)
        return nil
      end
    end

    begin
      service = Google::Apis::DriveV3::DriveService.new
      service.client_options.application_name = 'My App'
      
      service.authorization = Signet::OAuth2::Client.new(
        access_token: google_access_token,
        refresh_token: google_refresh_token,
        client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
        token_credential_uri: "https://oauth2.googleapis.com/token"
      )
      
      service
      
    rescue Google::Apis::AuthorizationError => e
      update(google_access_token: nil, google_refresh_token: nil, google_token_expires_at: nil)
      nil
    rescue => e
      nil
    end
  end

  def refresh_google_token
    
    return false unless google_refresh_token
    
    begin
      uri = URI("https://oauth2.googleapis.com/token")
      
      response = Net::HTTP.post_form(uri, {
        client_id: ENV.fetch("GOOGLE_CLIENT_ID", nil),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", nil),
        refresh_token: google_refresh_token,
        grant_type: "refresh_token"
      })
      
      if response.is_a?(Net::HTTPSuccess)
        token_data = JSON.parse(response.body)
        
        update(
          google_access_token: token_data["access_token"],
          google_token_expires_at: Time.now.utc + token_data["expires_in"].to_i
        )
        
        return true
      else
        error_data = JSON.parse(response.body) rescue {}
        return false
      end
    rescue => e
      Rails.logger.error "Token refresh error: #{e.message}"
      return false
    end
  end

  def token_expired?
    return true unless google_token_expires_at
    google_token_expires_at < 5.minutes.from_now
  end

  def google_calendar_connected?
    google_access_token.present? && google_refresh_token.present?
  end

  def can_access_calendar?
    return false unless google_calendar_connected?
    
    service = google_calendar_service
    service.present?
  end

  def google_sheets_connected?
    google_access_token.present? && google_refresh_token.present?
  end

  def can_access_sheets?
    return false unless google_sheets_connected?
    
    service = google_sheets_service
    service.present?
  end

  def google_drive_connected?
    google_access_token.present? && google_refresh_token.present?
  end

  def can_access_drive?
    return false unless google_drive_connected?
    
    service = google_drive_service
    service.present?
  end

  def send_welcome_email()
    Rails.logger.info "Sending welcome email to #{email}"
    UserMailer.welcome_email(self).deliver_later
  end
  
end
