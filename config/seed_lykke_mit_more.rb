account = Account.default
term    = account.default_enrollment_term

teachers = {
  "admin"  => Pseudonym.active.by_unique_id("admin@getlykke.com").first.user,
  "ashish" => Pseudonym.active.by_unique_id("ashish@getlykke.com").first.user,
  "pranav" => Pseudonym.active.by_unique_id("pranav@getlykke.com").first.user,
}
student = Pseudonym.active.by_unique_id("student@getlykke.com").first.user

def find_or_create_course(account, term, code, name, syllabus)
  c = account.courses.find_by(course_code: code)
  if c
    c.update!(syllabus_body: syllabus) if c.syllabus_body != syllabus
    c
  else
    account.courses.create!(
      name: name, course_code: code, enrollment_term: term,
      workflow_state: "available", is_public: false,
      syllabus_body: syllabus, restrict_enrollments_to_course_dates: false
    )
  end
end

def enroll(course, user, type)
  return if course.enrollments.where(user_id: user.id, type: type).active.exists?
  course.enroll_user(user, type, enrollment_state: "active")
end

def upsert_assignment(course, title, opts)
  a = course.assignments.find_by(title: title) || course.assignments.create!(title: title, workflow_state: "published")
  a.update!(opts.merge(workflow_state: "published"))
  a
end

def upsert_quiz(course, title, due_at, points)
  q = course.quizzes.find_by(title: title) || course.quizzes.create!(title: title, quiz_type: "assignment")
  q.update!(description: "Quiz: #{title}", quiz_type: "assignment", time_limit: 30,
            allowed_attempts: 1, due_at: due_at, points_possible: points,
            published_at: Time.now, workflow_state: "available")
  q
end

def upsert_page(course, title, body)
  p = course.wiki_pages.find_by(title: title)
  if p then p.update!(body: body, workflow_state: "active"); p
  else course.wiki_pages.create!(title: title, body: body, workflow_state: "active"); end
end

def upsert_module(course, name, position)
  m = course.context_modules.find_by(name: name) ||
      course.context_modules.create!(name: name, position: position, workflow_state: "active")
  m.update!(position: position); m
end

def add_item(mod, type, id, title)
  return if mod.content_tags.active.exists?(content_type: type.camelize, content_id: id)
  mod.add_item(type: type, id: id, title: title)
end

def upsert_discussion(course, title, message, user)
  d = course.discussion_topics.find_by(title: title)
  if d then d.update!(message: message, workflow_state: "active"); d
  else course.discussion_topics.create!(title: title, message: message, user: user, workflow_state: "active"); end
end

def build_course(account, term, code, name, syllabus, teacher, student, units, quiz_specs=[], extensions=["pdf"])
  course = find_or_create_course(account, term, code, name, syllabus)
  enroll(course, teacher, "TeacherEnrollment")
  enroll(course, student, "StudentEnrollment")

  units.each_with_index do |u, i|
    page = upsert_page(course, u[:page_title], u[:page_body])
    asgn = upsert_assignment(course, u[:asgn_title],
      description: u[:asgn_desc],
      points_possible: u[:points] || 100,
      submission_types: "online_text_entry,online_upload",
      allowed_extensions: extensions,
      due_at: u[:due_days].days.from_now,
      unlock_at: [u[:due_days] - 14, 0].max.days.from_now)
    mod = upsert_module(course, u[:module_name], i + 1)
    add_item(mod, "wiki_page", page.id, page.title)
    add_item(mod, "assignment", asgn.id, asgn.title)
  end

  unless quiz_specs.empty?
    qmod = upsert_module(course, "Assessments", 98)
    quiz_specs.each do |qs|
      q = upsert_quiz(course, qs[:title], qs[:due_days].days.from_now, qs[:points] || 20)
      add_item(qmod, "quiz", q.id, q.title)
    end
  end

  upsert_discussion(course, "Questions and Discussion",
    "Use this space for questions about lectures, problem sets, and general course topics.", teacher)

  puts "created: #{code} - #{name} (id=#{course.id})"
  course
