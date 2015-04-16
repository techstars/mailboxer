module Mailboxer
  class Conversation
    class OptOut

      include Mongoid::Document
      include Mongoid::Timestamps

      store_in collection: :mailboxer_conversation_opt_outs

      belongs_to :conversation, :class_name  => "Mailboxer::Conversation", index: true
      belongs_to :unsubscriber, :polymorphic => true

      validates :unsubscriber, :presence => true

      scope :unsubscriber, lambda { |entity| where(:unsubscriber_type => entity.class.name, :unsubscriber_id => entity.id) }

    end
  end
end
