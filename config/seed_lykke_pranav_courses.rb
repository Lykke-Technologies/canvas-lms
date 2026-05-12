account = Account.default
term = account.default_enrollment_term

pranav  = Pseudonym.active.by_unique_id("pranav@getlykke.com").first.user
student = Pseudonym.active.by_unique_id("student@getlykke.com").first.user

def find_or_create_course(account, term, code, name, syllabus_body)
  course = account.courses.find_by(course_code: code)
  if course
    course.update!(syllabus_body: syllabus_body) if course.syllabus_body != syllabus_body
    course
  else
    account.courses.create!(
      name: name,
      course_code: code,
      enrollment_term: term,
      workflow_state: "available",
      is_public: false,
      syllabus_body: syllabus_body,
      restrict_enrollments_to_course_dates: false
    )
  end
end

def enroll(course, user, type)
  return if course.enrollments.where(user_id: user.id, type: type).active.exists?
  course.enroll_user(user, type, enrollment_state: "active")
end

def upsert_assignment(course, title, opts)
  a = course.assignments.find_by(title: title) ||
      course.assignments.create!(title: title, workflow_state: "published")
  a.update!(opts.merge(workflow_state: "published"))
  a
end

def upsert_quiz(course, title, due_at)
  q = course.quizzes.find_by(title: title) ||
      course.quizzes.create!(title: title, quiz_type: "assignment")
  q.update!(
    description: "Quiz: #{title}",
    quiz_type: "assignment",
    time_limit: 30,
    allowed_attempts: 1,
    due_at: due_at,
    points_possible: 20,
    published_at: Time.now,
    workflow_state: "available"
  )
  q.save!
  q
end

def upsert_page(course, title, body)
  page = course.wiki_pages.find_by(title: title)
  if page
    page.update!(body: body, workflow_state: "active")
  else
    page = course.wiki_pages.create!(title: title, body: body, workflow_state: "active")
  end
  page
end

def upsert_module(course, name, position)
  m = course.context_modules.find_by(name: name) ||
      course.context_modules.create!(name: name, position: position, workflow_state: "active")
  m.update!(position: position)
  m
end

def add_module_item(mod, type, content_id, title)
  return if mod.content_tags.active.exists?(content_type: type.camelize, content_id: content_id)
  mod.add_item(type: type, id: content_id, title: title)
end

def upsert_discussion(course, title, message, user)
  d = course.discussion_topics.find_by(title: title)
  if d
    d.update!(message: message, workflow_state: "active")
  else
    d = course.discussion_topics.create!(title: title, message: message, user: user, workflow_state: "active")
  end
  d
end

############################################################
# Course 1: 6.006 Introduction to Algorithms (comprehensive)
############################################################

syllabus_6006 = <<~HTML
  <h2>6.006 Introduction to Algorithms</h2>
  <p><em>Adapted from MIT OpenCourseWare 6.006 - Introduction to Algorithms.</em></p>

  <h3>Course Description</h3>
  <p>This course provides an introduction to mathematical modeling of computational problems.
  It covers the common algorithms, algorithmic paradigms, and data structures used to solve these problems.
  The course emphasizes the relationship between algorithms and programming and introduces basic performance
  measures and analysis techniques for these problems.</p>

  <h3>Topics</h3>
  <ul>
    <li>Asymptotic analysis and recurrences</li>
    <li>Sorting and order statistics</li>
    <li>Hashing and amortized analysis</li>
    <li>Search trees and balanced search trees</li>
    <li>Graph algorithms (BFS, DFS, shortest paths)</li>
    <li>Dynamic programming</li>
    <li>Numerical algorithms</li>
  </ul>

  <h3>Grading</h3>
  <ul>
    <li>Problem Sets (5): 40%</li>
    <li>Quizzes (2): 30%</li>
    <li>Final Project: 25%</li>
    <li>Participation: 5%</li>
  </ul>

  <h3>Textbook</h3>
  <p><em>Introduction to Algorithms</em> (CLRS), 3rd Edition, by Cormen, Leiserson, Rivest, and Stein.</p>
HTML

course = find_or_create_course(account, term, "6.006", "Introduction to Algorithms", syllabus_6006)
enroll(course, pranav, "TeacherEnrollment")
enroll(course, student, "StudentEnrollment")

