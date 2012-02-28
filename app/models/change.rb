class Change < ActiveRecord::Base

  scope :suggested, :conditions => "changes.status = 'suggested'"
  scope :notsent, :conditions => "changes.status = 'notsent'"
  scope :sent, :conditions => "changes.status = 'sent'"  
  scope :approved, :conditions => "changes.status = 'approved'"
  scope :declined, :conditions => "changes.status = 'declined'"  
  scope :voting, :conditions => "changes.status in ('approved','declined','sent')"
  
  scope :active, :conditions => "changes.status in ('sent','suggested')"
  scope :inactive, :conditions => "changes.status in ('notsent','approved','declined')"
  scope :not_deleted, :conditions => "changes.status <> 'deleted'"
  scope :deleted, :conditions => "changes.status = 'deleted'"

  scope :by_recently_created, :order => "changes.created_at desc"
  scope :by_recently_started, :order => "changes.sent_at desc"  
  scope :by_recently_updated, :order => "changes.updated_at desc"  

  scope :item_limit, lambda{|limit| {:limit=>limit}}

  belongs_to :priority
  belongs_to :new_priority, :class_name => "Priority", :foreign_key => "new_priority_id"
  belongs_to :user
  
  has_many :votes, :dependent => :destroy
  has_many :activities, :dependent => :destroy
  has_many :notifications, :as => :notifiable, :dependent => :destroy
    
  def validate
    if user.capitals_count < calculate_cost
      errors.add(:base, tr("You dont have enough captial to suggest a takeover", "model/change"))
    end
    if new_priority == priority
      errors.add(:base, tr("You cant suggest a take over of the same priority", "model/change"))
    end
    if not is_endorsers and not is_opposers
      errors.add(:base, tr("You must select either supporters or opposers", "model/change"))
    end
    if priority.has_change?
      errors.add(:base, tr("This priority already has a take over in progress", "model/change"))
    end
  end
  
  validates_presence_of :priority, :user
  validates_presence_of :new_priority, :message => tr("Could not find, make sure you entered it correctly", "model/change")
  validates_length_of :content, :maximum => 500, :allow_nil => true, :allow_blank => true  
  
  acts_as_list

  include Workflow
  workflow_column :status
  workflow do
    state :suggested do
      event :send, transitions_to: :sent
      event :dont_send, transitions_to: :notsent
      event :approve, transitions_to: :approved
      event :decline, transitions_to: :declined
      event :delete, transitions_to: :deleted
    end
    state :sent do
      event :approve, transitions_to: :approved
      event :decline, transitions_to: :declined
      event :delete, transitions_to: :deleted
    end
    state :notsent
    state :approved do
      event :delete, transitions_to: :deleted
    end
    state :declined do
      event :delete, transitions_to: :deleted
    end
    state :delete
  end

  after_create :add_to_priority
  after_create :log_activity
  before_create :add_cost
  
  def calculate_estimated_votes_count
    ballots = 0
    ballots += priority.up_endorsements_count if is_endorsers?
    ballots += priority.down_endorsements_count if is_opposers?
    return ballots
  end  
  
  def per_user_cost
    0.01
  end
  
  def cost_opposers
    return 0 if priority.down_endorsements_count == 0
    (priority.down_endorsements_count*per_user_cost).to_i+1
  end
  
  def cost_endorsers
    return 0 if priority.up_endorsements_count == 0    
    (priority.up_endorsements_count*per_user_cost).to_i+1
  end  
  
  def calculate_cost
    (calculate_estimated_votes_count*per_user_cost).to_i+1
  end
  
  def add_cost
    self.cost = calculate_cost
    self.estimated_votes_count = calculate_estimated_votes_count
  end
  
  cattr_reader :per_page
  @@per_page = 15
  
  def log_activity
    user.increment(:changes_count)
    @activity = ActivityCapitalAcquisitionProposal.create(:user => user, :priority => priority, :change => self, :capital => CapitalAcquisitionProposal.create(:sender => user, :amount => self.cost))
    for u in User.active.admins.all
      notifications << NotificationChangeProposed.new(:sender => user, :recipient => u) if u.id != user.id
    end
    if self.attribute_present?("content")
      @comment = @activity.comments.new
      @comment.content = content
      @comment.user = user
      if priority
        # if this is related to a priority, check to see if they endorse it
        e = priority.endorsements.active_and_inactive.find_by_user_id(user.id)
        @comment.is_endorser = true if e and e.is_up?
        @comment.is_opposer = true if e and e.is_down?
      end
      @comment.save(:validate => false)
    end
  end  
  
  def add_to_priority
    priority.update_attribute(:change_id,id)
  end

  def new_priority_name
    new_priority.name if new_priority
  end
  
  def new_priority_name=(n)
    self.new_priority = Priority.find_by_name(n) unless n.blank?
  end
  
  def priority_name
    priority.name if priority
  end
  
  def priority_name=(n)
    self.priority = Priority.find_by_name(n) unless n.blank?
  end  
  
  def time_left
    return '0 mins' if self.is_expired?
    amt = (self.sent_at+2.days) - Time.now
    minutes = (amt/60).round
    hours = (minutes/60).round
    minutes_left = minutes - (hours*60)
    if hours < 1
      return minutes_left.to_s + " #{tr("min", "model/change")}."
    elsif hours == 1
      return hours.to_s + " #{tr("hr", "model/change")} " + minutes_left.to_s + " #{tr("min", "model/change")}."      
    else
      return hours.to_s + " #{tr("hr", "model/change")} " + minutes_left.to_s + " #{tr("min", "model/change")}."
    end
  end
  
  def past_changes
    Change.find(:all, :conditions => ["status in ('sent','approved','declined') and id <> ? and ((priority_id = ? and new_priority_id = ?) or (priority_id = ? and new_priority_id = ?))",self.id,self.priority_id,self.new_priority_id,self.new_priority_id,self.priority_id])    
  end
  
  def past_change_ids
    past_changes.collect{|c| c.id}    
  end
    
  def past_voters
    Vote.find(:all, :conditions => ["change_id in (?)",past_change_ids] )
  end
  
  def past_voter_ids
    past_voters.collect{|c| c.user_id}
  end
  
  def on_sent_entry(new_state, event)
    ballots = 0
    if is_endorsers?
      for u in priority.up_endorsers
        v = Vote.new(:user => u, :change => self) 
        if is_flip?        
          v.value = -1 
        else
          v.value = 1
        end
        v.save(:validate => false)
        ballots += 1
      end
    end
    if is_opposers?
      for u in priority.down_endorsers
        v = Vote.new(:user => u, :change => self) 
        if is_flip?        
          v.value = 1 
        else
          v.value = -1
        end
        v.save(:validate => false)
        ballots += 1
      end
    end
    self.votes_count = ballots
    self.sent_at = Time.now
    remove_notifications    
  end
  
  # this method is based on not including folks who have voted on this acquisition in the past
  #def on_sent_entry(new_state, event)
  #  if is_up?
  #    eusers = priority.up_endorsers
  #  elsif is_down?
  #    eusers = priority.down_endorsers
  #  elsif is_both?
  #    eusers = priority.endorsers
  #  end
  #  ballots = 0    
  #  for u in eusers
  #    if not past_voter_ids.include?(u.id)
  #      v = Vote.create(:user => u, :change => self) 
  #      ballots += 1
  #      # v.send! -- don't send it anymore, it gets batched once a day
  #    end
  #  end
  #  self.votes_count = ballots
  #  self.sent_at = Time.now
  #end
  
  def on_notsent_entry(new_state, event)
    priority.update_attribute(:change_id,nil)    
    # refund their political capital
    if self.has_cost?
      ActivityCapitalAcquisitionProposalDeleted.create(:user => user, :priority => priority, :change => self, :capital => CapitalAcquisitionProposalDeleted.create(:recipient => user, :amount => self.cost))
    end
    remove_notifications    
  end  
  
  def on_approved_entry(new_state, event)
    self.approved_at = Time.now
    for vote in self.votes.pending
      vote.implicit_approve!
    end
    # uncommenting this would remove the change_id from the acquired priority, messing up the replaced functionality
    # priority.update_attribute(:change_id,nil) 
    priority.reload
    priority.deactivate! if priority.endorsements.length == 0
    ActivityPriorityAcquisitionProposalApproved.create(:change => self, :priority => priority, :user => user)
    # reward them with more political capital because it was such a success
    if self.has_cost?
      ActivityCapitalAcquisitionProposalApproved.create(:user => user, :priority => priority, :change => self, :capital => CapitalAcquisitionProposalApproved.create(:recipient => user, :amount => self.cost*2))
    end
    remove_notifications    
  end
  
  def insta_approve!
    approve!
    if is_flip?
      priority.flip_into(new_priority_id,true)
    else
      priority.merge_into(new_priority_id,true)
    end
    remove_notifications    
  end
  
  def on_declined_entry(new_state, event)
    self.declined_at = Time.now
    priority.update_attribute(:change_id,nil)    
    for vote in self.votes.pending
      vote.implicit_decline!
    end
    ActivityPriorityAcquisitionProposalDeclined.create(:change => self, :priority => priority, :user => user)
    remove_notifications    
  end
  
  def on_deleted_entry(new_state, event)
    priority.update_attribute(:change_id,nil)    
    # refund their political capital
    if has_cost?
      ActivityCapitalAcquisitionProposalDeleted.create(:user => user, :priority => priority, :change => self, :capital => CapitalAcquisitionProposalDeleted.create(:recipient => user, :amount => self.cost))
    end
    remove_notifications
  end
  
  def remove_notifications
    for n in notifications
      n.destroy
    end
    return true
  end

  def has_reason?
    attribute_present?("content")
  end
  
  def has_cost?
    attribute_present?("cost") and cost > 0
  end  
  
  def total_votes
    yes_votes + no_votes
  end
  
  def is_voting?
    self.status == 'sent'
  end
  
  def is_passing?
    return true if (yes_votes+no_votes) == 0
    (yes_votes.to_f/total_votes.to_f) >= 0.70
  end
  
  def is_failing?
    not is_passing?
  end
  
  def is_active?
    ['sent','suggested'].include?(status)
  end
  
  def is_expired?
    return true if ['approved','declined','notsent'].include?(status)
    return false if not self.attribute_present?("sent_at")
    Time.now > (self.sent_at+2.days)
  end
  
  def show_url
    priority.show_url + '/changes/' + id.to_s
  end
  
end
