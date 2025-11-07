class Api::V1::GoogleAuthController < ApplicationController
  require 'net/http'
  require 'uri'
  require 'json'

  GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token".freeze

  def login
    Rails.logger.info "Params received: #{params.inspect}"

    access_token = params[:access_token]
    return render json: { error: 'Missing access_token' }, status: :bad_request unless access_token

    payload =fetch_userinfo(access_token)
    Rails.logger.info "Google payload: #{payload.inspect}"
    return render json: { error: 'Invalid ID token' }, status: :unauthorized unless payload
    

    user = User.where(provider: 'google_oauth2', uid: payload['sub']).first_or_initialize
    user.email = payload['email']
    user.password ||= Devise.friendly_token[0, 20]
    user.provider = 'google_oauth2'
    user.uid = payload['sub']
    user.google_access_token = access_token

    user.save!

    if user.created_at == user.updated_at
      user.send_welcome_email
    end

    token, _ = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

    render json: {
      message: 'Logged in successfully.',
      user: { id: user.id, email: user.email },
      token: token
    }
    rescue => e
      Rails.logger.error "Google login error: #{e.message}"
      render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  def redirect
    client_id = ENV.fetch("GOOGLE_CLIENT_ID", nil)
    redirect_uri = "http://localhost:3000/api/v1/google_callback"
    scopes = [
      "openid",
      "email",
      "profile",
      "https://www.googleapis.com/auth/calendar",
      "https://www.googleapis.com/auth/calendar.events",
      "https://www.googleapis.com/auth/spreadsheets",
      "https://www.googleapis.com/auth/drive.metadata.readonly",
      "https://www.googleapis.com/auth/drive"
    ]

    scope = scopes.join(" ")

    url = "#{GOOGLE_AUTH_URL}?" + {
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: scope,
      access_type: "offline",
      prompt: "consent"
    }.to_query

    redirect_to url, allow_other_host: true
  end

  def callback
    code = params[:code]
    return render json: { error: "Missing code" }, status: :bad_request unless code

    token_data = exchange_code_for_token(code)
    id_token = token_data["id_token"]

    access_token = token_data["access_token"]
    refresh_token = token_data["refresh_token"] 
    expires_at = Time.now.utc + token_data["expires_in"].to_i

    payload = verify_google_id_token(id_token)
    return render json: { error: "Invalid ID token" }, status: :unauthorized unless payload

    user = User.find_by(provider: "google_oauth2", uid: payload["sub"])

    user ||= User.find_by(email: payload["email"])

    if user
      user.update!(
        provider: "google_oauth2",
        uid: payload["sub"],
        google_access_token: access_token,
        google_refresh_token: refresh_token,
        google_token_expires_at: expires_at
    )
    else
      user = User.create!(
        email: payload["email"],
        password: Devise.friendly_token[0, 20],
        provider: "google_oauth2",
        uid: payload["sub"],
        role: "user",
        google_access_token: access_token,
        google_refresh_token: refresh_token,
        google_token_expires_at: expires_at
      )
      user.send_welcome_email
    end

    jwt, _ = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)

    redirect_to "http://localhost:5173/auth/success?token=#{jwt}" ,allow_other_host: true

  rescue => e
    Rails.logger.error "Google OAuth redirect error: #{e.message}"
    redirect_to "http://localhost:5173/login"
  end

  def fetch_userinfo(access_token)
    url = URI("https://www.googleapis.com/oauth2/v3/userinfo")
    req = Net::HTTP::Get.new(url)
    req["Authorization"] = "Bearer #{access_token}"

    res = Net::HTTP.start(url.hostname, url.port, use_ssl: true) { |http| http.request(req) }
    JSON.parse(res.body)
  end

  private
    def verify_google_id_token(id_token)
      uri = URI.parse("https://oauth2.googleapis.com/tokeninfo?id_token=#{id_token}")
      response = Net::HTTP.get_response(uri)
      return nil unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
      rescue => e
        Rails.logger.error "Google ID token verification failed: #{e.message}"
        nil
    end
    def exchange_code_for_token(code)
      uri = URI("https://oauth2.googleapis.com/token")
      res = Net::HTTP.post_form(uri, {
        code: code,
        client_id: ENV.fetch("GOOGLE_CLIENT_ID", nil),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", nil),
        redirect_uri: "http://localhost:3000/api/v1/google_callback",
        grant_type: "authorization_code"
      })
      JSON.parse(res.body)
    end
end
