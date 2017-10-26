class Gws::LoginController < ApplicationController
  include Sns::BaseFilter
  include Sns::LoginFilter

  protect_from_forgery except: :remote_login
  before_action :set_organitzaion
  skip_before_action :verify_authenticity_token unless SS.config.env.protect_csrf
  skip_before_action :logged_in?, only: [:login, :remote_login, :status]

  layout "ss/login"
  navi_view nil

  private

  def set_organitzaion
    @cur_org = SS::Group.where(domains: request_host).first
    @cur_org ||= SS::Group.where(id: params[:site].to_s).first
    raise '404' unless @cur_org
  end

  def default_logged_in_path
    gws_portal_path(site: @cur_org)
  end

  def get_params
    params.require(:item).permit(:uid, :email, :password, :encryption_type)
  rescue
    raise "400"
  end

  public

  def login
    @notices = Sys::Notice.and_public.
      and_show_login.
      limit(5)

    if !request.post?
      # retrieve parameters from get parameter. this is bookmark support.
      @item = SS::User.new email: params[:email]
      return
    end

    safe_params     = get_params
    email_or_uid    = safe_params[:email].presence || safe_params[:uid]
    password        = safe_params[:password]
    encryption_type = safe_params[:encryption_type]
    if encryption_type.present?
      password = SS::Crypt.decrypt(password, type: encryption_type) rescue nil
    end

    @item = SS::User.organization_authenticate(@cur_org, email_or_uid, password) rescue false
    @item = nil if @item && !@item.enabled?
    @item = @item.try_switch_user || @item if @item

    render_login @item, email_or_uid, session: true, password: password, logout_path: gws_logout_path(site: @cur_org)
  end

  def remote_login
    raise "404" unless SS::config.sns.remote_login

    login
    render :login if response.body.blank?
  end

  def status
    if @cur_user = get_user_by_session
      render plain: 'OK'
    else
      raise '403'
    end
  end

  def logout
    put_history_log
    # discard all session info
    reset_session
    respond_to do |format|
      format.html { redirect_to gws_login_path }
      format.json { head :no_content }
    end
  end
end