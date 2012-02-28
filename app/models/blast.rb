class Blast < ActiveRecord::Base
  
  belongs_to :user

  include Workflow
  workflow_column :status
  workflow do
    state :pending do
      event :send, transitions_to: :sent
      event :dont_send, transitions_to: :notsent
    end
    state :sent
    state :notsent
  end

  before_create :make_code
  
  private
  def make_code
    self.code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end

end

class BlastNewsletter < Blast
  def on_sent_entry(new_state, event)
    self.sent_at = Time.now    
    Blaster.deliver_newsletter(self,user)
  end
end

class BlastUserNewsletter < Blast
  def on_sent_entry(new_state, event)
    self.sent_at = Time.now
    Blaster.deliver_user_newsletter(self,user)
  end
end

class BlastAddPicture < Blast
  
  belongs_to :tag
  
  def on_sent_entry(new_state, event)
    self.sent_at = Time.now    
    Blaster.deliver_add_picture(user,tag)
  end
  
end

class BlastAlert < Blast
  
  belongs_to :tag
  
  def on_sent_entry(new_state, event)
    self.sent_at = Time.now    
    Blaster.deliver_alert(user,tag)
  end
  
end

class BlastBasic < Blast
  def on_sent_entry(new_state, event)
    self.sent_at = Time.now
    Blaster.deliver_basic_blast(self,user)
  end
end
