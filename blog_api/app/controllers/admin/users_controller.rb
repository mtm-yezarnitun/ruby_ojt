class Admin::UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    def authorize_admin!
        unless current_user.role == 'admin'
            render json: { error: "Access Denied !"} , status: :forbidden
        end
    end

    def index
        @users = User.where.not(id: current_user.id)
        render json: @users
    end

    def show
        @user = User.find(params[:id])
        render json: @user
    end

    def create
    @user = User.new(user_params)
        if @user.save
            render json: { message: "User created", user: @user }, status: :created
        else
            render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
    end

    def update
    @user = User.find(params[:id])
        if @user.update(user_params)
            render json: @user
        else
            render json: @user.errors, status: :unprocessable_entity
        end
    end

    def destroy
        @user = User.find(params[:id])
        @user.destroy
        render json: { message: 'User deleted successfully.' },status: :ok
    end

    private

    def user_params
        params.require(:user).permit(:email, :password, :role)
    end
    
end