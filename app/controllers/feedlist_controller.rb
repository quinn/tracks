class FeedlistController < ApplicationController

  helper :feedlist

  def index
    @page_title = 'TRACKS::Feeds'
    
    unless mobile?
      init_data_for_sidebar 
    else
      @projects = Project.all_of_them
      @contexts = Context.all_of_them
    end
    
    @active_projects = Project.all_of_them.active
    @hidden_projects = Project.all_of_them.hidden
    @completed_projects = Project.all_of_them.completed
    
    @active_contexts = Context.all_of_them.active
    @hidden_contexts = Context.all_of_them.hidden
    
    respond_to do |format|
      format.html { render :layout => 'standard' }
      format.m { render :action => 'mobile_index' }
    end
  end
  
  def get_feeds_for_context
    context = Context.all_of_them.find params[:context_id]
    render :partial => 'feed_for_context', :locals => { :context => context }
  end

  def get_feeds_for_project
    project = Project.all_of_them.find params[:project_id]
    render :partial => 'feed_for_project', :locals => { :project => project }
  end

end
