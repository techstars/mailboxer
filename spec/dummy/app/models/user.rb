class User

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :email, type: String

  include Mailboxer::Messageable

  def mailboxer_email(object)
    return email
  end

end
