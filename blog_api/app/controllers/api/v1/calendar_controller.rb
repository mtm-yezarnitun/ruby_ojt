module Api::V1
  class CalendarController < ApplicationController
    before_action :authenticate_user!
    after_action :update_cached_events, only: %i[create_event update destroy]

    def cached_events
      redis = Redis.new
      data = redis.get("user:#{current_user.id}:events")

      if data
        render json: { events: JSON.parse(data) }

      else
        service = current_user.google_calendar_service
        if service
          begin
            events = service.list_events(
              'primary',
              single_events: true,
              order_by: 'startTime',
              time_min: 1.year.ago.rfc3339
            )

            formatted = events.items.map { |e| calendar_event_to_json(e) }
            Redis.new.set("user:#{current_user.id}:events", formatted.to_json)
            Rails.logger.info "✅ Redis cached for user #{current_user.id}"
            render json: { events: formatted }
          rescue StandardError => e
            Rails.logger.error "⚠️ Failed to Redis cache: #{e.message}"
            render json: { events: [], error: 'Failed to fetch events from Google Calendar' },
                   status: :internal_server_error
          end
        else
          render json: { events: [], error: 'Google Calendar not connected' }, status: :unauthorized
        end

      end
    end

    def events
      service = current_user.google_calendar_service
      service = current_user.google_calendar_service if service.nil? && current_user.refresh_google_token

      return render json: { error: 'Google Calendar not connected' }, status: :unauthorized if service.nil?

      events = service.list_events( 
        'primary',
        single_events: true,
        order_by: 'startTime',
        time_min: 1.year.ago.rfc3339
      )

      formatted_events = events.items.map { |event| calendar_event_to_json(event) }
      Redis.new.set("user:#{current_user.id}:events", formatted_events.to_json)

      render json: { events: formatted_events }
    rescue Google::Apis::AuthorizationError => e
      Rails.logger.error "Calendar authorization error: #{e.message}"
      render json: { error: 'Calendar access expired. Please reconnect.' }, status: :unauthorized
    rescue StandardError => e
      Rails.logger.error "Calendar error: #{e.message}"
      render json: { error: 'Failed to fetch calendar events' }, status: :internal_server_error
    end

    def create_event
      unless current_user.google_access_token
        return render json: { error: 'Google Calendar not connected' }, status: :unauthorized
      end

      service = current_user.google_calendar_service
      if service.nil?
        return render json: { error: 'Failed to initialize calendar service' }, status: :internal_server_error
      end

      begin
        recurrence_rule = params[:recurrence].presence
        recurrence_rule = nil if recurrence_rule == 'null'

        attendees_emails = params[:attendees]&.split(',')&.map(&:strip)&.reject(&:blank?) || []
        attendees = attendees_emails.map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) }

        user_timezone = 'Asia/Yangon'
        start_time = Time.find_zone(user_timezone).parse(params[:start_time])
        end_time = Time.find_zone(user_timezone).parse(params[:end_time])

        if end_time <= start_time
          return render json: { error: 'End time must be after start time' }, status: :bad_request
        end

        event = Google::Apis::CalendarV3::Event.new(
          summary: params[:title],
          description: params[:description],
          location: params[:location],
          color_id: params[:colorId],
          start: Google::Apis::CalendarV3::EventDateTime.new(
            date_time: start_time.rfc3339,
            time_zone: user_timezone
          ),
          end: Google::Apis::CalendarV3::EventDateTime.new(
            date_time: end_time.rfc3339,
            time_zone: user_timezone
          ),
          attendees: attendees
        )
        event.recurrence = [recurrence_rule] if recurrence_rule

        result = service.insert_event('primary', event)

        render json: { event: calendar_event_to_json(result) }

        redis = Redis.new
        redis.del("user:#{current_user.id}:events")
      rescue ArgumentError
        render json: { error: 'Invalid date format' }, status: :bad_request
      rescue Google::Apis::ClientError => e
        render json: { error: 'Google Calendar error: ' + e.message }, status: :bad_request
      rescue StandardError => e
        Rails.logger.error "Create event failed: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Failed to create event' }, status: :internal_server_error
      end
    end

    def update
      unless current_user.google_access_token
        return render json: { error: 'Google Calendar not connected' }, status: :unauthorized
      end

      service = current_user.google_calendar_service
      if service.nil?
        return render json: { error: 'Failed to initialize calendar service' }, status: :internal_server_error
      end

      begin
        user_timezone = 'Asia/Yangon'

        start_time = (Time.find_zone(user_timezone).parse(params[:start_time]) if params[:start_time].present?)

        end_time = (Time.find_zone(user_timezone).parse(params[:end_time]) if params[:end_time].present?)

        if start_time && end_time && end_time <= start_time
          return render json: { error: 'End time must be after start time' }, status: :bad_request
        end

        existing_event = service.get_event('primary', params[:id])

        existing_event.summary = params[:title] if params[:title].present?
        existing_event.description = params[:description] if params.key?(:description)
        existing_event.location = params[:location] if params.key?(:location)
        existing_event.color_id = params[:colorId] if params.key?(:colorId)

        if params.key?(:attendees)
          attendees_emails = params[:attendees]&.split(',')&.map(&:strip)&.reject(&:blank?) || []
          existing_event.attendees = attendees_emails.map { |email| Google::Apis::CalendarV3::EventAttendee.new(email: email) }
        end

        if start_time
          existing_event.start = Google::Apis::CalendarV3::EventDateTime.new(
            date_time: start_time.rfc3339,
            time_zone: user_timezone
          )
        end

        if end_time
          existing_event.end = Google::Apis::CalendarV3::EventDateTime.new(
            date_time: end_time.rfc3339,
            time_zone: user_timezone
          )
        end

        result = service.update_event('primary', params[:id], existing_event)

        redis = Redis.new
        redis.del("user:#{current_user.id}:events")

        render json: { event: calendar_event_to_json(result) }
      rescue ArgumentError
        render json: { error: 'Invalid date format' }, status: :bad_request
      rescue Google::Apis::ClientError => e
        if e.status_code == 404
          render json: { error: 'Event not found' }, status: :not_found
        else
          render json: { error: 'Google Calendar error: ' + e.message }, status: :bad_request
        end
      rescue StandardError => e
        Rails.logger.error "Calendar update error: #{e.message}"
        render json: { error: 'Failed to update event' }, status: :internal_server_error
      end
    end

    def destroy
      unless current_user.google_access_token
        return render json: { error: 'Google Calendar not connected' }, status: :unauthorized
      end

      service = current_user.google_calendar_service
      if service.nil?
        return render json: { error: 'Failed to initialize calendar service' }, status: :internal_server_error
      end

      begin
        service.delete_event('primary', params[:id])

        redis = Redis.new
        redis.del("user:#{current_user.id}:events")

        render json: { message: 'Event deleted successfully' }
      rescue Google::Apis::ClientError
        render json: { error: 'Event not found' }, status: :not_found
      rescue StandardError
        render json: { error: 'Failed to delete event' }, status: :internal_server_error
      end
    end

    def download_template
      headers = ["Title", "Description", "Start Time", "End Time", "Location", "Attendees"]
      csv_data = CSV.generate(headers: true) do |csv|
        csv << headers
        csv << ["Sample Event", "This is a description", "2025-10-14T10:00:00", "2025-10-14T12:00:00", "Office", "attendee1@example.com,attendee2@example.com"]
      end
      send_data csv_data, filename: "events_template.csv", type: 'text/csv'
    end
    
    def import_csv 
      if params[:file].nil?
        render json: { error: "No file provided" }, status: :unprocessable_entity
        return
      end 

      FileUtils.mkdir_p(Rails.root.join("tmp", "imports"))
        
      filename = "events_#{Time.now.to_i}_#{params[:file].original_filename}"
      file_path = Rails.root.join("tmp", "imports",filename)

      File.open(file_path, "wb") do |file|
        file.write(params[:file].read)
      end
      job_key = "import_result:#{current_user.id}:#{Time.now.to_i}"
      ImportEventsJob.perform_async(current_user.id, file_path.to_s, job_key)

      render json: { status: "queued", job_key: job_key }
    end

    def import_status
      redis = Redis.new
      result = redis.get(params[:job_key])

      if result
        redis.del(params[:job_key])
        render json: JSON.parse(result)
      else
        render json: { status: "pending", message: "Import in progress..." }
      end
    end
    
    def export_pdf
      require 'Prawn'
      require 'Time'
      cached_events = Redis.new.get("user:#{current_user.id}:events")
      events = cached_events.present? ? JSON.parse(cached_events) : []

      now = Time.now 
      filter = params[:filter] || 'all'

      filter_events = events.select do |event|
        start_time=Time.parse(event['start_time']) rescue nil
        end_time=Time.parse(event['end_time']) rescue nil

        next false unless start_time && end_time

        case filter 
          when 'past'
            end_time < now
          when 'ongoing'
            start_time <= now && end_time >= now
          when 'upcoming'
            start_time > now
          else 
            true
        end

      end

      if filter_events.empty?
        pdf = Prawn::Document.new
          pdf.text "#{filter.capitalize}_Events", size: 24, style: :bold
          pdf.move_down 20
          pdf.text "No #{filter.capitalize} Events Found", size: 16, style: :italic

          pdf_data = pdf.render

          ExportPdfEmailWorker.perform_async(current_user.id, Base64.encode64(pdf_data),filter)
      else
        pdf = Prawn::Document.new
          pdf.text "#{filter.capitalize}_Events", size: 24, style: :bold
          pdf.move_down 20
            filter_events.each do |event|
              pdf.text "Title: #{event['title']}", style: :bold
              pdf.text "Description: #{event['description']}" if event['description'].present?
              pdf.text "Location: #{event['location']}" if event['location'].present?

              if event['attendees'].present? && event['attendees'].any?
                pdf.text "Attendees: #{event['attendees'].join(', ')}"
              else
                pdf.text 'Attendees: None'
              end

              start_time = Time.parse(event['start_time']).strftime('%b %d, %Y %I:%M %p')
              pdf.text "Start: #{start_time}"

              end_time = Time.parse(event['end_time']).strftime('%b %d, %Y %I:%M %p')
              pdf.text "End: #{end_time}"

              pdf.move_down 34
            end

        pdf_data = pdf.render
        ExportPdfEmailWorker.perform_async(current_user.id, Base64.encode64(pdf_data),filter)
      
      end

      send_data pdf_data,
                filename: "#{filter}_events.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def export_csv
      require 'csv'

      cached_events = Redis.new.get("user:#{current_user.id}:events")
      events = cached_events.present? ? JSON.parse(cached_events) : []

      now = Time.now 
      filter = params[:filter] || 'all'

      filter_events = events.select do |event|
        start_time=Time.parse(event['start_time']) rescue nil
        end_time=Time.parse(event['end_time']) rescue nil

        next false unless start_time && end_time

        case filter 
          when 'past'
            end_time < now
          when 'ongoing'
            start_time <= now && end_time >= now
          when 'upcoming'
            start_time > now
          else 
            true
        end

      end
    
      if filter_events.empty?
        csv_data = CSV.generate(headers: true) do |csv|
        csv << ["No #{filter.capitalize} Events Found"]
        
        UserMailer.send_calendar_csv(current_user, csv_data,filter).deliver_later
      end

      else
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ['Title', 'Description', 'Start Time', 'End Time', 'Location', 'Attendees']

          filter_events.each do |event|
            csv << [
              event['title'],
              event['description'],
              event['start_time'] ? Time.parse(event['start_time']).strftime('%b %d, %Y %I:%M %p') : '',
              event['end_time'] ? Time.parse(event['end_time']).strftime('%b %d, %Y %I:%M %p') : '',
              event['location'],
              event['attendees']&.join(', ')
            ]
          end
        end

        UserMailer.send_calendar_csv(current_user, csv_data,filter).deliver_later

      end 

      send_data csv_data,
                filename: '#{filter}_events.csv',
                type: 'text/csv',
                disposition: 'attachment'
    end
    
    private

      def calendar_event_to_json(event)
        processed_attendees = event.attendees&.map do |attendee|
          if attendee.respond_to?(:email)
            attendee.email
          elsif attendee.is_a?(String)
            attendee
          else
            attendee.to_s
          end
        end || []

        Rails.logger.info "Processed attendees: #{processed_attendees.inspect}"
        {
          id: event.id,
          title: event.summary,
          description: event.description,
          location: event.location,
          attendees: event.attendees&.map { |a| a.email } || [],
          colorId: event.color_id,
          recurrence: event.recurrence,
          start_time: event.start&.date_time,
          end_time: event.end&.date_time,
          html_link: event.html_link
        }
      end

      def update_cached_events
        service = current_user.google_calendar_service
        return unless service

        begin
          events = service.list_events(
            'primary',
            single_events: true,
            order_by: 'startTime',
            time_min: 1.year.ago.rfc3339
          )

          formatted = events.items.map { |e| calendar_event_to_json(e) }

          Redis.new.set("user:#{current_user.id}:events", formatted.to_json)
          Rails.logger.info "✅ Redis cache refreshed for user #{current_user.id}"
        rescue StandardError => e
          Rails.logger.error "⚠️ Failed to refresh Redis cache: #{e.message}"
        end
      end
  end
end
