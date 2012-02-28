class DocumentRevision < ActiveRecord::Base

  scope :published, :conditions => "document_revisions.status = 'published'"
  scope :by_recently_created, :order => "document_revisions.created_at desc"  

  belongs_to :document  
  belongs_to :user

  has_many :activities
  has_many :notifications, :as => :notifiable, :dependent => :destroy

  after_create :on_published_entry

  include Workflow
  workflow_column :status
  workflow do
    state :draft do
      event :publish, transitions_to: :published
    end
    state :archived do
      event :publish, transitions_to: :published
      event :delete, transitions_to: :deleted
    end
    state :published do
      event :archive, transitions_to: :archived
      event :delete, transitions_to: :deleted
    end
    state :deleted do
      event :undelete, transitions_to: :published, meta: { validates_presence_of: [:published_at] }
      event :undelete, transitions_to: :draft
    end
  end

  before_save :update_word_count
  
  before_save :truncate_user_agent
  
  def truncate_user_agent
    self.user_agent = self.user_agent[0..149] if self.user_agent # some user agents are longer than 150 chars!
  end  
  
  def on_published_entry(new_state = nil, event = nil)
    self.published_at = Time.now
    self.auto_html_prepare
    begin
      Timeout::timeout(5) do   #times out after 5 seconds
        self.content_diff = HTMLDiff.diff(document.content,self.content).html_safe
      end
    rescue Timeout::Error
    end    
    document.revisions_count += 1    
    changed = false
    if document.revisions_count == 1
      ActivityDocumentNew.create(:user => user, :priority => document.priority, :document => document, :document_revision => self)
    else
      if document.content != self.content # they changed content
        changed = true
        ActivityDocumentRevisionContent.create(:user => user, :priority => document.priority, :document => document, :document_revision => self)
      end
      if document.name != self.name 
        changed = true
        ActivityDocumentRevisionName.create(:user => user, :priority => document.priority, :document => document, :document_revision => self)
      end
      if document.value != self.value and document.priority
        changed = true
        if self.is_up?
          ActivityDocumentRevisionSupportive.create(:user => user, :priority => document.priority, :document => document, :document_revision => self)
        elsif self.is_neutral?
          ActivityDocumentRevisionNeutral.create(:user => user, :priority => document.priority, :document => document, :document_revision => self)
        elsif self.is_down?
          ActivityDocumentRevisionOpposition.create(:user => user, :priority => document.priority, :document => document, :document_revision => self)
        end
      end      
    end    
    if changed
      sent = []
      for a in document.author_users
        if a.id != self.user_id
          notifications << NotificationDocumentRevision.new(:sender => self.user, :recipient => a)    
          sent << a.id
        end 
      end
    end    
    document.content = self.content
    document.revision_id = self.id
    document.name = self.name
    document.value = self.value
    document.author_sentence = document.user.login
    document.author_sentence += ", breytingar " + document.editors.collect{|a| a[0].login}.to_sentence if document.editors.size > 0
    document.published_at = Time.now
    document.save(:validate => false)
    user.increment!(:document_revisions_count)
  end
  
  def on_archived_entry(new_state, event)
    self.published_at = nil
  end
  
  def on_deleted_entry(new_state, event)
    document.decrement!(:revisions_count)
    user.decrement!(:document_revisions_count)    
  end
  
  def update_word_count
    self.word_count = self.content.split(' ').length
  end
  
  def is_up?
    value > 0
  end
  
  def is_down?
    value < 0
  end
  
  def is_neutral?
    value == 0
  end

  def priority_name
    priority.name if priority
  end
  
  def priority_name=(n)
    self.priority = Priority.find_by_name(n) unless n.blank?
  end

  def text
    s = document.name
    s += " [#{tr("Against", "model/revision")}]" if is_down?
    s += " [#{tr("Neutral", "model/revision")}]" if is_neutral? and has_priority?
    s += "\r\n" + content
    return s
  end  
  
  def has_priority?
    attribute_present?("priority_id")
  end
  
  def request=(request)
    if request
      self.ip_address = request.remote_ip
      self.user_agent = request.env['HTTP_USER_AGENT']
    end
  end
  
  def DocumentRevision.create_from_document(document_id, request)
    p = Document.find(document_id)
    r = DocumentRevision.new
    r.document = p
    r.user = p.user
    r.value = p.value
    r.name = p.name
    r.content = p.content
    r.content_diff = p.content 
    r.request = request
    r.save(:validate => false)
    r.publish!
  end
  
  def url
    'http://' + Government.current.base_url_w_partner + '/documents/' + document_id.to_s + '/revisions/' + id.to_s + '?utm_source=documents_changed&utm_medium=email'
  end

  auto_html_for(:content) do
    html_escape
    youtube(:width => 460, :height => 285)
    vimeo(:width => 460, :height => 260)
    link :target => "_blank", :rel => "nofollow"
  end

end
