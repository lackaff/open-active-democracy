class Partner < ActiveRecord::Base

  require 'paperclip'
  
  scope :active, :conditions => "status in ('pending','active')"
  
  scope :with_logo, :conditions => "logo_file_name is not null"
  
  belongs_to :picture
  
  has_attached_file :logo, :styles => { :icon_96 => "96x96#", :icon_140 => "140x140#", :icon_214_32 => "214x32#", :icon_107_16 => "107x16#", :icon_53_8 => "53x8#", :icon_180 => "180x180#", :medium  => "450x" }
    
  validates_attachment_size :logo, :less_than => 5.megabytes
  validates_attachment_content_type :logo, :content_type => ['image/jpeg', 'image/png', 'image/gif']
  
  has_one :owner, :class_name => "User", :foreign_key => "partner_id"
  has_many :signups
  has_many :users, :through => :signups
  has_many :activities
  has_many :priorities
  
  belongs_to :iso_country, :class_name => 'Tr8n::IsoCountry'

  # docs: http://www.vaporbase.com/postings/stateful_authentication
  acts_as_state_machine :initial => :passive, :column => :status
  
  state :passive
  state :pending
  state :active, :enter => :do_activate
  state :suspended
  state :deleted, :enter => :do_delete
  
  event :register do
    transitions :from => :passive, :to => :pending
  end

  event :activate do
    transitions :from => :pending, :to => :active 
  end
  
  event :suspend do
    transitions :from => [:passive, :pending, :active], :to => :suspended
  end
  
  event :delete do
    transitions :from => [:passive, :pending, :active, :suspended], :to => :deleted
  end

  event :unsuspend do
    transitions :from => :suspended, :to => :active, :guard => Proc.new {|u| !u.activated_at.blank? }
    transitions :from => :suspended, :to => :pending, :guard => Proc.new {|u| !u.activation_code.blank? }
    transitions :from => :suspended, :to => :passive
  end  

  before_save :clean_urls
  
  before_validation :shorten_name

  belongs_to :iso_country, :class_name => 'Tr8n::IsoCountry', :foreign_key => :iso_country_id

  def shorten_name
    short_name.gsub(/[^a-z0-9]+/i, '-')
  end
  
  def validate
    if is_optin? and not attribute_present?("optin_text")
      errors.add("optin_text",tr("Please specify the opt-in language if you wish to request their permission to be added to your email list.",""))
    end
    if is_optin? and optin_text.size > 60
      errors.add("optin_text",tr("needs to be less than 60 characters. Keep it short!",""))
    end    
    errors.on("optin_text")    
    if is_optin? and not attribute_present?("privacy_url")
      errors.add("privacy_url", tr("Please specify the URL to your privacy policy. This is required if you request the new member's permission to be added to your email list.",""))
    end
    errors.on("privacy_url")   
    if is_optin? and not attribute_present?("subscribe_url")
      errors.add("subscribe_url", tr("Please specify the URL where people can subscribe to your email list. This is required.",""))
    end
    errors.on("subscribe_url")
    if is_optin? and not attribute_present?("unsubscribe_url")
      errors.add("unsubscribe_url", tr("Please specify the URL where people can unsubscribe to your email list. This is required.",""))
    end
    errors.on("unsubscribe_url")       
  end

  validates_length_of       :short_name,    :within => 2..20, :message => tr("should be between 2 and 20 characters.","")
  validates_uniqueness_of   :short_name, :case_sensitive => false, :message => tr("is already taken.","")
  validates_length_of       :name, :within => 2..30, :message => tr("should be within 3 and 30 characters.","")

  ReservedShortnames = %w[admin blog ftp mail pop pop3 imap smtp stage stats status www localize feedback facebook]
  validates_exclusion_of :short_name, :in => ReservedShortnames, :message => tr('is already taken',"")

  def self.current  
    Thread.current[:partner]  
  end  

  def self.current_id
    if Thread.current[:partner]
      Thread.current[:partner].id
    else
      "nopartner"
    end
  end

  def self.current=(partner)
    Thread.current[:partner] = partner
  end

  def geoblocking_disabled_for?(country_code)
    self.geoblocking_open_countries.split.include?(country_code)
  end

  def clean_urls
    privacy_url = 'http://' + privacy_url if not privacy_url.nil? and privacy_url[0..3] != 'http' 
    unsubscribe_url = 'http://' + unsubscribe_url if not unsubscribe_url.nil? and unsubscribe_url[0..3] != 'http'
    subscribe_url = 'http://' + subscribe_url if not subscribe_url.nil? and subscribe_url[0..3] != 'http'    
  end  
    
  def to_param
    "#{id}-#{short_name.parameterize_full}"
  end

  def do_activate
    ActivityPartnerNew.create(:user => owner, :partner => self)
  end
  
  def has_picture?
    attribute_present?("picture_id")
  end
  
  def has_logo?
    attribute_present?("logo_file_name")
  end
  
  def has_website?
    attribute_present?("website")
  end  
  
  def website_link
    return nil if self.website.nil?
    wu = website
    wu = 'http://' + wu if wu[0..3] != 'http'
    return wu    
  end
  
  def show_url
    'http://' + self.short_name + '.' + Government.current.base_url + '/'
  end
  
  def custom_tag_dropdown_options(option)
    options = send("custom_tag_dropdown_#{option}")
    out = ""
    options.split(",").each do |o|
      out+="<option>#{o}</option>"
    end
    out
  end
  
  def name_variations
    if self.name_variations_data and self.name_variations_data!=""
      self.name_variations_data.split(",")
    else
      ["missing","missing","missing","missing","missing","missing","missing","missing","missing"]
    end
  end
  
  private
  def do_delete
    deleted_at = Time.now
  end  
end
