account = Account.default
account.update!(name: "Lykke") if account.name.blank? || account.name == "Default Account"

admins = [
  { name: "Admin", email: "admin@getlykke.com" },
  { name: "Ashish", email: "ashish@getlykke.com" },
  { name: "Pranav", email: "pranav@getlykke.com" },
]

password = "lykke@123"

admins.each do |a|
  pseudonym = Pseudonym.active.by_unique_id(a[:email]).first
  if pseudonym
    user = pseudonym.user
    pseudonym.password = password
    pseudonym.password_confirmation = password
    pseudonym.save!
    puts "updated password for #{a[:email]}"
  else
    user = User.create!(name: a[:name])
    user.pseudonyms.create!(
      unique_id: a[:email],
      password: password,
      password_confirmation: password,
      account: account
    )
    cc = user.communication_channels.create!(path: a[:email], path_type: "email")
    cc.confirm
    puts "created #{a[:email]}"
  end

  unless account.account_users.active.where(user_id: user.id, role_id: Role.get_built_in_role("AccountAdmin", root_account_id: account.id).id).exists?
    account.account_users.create!(user: user, role: Role.get_built_in_role("AccountAdmin", root_account_id: account.id))
    puts "  - granted AccountAdmin to #{a[:email]}"
  else
    puts "  - already AccountAdmin: #{a[:email]}"
  end
end

puts "done."