units = [
  {
    num: 1,
    name: "Unit 1: Algorithmic Thinking",
    page_title: "Unit 1 - Algorithmic Thinking",
    page_body: <<~HTML,
      <h2>Unit 1: Algorithmic Thinking</h2>
      <p><strong>Readings:</strong> CLRS Chapters 1-4</p>
      <h3>Lecture Topics</h3>
      <ul>
        <li>Lecture 1: Algorithmic Thinking, Peak Finding</li>
        <li>Lecture 2: Models of Computation, Document Distance</li>
        <li>Lecture 3: Insertion Sort, Merge Sort</li>
        <li>Lecture 4: Heaps and Heap Sort</li>
      </ul>
      <h3>Key Concepts</h3>
      <p>Big-O notation, recurrences, Master Theorem, divide and conquer.</p>
    HTML
    pset_title: "Problem Set 1 - Asymptotic Analysis & Sorting",
    pset_desc: "Solve peak-finding on 1D and 2D arrays. Analyze complexity. Implement merge sort and compare runtime to insertion sort.",
    due_days: 7
  },
  {
    num: 2,
    name: "Unit 2: Sorting and Trees",
    page_title: "Unit 2 - Sorting and Trees",
    page_body: <<~HTML,
      <h2>Unit 2: Sorting and Trees</h2>
      <p><strong>Readings:</strong> CLRS Chapters 6-8, 12-13</p>
      <h3>Lecture Topics</h3>
      <ul>
        <li>Lecture 5: Binary Search Trees, BST Sort</li>
        <li>Lecture 6: AVL Trees, AVL Sort</li>
        <li>Lecture 7: Counting Sort, Radix Sort</li>
      </ul>
    HTML
    pset_title: "Problem Set 2 - BSTs and Linear-Time Sorting",
    pset_desc: "Implement an AVL tree with range queries. Prove lower bound for comparison-based sorting. Analyze radix sort.",
    due_days: 21
  },
  {
    num: 3,
    name: "Unit 3: Hashing",
    page_title: "Unit 3 - Hashing",
    page_body: <<~HTML,
      <h2>Unit 3: Hashing</h2>
      <p><strong>Readings:</strong> CLRS Chapter 11</p>
      <h3>Lecture Topics</h3>
      <ul>
        <li>Lecture 8: Hashing with Chaining</li>
        <li>Lecture 9: Table Doubling, Karp-Rabin</li>
        <li>Lecture 10: Open Addressing, Cryptographic Hashing</li>
      </ul>
    HTML
    pset_title: "Problem Set 3 - Hashing Applications",
    pset_desc: "Design a rolling hash for substring search. Analyze collision probability. Implement and benchmark a hash table with open addressing.",
    due_days: 35
  },
  {
    num: 4,
    name: "Unit 4: Graph Algorithms",
    page_title: "Unit 4 - Graph Algorithms",
    page_body: <<~HTML,
      <h2>Unit 4: Graph Algorithms</h2>
      <p><strong>Readings:</strong> CLRS Chapters 22-25</p>
      <h3>Lecture Topics</h3>
      <ul>
        <li>Lecture 13: Breadth-First Search (BFS)</li>
        <li>Lecture 14: Depth-First Search, Topological Sort</li>
        <li>Lecture 15: Single-Source Shortest Paths, Dijkstra</li>
        <li>Lecture 16: Dijkstra, Speed-ups</li>
        <li>Lecture 17: Bellman-Ford</li>
      </ul>
    HTML
    pset_title: "Problem Set 4 - Shortest Paths",
    pset_desc: "Model a real-world routing problem as a weighted graph. Implement Dijkstra and Bellman-Ford and compare.",
    due_days: 49
  },
  {
    num: 5,
    name: "Unit 5: Dynamic Programming",
    page_title: "Unit 5 - Dynamic Programming",
    page_body: <<~HTML,
      <h2>Unit 5: Dynamic Programming</h2>
      <p><strong>Readings:</strong> CLRS Chapter 15</p>
      <h3>Lecture Topics</h3>
      <ul>
        <li>Lecture 19: Dynamic Programming I - Fibonacci, Shortest Paths</li>
        <li>Lecture 20: DP II - Text Justification, Blackjack</li>
        <li>Lecture 21: DP III - Parenthesization, Edit Distance, Knapsack</li>
        <li>Lecture 22: DP IV - Guitar Fingering, Tetris Training, Super Mario Bros.</li>
      </ul>
    HTML
    pset_title: "Problem Set 5 - Dynamic Programming",
    pset_desc: "Solve 4 DP problems: edit distance, longest common subsequence, knapsack variant, and a custom sequence alignment problem.",
    due_days: 63
  },
]

units.each do |u|
  page = upsert_page(course, u[:page_title], u[:page_body])
  asgn = upsert_assignment(course, u[:pset_title],
    description: u[:pset_desc],
    points_possible: 100,
    submission_types: "online_text_entry,online_upload",
    allowed_extensions: ["pdf","py","ipynb","zip"],
    due_at: u[:due_days].days.from_now,
    unlock_at: [u[:due_days] - 14, 0].max.days.from_now
  )
  mod = upsert_module(course, u[:name], u[:num])
  add_module_item(mod, "wiki_page", page.id, u[:page_title])
  add_module_item(mod, "assignment", asgn.id, u[:pset_title])
end

