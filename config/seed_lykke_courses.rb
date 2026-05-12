account = Account.default
password = "lykke@123"

def ensure_user(name, email, password, account)
  pseud = Pseudonym.active.by_unique_id(email).first
  if pseud
    pseud.password = password
    pseud.password_confirmation = password
    pseud.save!
    pseud.user
  else
    u = User.create!(name: name)
    u.pseudonyms.create!(
      unique_id: email,
      password: password,
      password_confirmation: password,
      account: account
    )
    cc = u.communication_channels.create!(path: email, path_type: "email")
    cc.confirm
    u
  end
end

student = ensure_user("Test Student", "student@getlykke.com", password, account)
puts "student: #{student.id} #{student.name}"

teachers = {
  "admin@getlykke.com" => Pseudonym.active.by_unique_id("admin@getlykke.com").first.user,
  "ashish@getlykke.com" => Pseudonym.active.by_unique_id("ashish@getlykke.com").first.user,
  "pranav@getlykke.com" => Pseudonym.active.by_unique_id("pranav@getlykke.com").first.user,
}

term = account.default_enrollment_term

course_specs = [
  { code: "MATH101", name: "Introduction to Mathematics",  teacher: "ashish@getlykke.com" },
  { code: "ENG101",  name: "English Composition",          teacher: "pranav@getlykke.com" },
  { code: "SCI101",  name: "General Science",              teacher: "admin@getlykke.com"  },
  { code: "HIST101", name: "World History",                teacher: "ashish@getlykke.com" },
]

course_specs.each do |spec|
  course = account.courses.find_by(course_code: spec[:code]) ||
           account.courses.create!(
             name: spec[:name],
             course_code: spec[:code],
             enrollment_term: term,
             workflow_state: "available",
             is_public: false,
             restrict_enrollments_to_course_dates: false
           )

  course.update!(workflow_state: "available") unless course.available?
  course.offer! unless course.available?

  teacher = teachers[spec[:teacher]]
  unless course.enrollments.where(user_id: teacher.id, type: "TeacherEnrollment").active.exists?
    course.enroll_user(teacher, "TeacherEnrollment", enrollment_state: "active")
    puts "  + teacher #{spec[:teacher]} -> #{spec[:code]}"
  end

  unless course.enrollments.where(user_id: student.id, type: "StudentEnrollment").active.exists?
    course.enroll_user(student, "StudentEnrollment", enrollment_state: "active")
    puts "  + student -> #{spec[:code]}"
  end

  unless course.assignments.where(title: "Welcome Quiz").exists?
    course.assignments.create!(
      title: "Welcome Quiz",
      description: "Introductory assignment for #{spec[:name]}",
      points_possible: 10,
      workflow_state: "published",
      submission_types: "online_text_entry",
      due_at: 7.days.from_now
    )
  end

  unless course.assignments.where(title: "Week 1 Reading Response").exists?
    course.assignments.create!(
      title: "Week 1 Reading Response",
      description: "Write a short reflection on week 1 material.",
      points_possible: 20,
      workflow_state: "published",
      submission_types: "online_text_entry",
      due_at: 14.days.from_now
    )
  end

  unless course.context_modules.where(name: "Week 1").exists?
    mod = course.context_modules.create!(name: "Week 1", workflow_state: "active", position: 1)
    mod.add_item(type: "assignment", id: course.assignments.find_by(title: "Welcome Quiz").id)
    mod.save!
  end

  unless course.discussion_topics.where(title: "Introduce Yourself").exists?
    course.discussion_topics.create!(
      title: "Introduce Yourself",
      message: "Please introduce yourself to the class.",
      user: teacher,
      workflow_state: "active"
    )
  end

  puts "course: #{spec[:code]} - #{spec[:name]} (id=#{course.id})"
end

puts "done."