end

############################################################
# 18.06 Linear Algebra
############################################################
build_course(account, term, "18.06", "Linear Algebra",
  "<h2>18.06 Linear Algebra</h2><p><em>Adapted from MIT OCW 18.06 (Prof. Gilbert Strang).</em></p>
   <p>Basic subject on matrix theory and linear algebra, emphasizing topics useful in other
   disciplines: systems of equations, vector spaces, determinants, eigenvalues, similarity,
   and positive definite matrices. Applications include differential equations, least squares
   approximations, and Markov processes.</p>
   <h3>Grading</h3><ul><li>Problem Sets (10): 30%</li><li>Quizzes (3): 45%</li><li>Final Exam: 25%</li></ul>
   <p><strong>Text:</strong> Strang, <em>Introduction to Linear Algebra</em>, 5th ed.</p>",
  teachers["admin"], student,
  [
    { module_name: "Unit 1: Ax = b and the Four Subspaces",
      page_title: "Unit 1 - Solving Linear Equations",
      page_body: "<h2>Unit 1</h2><p><strong>Readings:</strong> Strang Ch. 1-3</p>
                  <ul><li>The geometry of linear equations</li><li>Elimination with matrices</li>
                  <li>Matrix multiplication and inverses</li><li>LU decomposition</li>
                  <li>The four fundamental subspaces</li></ul>",
      asgn_title: "Problem Set 1 - Gaussian Elimination and LU",
      asgn_desc: "Solve Ax=b for 4x4 systems using row reduction. Compute LU factorizations by hand and verify with code.",
      due_days: 7 },
    { module_name: "Unit 2: Least Squares, Determinants, Eigenvalues",
      page_title: "Unit 2 - Orthogonality and Determinants",
      page_body: "<h2>Unit 2</h2><p><strong>Readings:</strong> Strang Ch. 4-6</p>
                  <ul><li>Orthogonal vectors and subspaces</li><li>Projections and least squares</li>
                  <li>Gram-Schmidt and QR</li><li>Determinants and cofactors</li></ul>",
      asgn_title: "Problem Set 2 - Projections and Least Squares",
      asgn_desc: "Fit a line to 10 data points using least squares. Derive the normal equations and compute via QR.",
      due_days: 21 },
    { module_name: "Unit 3: Eigenvalues and Symmetric Matrices",
      page_title: "Unit 3 - Eigenvalues",
      page_body: "<h2>Unit 3</h2><p><strong>Readings:</strong> Strang Ch. 6</p>
                  <ul><li>Eigenvalues and eigenvectors</li><li>Diagonalization</li>
                  <li>Differential equations and e^At</li><li>Symmetric and positive definite matrices</li></ul>",
      asgn_title: "Problem Set 3 - Eigendecomposition",
      asgn_desc: "Diagonalize 3x3 matrices. Solve x' = Ax using eigendecomposition. Identify positive definite examples.",
      due_days: 42 },
    { module_name: "Unit 4: SVD and Applications",
      page_title: "Unit 4 - Singular Value Decomposition",
      page_body: "<h2>Unit 4</h2><p><strong>Readings:</strong> Strang Ch. 7</p>
                  <ul><li>Singular Value Decomposition</li><li>Principal Component Analysis</li>
                  <li>Applications: image compression, recommender systems</li></ul>",
      asgn_title: "Problem Set 4 - SVD Applications",
      asgn_desc: "Compute the SVD of a 5x3 matrix. Implement PCA on a small dataset. Demonstrate image compression via truncated SVD.",
      due_days: 63 },
  ],
  [
    { title: "Quiz 1 - Elimination and Subspaces", due_days: 14, points: 100 },
    { title: "Quiz 2 - Orthogonality and Determinants", due_days: 35, points: 100 },
    { title: "Quiz 3 - Eigenvalues and SVD", due_days: 70, points: 100 },
  ])

