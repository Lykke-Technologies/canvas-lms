account = Account.default
term    = account.default_enrollment_term
pranav  = Pseudonym.active.by_unique_id("pranav@getlykke.com").first.user
student = Pseudonym.active.by_unique_id("student@getlykke.com").first.user

PDF_DIR = "/usr/src/app/seed-pdfs"

syllabus = <<~HTML
  <h2>6.046J / 18.410J Design and Analysis of Algorithms</h2>
  <p><em>Adapted from MIT OpenCourseWare 6.046J.</em></p>
  <p>Techniques for the design and analysis of efficient algorithms, emphasizing methods useful in
  practice. Topics include sorting; search trees, heaps, and hashing; divide-and-conquer; dynamic
  programming; greedy algorithms; amortized analysis; graph algorithms; and shortest paths.
  <strong>Prerequisite:</strong> 6.006 Introduction to Algorithms.</p>
  <h3>Grading</h3>
  <ul>
    <li>Problem Sets (8): 40%</li>
    <li>In-class Quizzes (2): 30%</li>
    <li>Final Exam: 25%</li>
    <li>Recitation participation: 5%</li>
  </ul>
  <p>See the attached <strong>Syllabus.pdf</strong> in the Course Files for full details.</p>
HTML

course = account.courses.find_by(course_code: "6.046J") ||
         account.courses.create!(
           name: "Design and Analysis of Algorithms",
           course_code: "6.046J",
           enrollment_term: term,
           workflow_state: "available",
           is_public: false,
           restrict_enrollments_to_course_dates: false
         )
course.update!(syllabus_body: syllabus, workflow_state: "available")

[[pranav, "TeacherEnrollment"], [student, "StudentEnrollment"]].each do |user, type|
  next if course.enrollments.where(user_id: user.id, type: type).active.exists?
  course.enroll_user(user, type, enrollment_state: "active")
end

root_folder = Folder.root_folders(course).first

materials_folder = course.folders.active.find_by(name: "Course Materials") ||
                   course.folders.create!(name: "Course Materials", parent_folder: root_folder,
                                          workflow_state: "visible", context: course)

psets_folder = course.folders.active.find_by(name: "Problem Sets") ||
               course.folders.create!(name: "Problem Sets", parent_folder: root_folder,
                                      workflow_state: "visible", context: course)

def upload_pdf(course, folder, filename, display_name)
  attachment = course.attachments.active.find_by(filename: filename)
  path = File.join(PDF_DIR, filename)
  unless File.exist?(path)
    puts "  !! missing: #{path}"
    return nil
  end

  if attachment
    puts "  = exists: #{display_name}"
    return attachment
  end

  attachment = course.attachments.build(
    folder: folder,
    display_name: display_name,
    filename: filename,
    content_type: "application/pdf",
    context: course
  )
  File.open(path, "rb") { |f| attachment.uploaded_data = f }
  attachment.save!
  puts "  + uploaded: #{display_name} (id=#{attachment.id})"
  attachment
end

uploads = {
  syllabus:     upload_pdf(course, materials_folder, "Syllabus.pdf", "6.046J Syllabus"),
  lecture01:    upload_pdf(course, materials_folder, "Lecture-01-Divide-and-Conquer.pdf", "Lecture 1 - Divide-and-Conquer"),
  lecture02:    upload_pdf(course, materials_folder, "Lecture-02-Randomized-Algorithms.pdf", "Lecture 2 - Randomized Algorithms"),
  pset01:       upload_pdf(course, psets_folder,     "Problem-Set-01.pdf", "Problem Set 1"),
  pset02:       upload_pdf(course, psets_folder,     "Problem-Set-02.pdf", "Problem Set 2"),
  pset03:       upload_pdf(course, psets_folder,     "Problem-Set-03.pdf", "Problem Set 3"),
}

def file_link(course, att, text)
  %(<p><a class="instructure_file_link instructure_scribd_file" ) +
    %(href="/courses/#{course.id}/files/#{att.id}/download?download_frd=1" ) +
    %(data-api-endpoint="/api/v1/courses/#{course.id}/files/#{att.id}" ) +
    %(data-api-returntype="File">#{text}</a></p>)
end

def upsert_assignment(course, teacher, title, desc, points, due_days)
  a = course.assignments.find_by(title: title) || course.assignments.create!(title: title, workflow_state: "published")
  a.updating_user = teacher
  a.description = desc
  a.points_possible = points
  a.submission_types = "online_text_entry,online_upload"
  a.allowed_extensions = ["pdf", "zip", "py"]
  a.workflow_state = "published"
  a.due_at = due_days.days.from_now
  a.unlock_at = [due_days - 14, 0].max.days.from_now
  a.save!
  a
end

def upsert_module(course, name, position)
  m = course.context_modules.find_by(name: name) ||
      course.context_modules.create!(name: name, position: position, workflow_state: "active")
  m.update!(position: position)
  m
end

def add_item(mod, type, id, title)
  return if mod.content_tags.active.exists?(content_type: type.camelize, content_id: id)
  mod.add_item(type: type, id: id, title: title)
end

# Assignments with PDF instructions embedded
pset1_asgn = upsert_assignment(course, pranav, "Problem Set 1 - Divide-and-Conquer",
  "<p>Master method practice, counting inversions, closest pair, and matrix exponentiation. " \
  "Full instructions are in the attached PDF.</p>" + file_link(course, uploads[:pset01], "Download Problem Set 1 (PDF)"),
  100, 14)

pset2_asgn = upsert_assignment(course, pranav, "Problem Set 2 - Randomization and DP",
  "<p>Randomized quickselect, longest palindromic subsequence, optimal BST, Karger's min-cut.</p>" +
  file_link(course, uploads[:pset02], "Download Problem Set 2 (PDF)"),
  100, 35)

pset3_asgn = upsert_assignment(course, pranav, "Problem Set 3 - Greedy and Graph Algorithms",
  "<p>Interval scheduling, MST uniqueness, widest path, bipartite matching via max flow.</p>" +
  file_link(course, uploads[:pset03], "Download Problem Set 3 (PDF)"),
  100, 56)

# Modules
m_info = upsert_module(course, "Course Information", 1)
add_item(m_info, "attachment", uploads[:syllabus].id, "6.046J Syllabus (PDF)")

m_lec = upsert_module(course, "Lectures", 2)
add_item(m_lec, "attachment", uploads[:lecture01].id, "Lecture 1 - Divide-and-Conquer")
add_item(m_lec, "attachment", uploads[:lecture02].id, "Lecture 2 - Randomized Algorithms")

m_psets = upsert_module(course, "Problem Sets", 3)
add_item(m_psets, "attachment", uploads[:pset01].id, "Problem Set 1 (PDF)")
add_item(m_psets, "assignment", pset1_asgn.id, pset1_asgn.title)
add_item(m_psets, "attachment", uploads[:pset02].id, "Problem Set 2 (PDF)")
add_item(m_psets, "assignment", pset2_asgn.id, pset2_asgn.title)
add_item(m_psets, "attachment", uploads[:pset03].id, "Problem Set 3 (PDF)")
add_item(m_psets, "assignment", pset3_asgn.id, pset3_asgn.title)

# Discussion
unless course.discussion_topics.where(title: "Problem Set Clarifications").exists?
  course.discussion_topics.create!(
    title: "Problem Set Clarifications",
    message: "Ask clarifying questions about the problem sets here. Please don't post solutions.",
    user: pranav,
    workflow_state: "active"
  )
end

puts "done. course_id=#{course.id}, url=https://canvas.getlykke.com/courses/#{course.id}"
