Rails.application.routes.draw do
  require 'sidekiq/web'
  require 'sidekiq/cron/web'

  devise_for :users,
             defaults: { format: :json },
             controllers: {
               sessions: 'users/sessions',
               registrations: 'users/registrations'
             },
             path: '',
             path_names: {
               sign_in: 'login',
               sign_out: 'logout',
               registration: 'signup'
             }
  namespace :api do
    namespace :v1 do
      post 'google_login', to: 'google_auth#login'

      get 'google_login', to: 'google_auth#redirect'
      get 'google_callback', to: 'google_auth#callback'

      get '/calendar/events', to: 'calendar#events'
      get 'calendar/cached_events', to: 'calendar#cached_events'
      post '/calendar/events', to: 'calendar#create_event'
      patch '/calendar/events/:id', to: 'calendar#update'
      delete '/calendar/events/:id', to: 'calendar#destroy'

      get '/calendar/export_pdf', to: 'calendar#export_pdf'
      get '/calendar/export_csv', to: 'calendar#export_csv'
      post '/calendar/import_csv', to: 'calendar#import_csv'
      get '/calendar/import_status', to: 'calendar#import_status'
      get '/calendar/download_template', to: 'calendar#download_template'
      
      resources :sheets, only: [:index, :show, :destroy] do
        collection do
          post :create_spreadsheet
          
          post ':spreadsheet_id/link_columns', to: 'sheets#link_columns'
          get '/linked_records', to: 'sheets#linked_records'
          delete 'unlink_columns/:id', to: 'sheets#unlink_columns'
        end
        member do
          get 'sheet/:sheet_name/preview', to: 'sheets#preview'
          get 'sheet/export', to: 'sheets#export'
          get 'sheet/export_whole_spreadsheet', to: 'sheets#export_whole_spreadsheet'
          put 'sheet/:sheet_name/update', to: 'sheets#update'
          put 'rename_sheet', to:'sheets#rename_sheet'
          post 'add_sheet', to: 'sheets#add_new_sheet' 
          post 'import_csv', to: 'sheets#import_csv'
          post 'duplicate_sheet', to: 'sheets#duplicate_sheet'
          post 'sheets/copy_sheet_to_spreadsheet', to: 'sheets#copy_sheet_to_spreadsheet'
          put 'sheet/:sheet_id/append_rows', to: 'sheets#append_rows'
          delete 'delete_sheet', to: 'sheets#delete_sheet' 
        end
      end
      
      resources :posts do
        resources :comments, only: %i[index create destroy]
      end
      resource :profile, only: %i[show update]

      resources :announcements do
        collection do
          get :active
        end
      end
    end
  end

  namespace :admin do
    resources :users
  end

  if Rails.env.development?
    mount Sidekiq::Web => '/sidekiq'
    mount LetterOpenerWeb::Engine, at: '/mailbox'
    mount ActionCable.server => '/cable'
  end
end
