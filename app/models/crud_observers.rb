module Observations
  def send message
    $morbid.send "$TRACKS_CRUD", message
  end

  def after_create record
    send %{
      A #{record.class} has been Created:
      
      #{record.inspect}
    }
  end
  
  def after_update record
    send %{
      A #{record.class} has been Updated:
      
      #{record.inspect}
    }
  end
  
  def after_destroy record
    send %{
      A #{record.class} has been Destroyed:
      
      #{record.inspect}
    }
  end
end

class ContextObserver
  include Observations
end

class ProjectObserver
  include Observations
end

class TodoObserver
  include Observations
end
