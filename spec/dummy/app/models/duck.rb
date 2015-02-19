class Duck

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :email, type: String

  include Mailboxer::Messageable

  def mailboxer_email(object)
    case object
    when Mailboxer::Message
      return nil
    when Mailboxer::Notification
      return email
    end
  end

end
