class Mailboxer::Message < Mailboxer::Notification

  field :subject, type: String,  :default => ""
  field :body,    type: String,  :default => ""

  belongs_to :conversation, :class_name => "Mailboxer::Conversation", :validate => true, :autosave => true, index: true
  validates_presence_of :sender

  class_attribute :on_deliver_callback
  protected :on_deliver_callback

  class << self
    #Sets the on deliver callback method.
    def on_deliver(callback_method)
      self.on_deliver_callback = callback_method
    end

    def conversation(conversation)
      where(conversation_id: conversation.id)
    end
  end

  #Delivers a Message. USE NOT RECOMENDED.
  #Use Mailboxer::Models::Message.send_message instead.
  def deliver(reply = false, should_clean = true)
    self.clean if should_clean

    #Receiver receipts
    temp_receipts = recipients.map { |r| build_receipt(r, 'inbox') }

    #Sender receipt
    sender_receipt = build_receipt(sender, 'sentbox', true)

    temp_receipts << sender_receipt

    if temp_receipts.all?(&:valid?)
      temp_receipts.each(&:save!)
      Mailboxer::MailDispatcher.new(self, recipients).call

      conversation.touch if reply

      self.recipients = nil

      on_deliver_callback.call(self) if on_deliver_callback
    end
    sender_receipt
  end

  private

  def build_receipt(receiver, mailbox_type, is_read = false)
    Mailboxer::ReceiptBuilder.new({
      :notification => self,
      :conversation => self.conversation,
      :mailbox_type => mailbox_type,
      :receiver     => receiver,
      :is_read      => is_read,
    }).build
  end

  if Mailboxer.search_enabled
    searchkick
  end

end