############################################################
# 6.0001 Introduction to CS and Programming in Python
############################################################
build_course(account, term, "6.0001", "Introduction to Computer Science and Programming in Python",
  "<h2>6.0001 Introduction to Computer Science and Programming in Python</h2>
   <p><em>Adapted from MIT OCW 6.0001.</em></p>
   <p>Intended for students with little or no programming experience. It aims to provide students
   with an understanding of the role computation can play in solving problems and to help
   students, regardless of their major, feel justifiably confident of their ability to write
   small programs that allow them to accomplish useful goals.</p>
   <h3>Grading</h3><ul><li>6 Problem Sets: 60%</li><li>Final Project: 30%</li><li>Participation: 10%</li></ul>",
  teachers["ashish"], student,
  [
    { module_name: "Lecture 1-3: Python Basics",
      page_title: "Python Basics",
      page_body: "<h2>Python Basics</h2><ul><li>Variables, types, operators</li>
                  <li>Strings, branching, iteration</li><li>Guess-and-check, bisection</li></ul>",
      asgn_title: "Problem Set 1 - Python Warmup",
      asgn_desc: "Hangman, paying off credit card debt with bisection search, and string manipulation exercises.",
      due_days: 10 },
    { module_name: "Lecture 4-6: Functions and Decomposition",
      page_title: "Functions, Decomposition, and Abstraction",
      page_body: "<h2>Functions</h2><ul><li>Decomposition and abstraction</li>
                  <li>Recursion</li><li>Dictionaries, tuples</li></ul>",
      asgn_title: "Problem Set 2 - Word Game",
      asgn_desc: "Implement a hangman-style word game using dictionaries and file I/O.",
      due_days: 24 },
    { module_name: "Lecture 7-9: OOP and Algorithmic Complexity",
      page_title: "Classes and Big-O",
      page_body: "<h2>OOP</h2><ul><li>Classes and inheritance</li>
                  <li>Computational complexity (Big-O)</li><li>Searching and sorting</li></ul>",
      asgn_title: "Problem Set 3 - Simulating Robots",
      asgn_desc: "Object-oriented simulation of a room-cleaning Roomba. Compare different robot strategies empirically.",
      due_days: 45 },
  ],
  [
    { title: "Quiz 1 - Python Fundamentals", due_days: 17, points: 50 },
    { title: "Quiz 2 - Functions and OOP", due_days: 49, points: 50 },
  ],
  ["py","ipynb","pdf","zip"])

############################################################
# 6.034 Artificial Intelligence
############################################################
build_course(account, term, "6.034", "Artificial Intelligence",
  "<h2>6.034 Artificial Intelligence</h2><p><em>Adapted from MIT OCW 6.034 (Prof. Patrick Winston).</em></p>
   <p>Introduction to representations, techniques, and architectures used to build applied systems
   and to account for intelligence from a computational point of view.</p>
   <h3>Topics</h3><ul><li>Rule-based expert systems</li><li>Search, games, constraints</li>
   <li>Learning, neural nets, genetic algorithms</li><li>Natural language understanding</li></ul>
   <h3>Grading</h3><ul><li>Problem Sets (6): 30%</li><li>Quizzes (2): 30%</li><li>Final Exam: 30%</li><li>Participation: 10%</li></ul>",
  teachers["pranav"], student,
  [
    { module_name: "Search and Constraints",
      page_title: "Search Algorithms",
      page_body: "<h2>Search</h2><ul><li>Uninformed search: BFS, DFS, uniform cost</li>
                  <li>Heuristic search: A*, admissibility, consistency</li>
                  <li>Adversarial search: minimax, alpha-beta pruning</li>
                  <li>Constraint propagation</li></ul>",
      asgn_title: "Problem Set 1 - Search",
      asgn_desc: "Implement A* on a pathfinding problem with a custom heuristic. Analyze admissibility.",
      due_days: 14 },
    { module_name: "Learning",
      page_title: "Machine Learning Basics",
      page_body: "<h2>Learning</h2><ul><li>Identification trees and decision trees</li>
                  <li>Nearest neighbors</li><li>Neural networks, backpropagation</li>
                  <li>Support vector machines and boosting</li></ul>",
      asgn_title: "Problem Set 2 - Classifiers",
      asgn_desc: "Build and compare a k-NN, decision tree, and small neural net on a provided dataset.",
      due_days: 35 },
    { module_name: "Representation",
      page_title: "Knowledge Representation",
      page_body: "<h2>Representation</h2><ul><li>Semantic nets, frames</li>
                  <li>Propagation and goal trees</li><li>Genetic algorithms</li></ul>",
      asgn_title: "Problem Set 3 - Expert System",
      asgn_desc: "Build a forward-chaining rule-based expert system for diagnosing a small domain.",
      due_days: 56 },
  ],
  [
    { title: "Quiz 1 - Search and Games", due_days: 21, points: 100 },
    { title: "Quiz 2 - Learning and Representation", due_days: 63, points: 100 },
  ],
  ["py","ipynb","pdf","zip"])

