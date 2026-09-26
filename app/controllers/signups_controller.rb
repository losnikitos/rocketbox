# frozen_string_literal: true

class SignupsController < ApplicationController
  layout "signup"
  skip_before_action :authenticate

  # ponytail: stub SMS OTP; wire WhatsApp/SMS when ready
  PHONE_STUB_CODE = "000000"

  before_action :require_draft_through_business!, only: %i[email email_submit email_code email_code_submit]
  before_action :require_draft_email!, only: %i[email_code email_code_submit]
  before_action :require_signed_in_for_phone!, only: %i[phone phone_submit phone_skip phone_code phone_code_submit]

  def show
    redirect_to next_step_path
  end

  def name
    @name = draft[:name]
  end

  def name_submit
    value = params[:name].to_s.strip
    if value.blank?
      @name = value
      flash.now[:alert] = "Enter your name"
      return render :name, status: :unprocessable_entity
    end

    update_draft(name: value)
    redirect_to sign_up_business_path
  end

  def business
    @business_name = draft[:business_name]
  end

  def business_submit
    value = params[:business_name].to_s.strip
    if value.blank?
      @business_name = value
      flash.now[:alert] = "Enter your business name"
      return render :business, status: :unprocessable_entity
    end

    update_draft(business_name: value)
    redirect_to sign_up_email_path
  end

  def email
    @email = draft[:email].presence || params[:email_hint]
  end

  def email_submit
    email = LoginChallenge.normalize(params[:email])
    if email.blank? || email !~ URI::MailTo::EMAIL_REGEXP
      @email = params[:email]
      flash.now[:alert] = "Enter a valid email"
      return render :email, status: :unprocessable_entity
    end

    if User.exists?(email: email)
      redirect_to sign_in_path(email_hint: email), notice: "You already have an account. Sign in instead."
      return
    end

    update_draft(email: email)
    issue_email_otp!(email)
    redirect_to sign_up_email_code_path
  end

  def email_code
    @email = draft[:email]
    @otp_code = session[:signup_otp_code] if Rails.env.development?
  end

  def email_code_submit
    if Current.user
      redirect_to sign_up_phone_path
      return
    end

    email = draft[:email]
    unless LoginChallenge.verify_code!(email, params[:otp])
      @email = email
      @otp_code = session[:signup_otp_code] if Rails.env.development?
      flash.now[:alert] = "That code is invalid or expired"
      return render :email_code, status: :unprocessable_entity
    end

    user = User.create!(
      email: email,
      name: draft[:name],
      business_name: draft[:business_name],
      verified: true
    )
    start_session!(user)
    redirect_to sign_up_phone_path
  end

  def phone
  end

  def phone_submit
    phone = params[:phone].to_s.strip
    if phone.blank?
      flash.now[:alert] = "Enter your phone number"
      return render :phone, status: :unprocessable_entity
    end

    Current.user.update!(whatsapp_phone: phone)
    redirect_to sign_up_phone_code_path
  end

  def phone_skip
    clear_draft!
    redirect_to app_path, notice: "Welcome! You have signed up successfully"
  end

  def phone_code
    @phone_code = PHONE_STUB_CODE
  end

  def phone_code_submit
    if params[:otp].to_s.strip != PHONE_STUB_CODE
      @phone_code = PHONE_STUB_CODE
      flash.now[:alert] = "That code is invalid"
      return render :phone_code, status: :unprocessable_entity
    end

    clear_draft!
    redirect_to app_path, notice: "Welcome! You have signed up successfully"
  end

  private

    def draft
      session[:signup] ||= {}
      session[:signup].with_indifferent_access
    end

    def update_draft(**attrs)
      session[:signup] = draft.merge(attrs.stringify_keys)
    end

    def clear_draft!
      session.delete(:signup)
      session.delete(:signup_otp_code)
    end

    def next_step_path
      return sign_up_phone_path if Current.user
      return sign_up_email_code_path if draft[:email].present?
      return sign_up_email_path if draft[:business_name].present?
      return sign_up_business_path if draft[:name].present?

      sign_up_name_path
    end

    def require_draft_through_business!
      return if draft[:name].present? && draft[:business_name].present?

      redirect_to next_step_path
    end

    def require_draft_email!
      return if draft[:email].present?

      redirect_to sign_up_email_path
    end

    def require_signed_in_for_phone!
      return if Current.user

      redirect_to sign_up_path
    end

    def issue_email_otp!(email)
      challenge = LoginChallenge.issue!(email)
      if challenge == :throttled
        return
      end

      session[:signup_otp_code] = challenge[:code] if Rails.env.development?

      UserMailer.with(
        email: challenge[:email],
        otp_code: challenge[:code],
        magic_token: challenge[:token]
      ).login_otp.deliver_later
    end

    def start_session!(user)
      session_record = user.sessions.create!
      cookies.signed.permanent[:session_token] = { value: session_record.id, httponly: true }
      Current.session = session_record
    end
end
