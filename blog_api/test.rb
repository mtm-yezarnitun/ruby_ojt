class User
  attr_accessor :name, :email

  def initialize(name, email)
    @name = name
    @email = email
  end

  def update(attrs = {})
    copy = dup
    attrs.each { |k, v| copy.send("#{k}=", v) }
    copy
  end

  def update!(attrs = {})
    attrs.each { |k, v| send("#{k}=", v) }
    self
  end
end

user1 = User.new("Alice", "a@example.com")

user2 = user1.update(name: "Bob", email: "b@example.com")
puts user1.name  
puts user2.name 
puts user2.email

user2.update!(name: "Kim")
puts user2.name

user1.update!(name: "Cam")
puts user1.name  
puts user1.email