############################################################
# 14.01 Principles of Microeconomics
############################################################
build_course(account, term, "14.01", "Principles of Microeconomics",
  "<h2>14.01 Principles of Microeconomics</h2><p><em>Adapted from MIT OCW 14.01.</em></p>
   <p>Introduces microeconomic concepts and analysis, supply and demand, market equilibrium,
   consumer theory, production and firm theory, market structure, and welfare economics.</p>
   <h3>Grading</h3><ul><li>Problem Sets (8): 20%</li><li>2 Midterms: 50%</li><li>Final: 30%</li></ul>",
  teachers["admin"], student,
  [
    { module_name: "Supply and Demand",
      page_title: "Supply, Demand, and Market Equilibrium",
      page_body: "<h2>Supply and Demand</h2><p>Readings: Perloff Ch. 2-3</p>
                  <ul><li>Demand and supply curves</li><li>Elasticity</li>
                  <li>Consumer and producer surplus</li></ul>",
      asgn_title: "Problem Set 1 - Supply and Demand",
      asgn_desc: "Analyze a market with given demand and supply functions. Compute elasticity and welfare effects of a tax.",
      due_days: 10 },
    { module_name: "Consumer Theory",
      page_title: "Preferences and Utility",
      page_body: "<h2>Consumer Theory</h2><p>Readings: Perloff Ch. 4-5</p>
                  <ul><li>Preferences and utility</li><li>Budget constraints</li>
                  <li>Consumer optimization</li></ul>",
      asgn_title: "Problem Set 2 - Utility Maximization",
      asgn_desc: "Solve Cobb-Douglas and CES utility maximization problems. Derive demand functions.",
      due_days: 28 },
    { module_name: "Producer Theory and Competition",
      page_title: "Production, Cost, and Competition",
      page_body: "<h2>Producer Theory</h2><p>Readings: Perloff Ch. 6-8</p>
                  <ul><li>Production functions and returns to scale</li><li>Cost minimization</li>
                  <li>Perfect competition, monopoly, oligopoly</li></ul>",
      asgn_title: "Problem Set 3 - Firm Behavior",
      asgn_desc: "Short-run and long-run cost problems. Analyze a monopolist's pricing and compare to competitive equilibrium.",
      due_days: 49 },
  ],
  [
    { title: "Midterm 1", due_days: 35, points: 100 },
    { title: "Midterm 2", due_days: 70, points: 100 },
  ])

