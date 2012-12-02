class ResourcesController < ApplicationController
  skip_before_filter :unauthorised_access, :only => [:index, :show, :new, :edit, :create, :update]
  before_filter :user_needs_to_be_a_viewer, :only => [:index, :show]
  before_filter :user_needs_to_be_an_archivist, :only => [:new, :edit, :create, :update]

  def index
    @search_data = JSONModel(:resource).all(:page => selected_page)
  end

  def show
    @resource = JSONModel(:resource).find(params[:id], "resolve[]" => ["subjects", "location", "ref"])

    if params[:inline]
      return render :partial => "resources/show_inline"
    end

    fetch_tree
  end

  def new
    @resource = JSONModel(:resource).new({:title => "New Resource"})._always_valid!
    @resource.extents = [JSONModel(:extent).new._always_valid!]
    return render :partial => "resources/new_inline" if params[:inline]
  end

  def edit
    @resource = JSONModel(:resource).find(params[:id], "resolve[]" => ["subjects", "location", "ref"])
    fetch_tree
    return render :partial => "resources/edit_inline" if params[:inline]
  end


  def create
    handle_crud(:instance => :resource,
                :on_invalid => ->(){ render action: "new" },
                :on_valid => ->(id){
                  flash[:success] = "Resource Created"
                  redirect_to(:controller => :resources,
                                                 :action => :edit,
                                                 :id => id)
                 })
  end


  def update
    handle_crud(:instance => :resource,
                :obj => JSONModel(:resource).find(params[:id],
                                                  "resolve[]" => ["subjects", "location", "ref"]),
                :on_invalid => ->(){
                  render :partial => "edit_inline"
                },
                :on_valid => ->(id){
                  flash[:success] = "Resource Saved"
                  render :partial => "edit_inline"
                })
  end


  private

  def fetch_tree
    @tree = JSONModel(:resource_tree).find(nil, :resource_id => @resource.id)
  end

end