quiz1 = upsert_quiz(course, "Midterm Quiz 1 - Sorting & Trees", 28.days.from_now)
quiz2 = upsert_quiz(course, "Midterm Quiz 2 - Graphs & DP", 56.days.from_now)
mod_quiz1 = upsert_module(course, "Assessments", 98)
add_module_item(mod_quiz1, "quiz", quiz1.id, quiz1.title)
add_module_item(mod_quiz1, "quiz", quiz2.id, quiz2.title)

final_project = upsert_assignment(course, "Final Project - Algorithm Design and Analysis",
  description: "Propose and solve a real-world problem using techniques from this course. Deliverables: 8-page writeup, implementation, 10-min presentation.",
  points_possible: 250,
  submission_types: "online_text_entry,online_upload",
  allowed_extensions: ["pdf","zip"],
  due_at: 84.days.from_now,
  unlock_at: 42.days.from_now
)
mod_final = upsert_module(course, "Final Project", 99)
add_module_item(mod_final, "assignment", final_project.id, final_project.title)

upsert_discussion(course, "Weekly Reading Discussion",
  "Each week, post one question or insight about the assigned reading. Respond to at least two classmates.",
  pranav)
upsert_discussion(course, "Study Group Finder",
  "Use this thread to find study partners for problem sets.",
  pranav)

puts "created: 6.006 Introduction to Algorithms (id=#{course.id})"

############################################################
# Course 2: 18.01 Single Variable Calculus
############################################################

syllabus_1801 = <<~HTML
  <h2>18.01 Single Variable Calculus</h2>
  <p><em>Adapted from MIT OpenCourseWare 18.01.</em></p>
  <p>Differentiation and integration of functions of one variable, with applications.
  Informal treatment of limits and continuity. Differentiation: definition, rules, application
  to graphing, rates, approximations, and extremum problems. Indefinite integration; separable
  first-order differential equations. Definite integral; fundamental theorem of calculus.</p>

  <h3>Grading</h3>
  <ul><li>Problem Sets: 50%</li><li>Exams (3): 50%</li></ul>
HTML

course2 = find_or_create_course(account, term, "18.01", "Single Variable Calculus", syllabus_1801)
enroll(course2, pranav, "TeacherEnrollment")
enroll(course2, student, "StudentEnrollment")

[
  ["Problem Set 1 - Limits and Derivatives", "Compute limits from first principles. Differentiate polynomial and trigonometric functions.", 10],
  ["Problem Set 2 - Applications of Derivatives", "Optimization, related rates, and curve sketching problems.", 24],
  ["Problem Set 3 - Integration", "Antiderivatives, definite integrals, substitution, and areas under curves.", 38],
].each_with_index do |(t, d, days), i|
  upsert_assignment(course2, t,
    description: d,
    points_possible: 100,
    submission_types: "online_text_entry,online_upload",
    allowed_extensions: ["pdf"],
    due_at: days.days.from_now)
end

upsert_discussion(course2, "Office Hours Q&A",
  "Ask clarifying questions about lecture material here.", pranav)

puts "created: 18.01 Single Variable Calculus (id=#{course2.id})"

############################################################
# Course 3: 6.001 Structure and Interpretation of Computer Programs
############################################################

syllabus_6001 = <<~HTML
  <h2>6.001 Structure and Interpretation of Computer Programs</h2>
  <p><em>Adapted from MIT OpenCourseWare 6.001 (SICP).</em></p>
  <p>A classic introduction to the principles of computation and abstraction. Uses Scheme to
  explore procedural abstraction, data abstraction, modularity, and metalinguistic abstraction.</p>

  <h3>Textbook</h3>
  <p>Abelson, Sussman, and Sussman, <em>Structure and Interpretation of Computer Programs</em>, 2nd ed.</p>
HTML

course3 = find_or_create_course(account, term, "6.001", "Structure and Interpretation of Computer Programs", syllabus_6001)
enroll(course3, pranav, "TeacherEnrollment")
enroll(course3, student, "StudentEnrollment")

[
  ["Problem Set 1 - Building Abstractions with Procedures", "Exercises 1.1-1.46 from SICP. Implement recursive and iterative Fibonacci.", 7],
  ["Problem Set 2 - Higher-Order Procedures", "map, filter, reduce. Implement a symbolic differentiator.", 21],
  ["Problem Set 3 - Building Abstractions with Data", "Pairs, lists, trees. Build a tagged-dispatch arithmetic package.", 35],
  ["Final Project - Metacircular Evaluator", "Implement a Scheme interpreter in Scheme (Chapter 4 of SICP).", 70],
].each do |t, d, days|
  upsert_assignment(course3, t,
    description: d,
    points_possible: 100,
    submission_types: "online_text_entry,online_upload",
    allowed_extensions: ["scm","rkt","pdf","zip"],
    due_at: days.days.from_now)
end

upsert_discussion(course3, "Scheme Setup Help",
  "Post issues getting MIT/GNU Scheme or Racket running locally.", pranav)

puts "created: 6.001 SICP (id=#{course3.id})"

puts "done."
