class EventsController < ApplicationController
  skip_before_filter :unauthorised_access, :only => [:index, :show, :new, :edit, :create, :update]
  before_filter :user_needs_to_be_a_viewer, :only => [:index, :show]
  before_filter :user_needs_to_be_an_archivist, :only => [:new, :edit, :create, :update]

  def index
    @events = JSONModel(:event).all(:page => selected_page)
  end

  def show
    @event = JSONModel(:event).find(params[:id])
  end

  def new
    @event = JSONModel(:event).new._always_valid!
    @event.linked_agents = [{}]
    @event.linked_records = [{}]
  end

  def edit
    @event = JSONModel(:event).find(params[:id], "resolve[]" => ["linked_agents", "linked_records"])
  end

  def create
    handle_crud(:instance => :event,
                :model => JSONModel(:event),
                :on_invalid => ->(){
                  render :action => :new
                },
                :on_valid => ->(id){
                  flash[:success] = I18n.t("event._html.messages.created")
                  return redirect_to :controller => :events, :action => :new if params.has_key?(:plus_one)

                  redirect_to :controller => :events, :action => :index, :id => id
                })
  end

  def update
    handle_crud(:instance => :event,
                :model => JSONModel(:event),
                :obj => JSONModel(:event).find(params[:id]),
                :on_invalid => ->(){ render :action => :edit },
                :on_valid => ->(id){
                  flash[:success] = I18n.t("event._html.messages.updated")
                  redirect_to :controller => :events, :action => :index
                })
  end

end
