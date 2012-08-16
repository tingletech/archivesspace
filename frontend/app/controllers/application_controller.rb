class ApplicationController < ActionController::Base
  protect_from_forgery

  helper :all

  rescue_from ArchivesSpace::SessionGone, :with => :destroy_user_session


  # Note: This should be first!
  before_filter :store_user_session

  before_filter :load_repository_list
  before_filter :load_default_vocabulary
  before_filter :load_theme

  protected

  def inline?
     params[:inline] === "true"
  end

  private

  def destroy_user_session
    Thread.current[:backend_session] = nil
    Thread.current[:repo_id] = nil

    reset_session

    flash[:error] = "Your backend session was not found"
    redirect_to :controller=>:welcome, :action=>:index
  end


  def store_user_session
    Thread.current[:backend_session] = session[:session]
    Thread.current[:selected_repo_id] = session[:repo_id]
  end


  def load_repository_list
    @repositories = JSONModel(:repository).all

    if not session.has_key?(:repo) and not @repositories.empty?
      session[:repo] = @repositories.first.repo_code.to_s
      session[:repo_id] = @repositories.first.id
    end

  end

  def load_theme
    session[:theme] = params[:theme] if params.has_key?(:theme)
    if not session.has_key?(:theme)
      session[:theme] = "default"
    end
  end

  def load_default_vocabulary
     if not session.has_key?(:vocabulary)
        session[:vocabulary] = JSONModel(:vocabulary).all.first.to_hash
     end
  end

  def choose_layout
     if inline?
        nil
     else
        'application'
     end
  end

end
