class Vote < ActiveRecord::Base
  
  scope :deleted, :conditions => "votes.status = 'deleted'"
  scope :not_deleted, :conditions => "votes.status <> 'deleted'"
  scope :active, :conditions => "votes.status = 'active'", :include => {:change => :priority}, :order => "priorities.endorsements_count desc"
  scope :pending, :conditions => "votes.status in ('active','sent')", :include => {:change => :priority}, :order => "votes.created_at desc"

  belongs_to :user
  belongs_to :change
  has_many :activities  
  has_many :notifications, :as => :notifiable, :dependent => :destroy
  
  before_create :make_code
  after_create :add_notification

  include Workflow
  workflow_column :status
  workflow do
    state :active do
      event :approve, transitions_to: :approved
      event :decline, transitions_to: :declined
      event :implicit_approve, transitions_to: :implicit_approved
      event :implicit_decline, transitions_to: :implicit_declined
      event :deactivate, transitions_to: :inactive
      event :delete, transitions_to: :deleted
    end
    state :approved do
      event :delete, transitions_to: :deleted
    end
    state :implicit_approved
    state :declined do
      event :delete, transitions_to: :deleted
    end
    state :implicit_declined
    state :inactive do
      event :delete, transitions_to: :deleted
    end
    state :deleted
  end

  def on_approved_entry(new_state, event)
    self.voted_at = Time.now
    change.decrement!("no_votes") if self.status == 'declined'
    change.increment!("yes_votes")
    old_endorsement = replace
  end
  
  def on_implicit_approved_entry(new_state, event)
    old_endorsement = replace(true)
  end  
  
  def on_declined_entry(new_state, event)
    self.voted_at = Time.now
    change.decrement!("yes_votes") if self.status == 'approved'
    change.increment!("no_votes")
    ActivityPriorityAcquisitionProposalNo.create(:user => user, :change => change, :vote => self, :priority => change.priority)
  end
  
  def replace(implicit=false)
    old_endorsement = change.priority.endorsements.find_by_user_id(user.id)
    return true if not old_endorsement
    # do they already have the new endorsement?
    new_endorsement = change.new_priority.endorsements.find_by_user_id(user.id)
    if not new_endorsement
      if change.is_flip?
        if old_endorsement.is_up?
          new_endorsement = change.new_priority.oppose(user)
          if implicit
            ActivityOppositionFlippedImplicit.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          else
            ActivityOppositionFlipped.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          end
        else
          new_endorsement = change.new_priority.endorse(user)
          if implicit
            ActivityEndorsementFlippedImplicit.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          else
            ActivityEndorsementFlipped.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          end
        end        
      else
        if old_endorsement.is_up?
          new_endorsement = change.new_priority.endorse(user)
          if implicit
            ActivityEndorsementReplacedImplicit.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          else
            ActivityEndorsementReplaced.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          end
        else
          new_endorsement = change.new_priority.oppose(user)
          if implicit
            ActivityOppositionReplacedImplicit.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          else
            ActivityOppositionReplaced.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)          
          end
        end
      end
    else
      if change.is_flip?
        if old_endorsement.is_down?
          new_endorsement = change.new_priority.endorse(user)
          if implicit
            ActivityEndorsementFlippedImplicit.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          else
            ActivityEndorsementFlipped.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)          
          end
        else
          new_endorsement = change.new_priority.oppose(user)
          if implicit
            ActivityOppositionFlippedImplicit.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)            
          else
            ActivityOppositionFlipped.create(:user => user, :change => change, :priority => change.priority, :position => new_endorsement.position, :vote => self)
          end
        end
      end
    end
    if old_endorsement and new_endorsement and old_endorsement.attribute_present?("position") and new_endorsement.attribute_present?("position") and old_endorsement.position < new_endorsement.position
      new_endorsement.insert_at(old_endorsement.position) 
    end
    old_endorsement.replace!
    return old_endorsement    
  end
  
  def is_up?
    value == 1
  end
  
  def is_down?
    value == -1
  end

  private
  def add_notification
    notifications << NotificationChangeVote.new(:sender => self.change.user, :recipient => self.user)
  end
  
  def make_code
    self.code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end
  
end
