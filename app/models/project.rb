class Project < ActiveRecord::Base
  has_many :todos, :dependent => :delete_all, :include => :context
  has_many :notes, :dependent => :delete_all, :order => "created_at DESC"
  belongs_to :default_context, :class_name => "Context", :foreign_key => "default_context_id"
  belongs_to :user

  named_scope :active, :conditions => { :state => 'active' }
  named_scope :hidden, :conditions => { :state => 'hidden' }
  named_scope :completed, :conditions => { :state => 'completed'}
  named_scope :all_of_them, :conditions => "1 = 1" do
      def find_by_params(params)
        find(params['id'] || params['project_id'])
      end
      def update_positions(project_ids)
        project_ids.each_with_index do |id, position|
          project = self.detect { |p| p.id == id.to_i }
          raise "Project id #{id} not associated with user id #{@user.id}." if project.nil?
          project.update_attribute(:position, position + 1)
        end
      end
      def projects_in_state_by_position(state)
          self.sort{ |a,b| a.position <=> b.position }.select{ |p| p.state == state }
      end
      def next_from(project)
        self.offset_from(project, 1)
      end
      def previous_from(project)
        self.offset_from(project, -1)
      end
      def offset_from(project, offset)
        projects = self.projects_in_state_by_position(project.state)
        position = projects.index(project)
        return nil if position == 0 && offset < 0
        projects.at( position + offset)
      end
      def cache_note_counts
        project_note_counts = Note.count(:group => 'project_id')
        self.each do |project|
          project.cached_note_count = project_note_counts[project.id] || 0
        end
      end
      def alphabetize(scope_conditions = {})
        projects = find(:all, :conditions => scope_conditions)
        projects.sort!{ |x,y| x.name.downcase <=> y.name.downcase }
        self.update_positions(projects.map{ |p| p.id })
        return projects
      end
      def actionize(user_id, scope_conditions = {})
        @state = scope_conditions[:state]
        query_state = ""
        query_state = "AND project.state = '" + @state +"' "if @state
        projects = Project.find_by_sql([
            "SELECT project.id, count(todo.id) as p_count " +
              "FROM projects as project " +
              "LEFT OUTER JOIN todos as todo ON todo.project_id = project.id "+
              "WHERE project.user_id = ? AND NOT todo.state='completed' " +
              query_state +
              " GROUP BY project.id ORDER by p_count DESC",user_id])
        self.update_positions(projects.map{ |p| p.id })
        projects = find(:all, :conditions => scope_conditions)
        return projects
      end
    end
  
  validates_presence_of :name, :message => "project must have a name"
  validates_length_of :name, :maximum => 255, :message => "project name must be less than 256 characters"
  validates_uniqueness_of :name, :message => "already exists", :scope =>"user_id"
  validates_does_not_contain :name, :string => ',', :message => "cannot contain the comma (',') character"

  acts_as_list :scope => 'user_id = #{user_id} AND state = \'#{state}\''
  acts_as_state_machine :initial => :active, :column => 'state'
  extend NamePartFinder
  include Tracks::TodoList
  
  state :active
  state :hidden, :enter => :hide_todos, :exit => :unhide_todos
  state :completed, :enter => Proc.new { |p| p.completed_at = Time.zone.now }, :exit => Proc.new { |p| p.completed_at = nil }

  event :activate do
    transitions :to => :active,   :from => [:hidden, :completed]
  end
  
  event :hide do
    transitions :to => :hidden,   :from => [:active, :completed]
  end
  
  event :complete do
    transitions :to => :completed, :from => [:active, :hidden]
  end
  
  attr_protected :user
  attr_accessor :cached_note_count

  def self.null_object
    NullProject.new
  end
  
  def self.feed_options(user)
    {
      :title => 'Tracks Projects',
      :description => "Lists all the projects for #{user.display_name}"
    }
  end
      
  def hide_todos
    todos.each do |t|
      unless t.completed? || t.deferred?
        t.hide!
        t.save
      end
    end
  end
      
  def unhide_todos
    todos.each do |t|
      if t.project_hidden?
        t.unhide!
        t.save
      end
    end
  end
  
  def note_count
    cached_note_count || notes.count
  end
  
  alias_method :original_default_context, :default_context

  def default_context
    original_default_context.nil? ? Context.null_object : original_default_context
  end
  
  # would prefer to call this method state=(), but that causes an endless loop
  # as a result of acts_as_state_machine calling state=() to update the attribute
  def transition_to(candidate_state)
    case candidate_state.to_sym
      when current_state
        return
      when :hidden
        hide!
      when :active
        activate!
      when :completed
        complete!
    end
  end
  
  def name=(value)
    self[:name] = value.gsub(/\s{2,}/, " ").strip
  end
  
  def new_record_before_save?
    @new_record_before_save
  end  
  
end

class NullProject
  
  def hidden?
    false
  end
  
  def nil?
    true
  end
  
  def id
    nil
  end
    
end