############################################################
# 6.042J Mathematics for Computer Science
############################################################
build_course(account, term, "6.042J", "Mathematics for Computer Science",
  "<h2>6.042J Mathematics for Computer Science</h2><p><em>Adapted from MIT OCW 6.042J.</em></p>
   <p>Elementary discrete mathematics oriented toward computer science and engineering: logic,
   proofs, number theory, combinatorics, graph theory, probability, and recurrences.</p>",
  teachers["pranav"], student,
  [
    { module_name: "Proofs and Logic",
      page_title: "Proof Techniques",
      page_body: "<h2>Proofs</h2><ul><li>Propositional and predicate logic</li>
                  <li>Direct proof, contradiction, contrapositive</li><li>Induction and strong induction</li></ul>",
      asgn_title: "Problem Set 1 - Induction",
      asgn_desc: "Prove 5 statements using induction. Identify the induction hypothesis and inductive step clearly.",
      due_days: 12 },
    { module_name: "Number Theory and Counting",
      page_title: "Number Theory and Combinatorics",
      page_body: "<h2>Number Theory</h2><ul><li>GCD, Bezout, modular arithmetic</li>
                  <li>RSA sketch</li><li>Counting: permutations, combinations, pigeonhole</li></ul>",
      asgn_title: "Problem Set 2 - Counting and Number Theory",
      asgn_desc: "Extended Euclidean algorithm problems. Counting arguments and pigeonhole applications.",
      due_days: 30 },
    { module_name: "Probability",
      page_title: "Discrete Probability",
      page_body: "<h2>Probability</h2><ul><li>Events, conditional probability, independence</li>
                  <li>Random variables and expectation</li><li>Variance, Chebyshev, Chernoff</li></ul>",
      asgn_title: "Problem Set 3 - Probability",
      asgn_desc: "Compute expectations and variances. Analyze a randomized algorithm with Chernoff bounds.",
      due_days: 51 },
  ],
  [{ title: "Midterm - Proofs, Counting, Probability", due_days: 38, points: 100 }])

############################################################
# 8.01 Physics I: Classical Mechanics
############################################################
build_course(account, term, "8.01", "Physics I: Classical Mechanics",
  "<h2>8.01 Physics I: Classical Mechanics</h2><p><em>Adapted from MIT OCW 8.01.</em></p>
   <p>Fundamental concepts in mechanics: kinematics, Newton's laws, energy, momentum, rotational
   motion, oscillations, and gravitation.</p>",
  teachers["ashish"], student,
  [
    { module_name: "Kinematics and Newton's Laws",
      page_title: "Kinematics and Newton",
      page_body: "<h2>Kinematics</h2><ul><li>1D and 2D motion</li>
                  <li>Newton's three laws</li><li>Applications: friction, tension, circular motion</li></ul>",
      asgn_title: "Problem Set 1 - Kinematics",
      asgn_desc: "Projectile motion and Newton's laws problems. Include free-body diagrams.",
      due_days: 9 },
    { module_name: "Energy and Momentum",
      page_title: "Work, Energy, Momentum",
      page_body: "<h2>Energy</h2><ul><li>Work-energy theorem</li><li>Conservation of energy</li>
                  <li>Linear momentum and collisions</li></ul>",
      asgn_title: "Problem Set 2 - Energy and Momentum",
      asgn_desc: "Elastic and inelastic collisions. Energy conservation with multiple forces.",
      due_days: 25 },
    { module_name: "Rotation and Oscillations",
      page_title: "Rotational Dynamics and SHM",
      page_body: "<h2>Rotation</h2><ul><li>Torque and angular momentum</li>
                  <li>Moments of inertia</li><li>Simple harmonic motion and pendulums</li></ul>",
      asgn_title: "Problem Set 3 - Rotation",
      asgn_desc: "Rotational dynamics problems and SHM. Derive the period of a physical pendulum.",
      due_days: 47 },
  ],
  [
    { title: "Midterm - Mechanics", due_days: 32, points: 100 },
    { title: "Final - Full Course", due_days: 75, points: 150 },
  ])

puts "done."
