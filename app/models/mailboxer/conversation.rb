class Mailboxer::Conversation

  include Mongoid::Document
  include Mongoid::Timestamps

  store_in collection: :mailboxer_conversations

  field :subject, type: String,  :default => ""

  attr_accessible :subject if Mailboxer.protected_attributes?

  has_many :opt_outs, :dependent => :destroy, :class_name => "Mailboxer::Conversation::OptOut"
  has_many :messages, :dependent => :destroy, :class_name => "Mailboxer::Message"
  has_many :receipts, :class_name => "Mailboxer::Receipt"

  validates :subject, :presence => true,
                      :length => { :maximum => Mailboxer.subject_max_length }

  index({ created_at: 1 },{ background: true })
  index({ updated_at: 1 },{ background: true })

  before_validation :clean

  class << self
    def participant(participant)
      # Conversations with the participant
      c_ids = Mailboxer::Receipt.recipient(participant).map{|r| r.conversation.id }.uniq
      self.in(id: c_ids).desc(:updated_at)
    end

    def inbox(participant)
      c_ids = Mailboxer::Receipt.recipient(participant).inbox.not_trash.not_deleted.map{|r| r.conversation.id }.uniq
      self.in(id: c_ids)
    end

    def sentbox(participant)
      c_ids = Mailboxer::Receipt.recipient(participant).sentbox.not_trash.not_deleted.map{|r| r.conversation.id }.uniq
      self.in(id: c_ids)
    end  

    def trash(participant)
      c_ids = Mailboxer::Receipt.recipient(participant).trash.map{|r| r.conversation.id }.uniq
      self.in(id: c_ids)
    end

    def unread(participant)
      c_ids = Mailboxer::Receipt.recipient(participant).is_unread.map{|r| r.conversation.id }.uniq
      self.in(id: c_ids)
    end

    def not_trash(participant)
      c_ids = Mailboxer::Receipt.recipient(participant).not_trash.map{|r| r.conversation.id }.uniq
      self.in(id: c_ids)
    end
  end

  #Mark the conversation as read for one of the participants
  def mark_as_read(participant)
    return unless participant
    receipts_for(participant).mark_as_read
  end

  #Mark the conversation as unread for one of the participants
  def mark_as_unread(participant)
    return unless participant
    receipts_for(participant).mark_as_unread
  end

  #Move the conversation to the trash for one of the participants
  def move_to_trash(participant)
    return unless participant
    receipts_for(participant).move_to_trash
  end

  #Takes the conversation out of the trash for one of the participants
  def untrash(participant)
    return unless participant
    receipts_for(participant).untrash
  end

  #Mark the conversation as deleted for one of the participants
  def mark_as_deleted(participant)
    return unless participant
    deleted_receipts = receipts_for(participant).mark_as_deleted
    if is_orphaned?
      destroy
    else
      deleted_receipts
    end
  end

  #Returns an array of participants
  def recipients
    return [] unless original_message
    Array original_message.recipients
  end

  #Returns an array of participants
  def participants
    recipients
  end

  #Originator of the conversation.
  def originator
    @originator ||= original_message.sender
  end

  #First message of the conversation.
  def original_message
    @original_message ||= messages.asc(:created_at).first
  end

  #Sender of the last message.
  def last_sender
    @last_sender ||= last_message.sender
  end

  #Last message in the conversation.
  def last_message
    @last_message ||= messages.desc(:created_at).first
  end

  #Returns the receipts of the conversation for one participants
  def receipts_for(participant)
    Mailboxer::Receipt.conversation(self).recipient(participant)
  end

  #Returns the number of messages of the conversation
  def count_messages
    Mailboxer::Message.conversation(self).count
  end

  #Returns true if the messageable is a participant of the conversation
  def is_participant?(participant)
    return false unless participant
    receipts_for(participant).any?
  end

  #Adds a new participant to the conversation
  def add_participant(participant)
    messages.each do |message|
      Mailboxer::ReceiptBuilder.new({
        :notification => message,
        :conversation => self,
        :receiver     => participant,
        :updated_at   => message.updated_at,
        :created_at   => message.created_at
      }).build.save!
    end
  end

  #Returns true if the participant has at least one trashed message of the conversation
  def is_trashed?(participant)
    return false unless participant
    receipts_for(participant).trash.count != 0
  end

  #Returns true if the participant has deleted the conversation
  def is_deleted?(participant)
    return false unless participant
    return receipts_for(participant).deleted.count == receipts_for(participant).count
  end

  #Returns true if both participants have deleted the conversation
  def is_orphaned?
    participants.reduce(true) do |is_orphaned, participant|
      is_orphaned && is_deleted?(participant)
    end
  end

  #Returns true if the participant has trashed all the messages of the conversation
  def is_completely_trashed?(participant)
    return false unless participant
    receipts_for(participant).trash.count == receipts_for(participant).count
  end

  def is_read?(participant)
    !is_unread?(participant)
  end

  #Returns true if the participant has at least one unread message of the conversation
  def is_unread?(participant)
    return false unless participant
    receipts_for(participant).not_trash.is_unread.count != 0
  end

  # Creates a opt out object
  # because by default all participants are opt in
  def opt_out(participant)
    return unless has_subscriber?(participant)
    opt_outs.create(:unsubscriber => participant)
  end

  # Destroys opt out object if any
  # a participant outside of the discussion is, yet, not meant to optin
  def opt_in(participant)
    opt_outs.unsubscriber(participant).destroy_all
  end

  # tells if participant is opt in
  def has_subscriber?(participant)
    !opt_outs.unsubscriber(participant).any?
  end

  protected

  #Use the default sanitize to clean the conversation subject
  def clean
    self.subject = sanitize subject
  end

  def sanitize(text)
    ::Mailboxer::Cleaner.instance.sanitize(text)
  end
end
