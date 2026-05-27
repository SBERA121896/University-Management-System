CREATE DATABASE university_database;
USE university_database;

CREATE TABLE department(
	dept_name VARCHAR(100) PRIMARY KEY,
    building VARCHAR(100),
    budget INT
);

CREATE TABLE instructor(
	id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    salary INT,
    dept VARCHAR(100),
    CONSTRAINT ins_user FOREIGN KEY(dept) REFERENCES department(dept_name)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE student(
	st_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    total_cred INT,
    dept VARCHAR(100),
    CONSTRAINT st_user FOREIGN KEY (dept) 
    REFERENCES department(dept_name) ON DELETE RESTRICT ON UPDATE CASCADE
);


CREATE  TABLE course(
	course_id INT PRIMARY KEY,
    title VARCHAR(100),
    dept VARCHAR(100),
    credits INT,
    FOREIGN KEY (dept) REFERENCES department(dept_name)
    ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE prereq(
	course_id INT,
    prereq_id INT,
    PRIMARY KEY(course_id, prereq_id),
    FOREIGN KEY (course_id) REFERENCES course (course_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (prereq_id) REFERENCES course (course_id)
    ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE classroom(
	building VARCHAR(100),
    room_number INT,
    capacity INT,
    PRIMARY KEY (building,room_number)
);


CREATE TABLE time_slot(
	time_slot_id INT PRIMARY KEY,
    day VARCHAR(50),
    start_time TIME,
    end_time TIME
);


CREATE TABLE section(
	sec_id INT,
    semester VARCHAR(10),
    year INT,
    course_id INT,
    building varchar(100),
    room_number INT,
    time_slot_id INT,
    primary key(sec_id,semester,year,course_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (building,room_number) REFERENCES classroom(building,room_number) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (time_slot_id) REFERENCES time_slot(time_slot_id) ON DELETE CASCADE ON UPDATE CASCADE
);
    

CREATE TABLE takes(
	st_id INT,
    course_id INT,
    sec_id INT, 
    semester VARCHAR(10),
    year INT,
    grade CHAR(1),
    PRIMARY KEY(st_id, course_id, sec_id, semester, year),
    FOREIGN KEY (st_id) REFERENCES student(st_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (sec_id,semester,year,course_id) 
    REFERENCES section(sec_id,semester,year,course_id)
    ON DELETE CASCADE ON UPDATE CASCADE
    );

CREATE TABLE teaches(
	ins_id INT,
    course_id INT,
    sec_id INT, 
    semester VARCHAR(10),
    year INT,
    PRIMARY KEY(ins_id, course_id, sec_id, semester, year),
	FOREIGN KEY (sec_id,semester,year,course_id) 
    REFERENCES section(sec_id,semester,year,course_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ins_id) REFERENCES instructor(id) ON DELETE RESTRICT ON UPDATE CASCADE
);


DELIMITER $$
CREATE TRIGGER update_total_credit
AFTER INSERT ON takes
FOR EACH ROW
BEGIN 
	UPDATE student
    SET total_cred = total_cred +
		(SELECT credits FROM course WHERE course_id = NEW.course_id)
	WHERE st_id=NEW.st_id;
END $$
DELIMITER ;

    
DELIMITER $$
CREATE TRIGGER validated_grade
BEFORE INSERT ON takes
FOR EACH ROW
BEGIN
	IF NEW.grade NOT IN ('A','B','C','D','F') THEN 
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT="Invalid Grade";
    END IF;
END $$
DELIMITER ;

#prevent negative salary
DELIMITER $$
CREATE TRIGGER check_salary
BEFORE INSERT ON instructor 
FOR EACH ROW
BEGIN 
	IF NEW.salary <0 THEN 
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT ="Salary can not be negative";
    END IF;
END $$
DELIMITER ;


#prevent classroom conflict
DELIMITER //
CREATE TRIGGER prevent_classroom_conflict
BEFORE INSERT ON section
FOR EACH ROW
BEGIN
	IF EXISTS(
    SELECT * FROM section
    WHERE building=NEW.building
    AND room_number=NEW.room_number
    AND time_slot_id=NEW.time_slot_id
    )
    THEN SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT ="Classroom already booked";
    END IF;
END //
DELIMITER ;


#prevent teacher time conflict
DELIMITER //
CREATE TRIGGER prevent_teacher_time_conflict
BEFORE INSERT ON teaches
FOR EACH ROW
BEGIN
	IF EXISTS( 
    SELECT 1 FROM teaches T
    INNER JOIN section S 
    ON T.course_id=S.course_id
    AND T.sec_id=S.sec_id
    AND T.semester=S.semester
    AND T.year=S.year
    WHERE T.ins_id =NEW.ins_id
    AND S.time_slot_id=(
		SELECT time_slot_id FROM section
        WHERE course_id=NEW.course_id
		AND sec_id=NEW.sec_id
		AND semester=NEW.semester
		AND year=NEW.year)
	)
    THEN SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT="Teacher already teaches in the time slot";
    END IF;
END //
DELIMITER ;


CREATE VIEW student_course_details AS
SELECT S.st_id AS Student_id,
S.name AS Student_name,
C.title AS Course,
T.grade AS Grade
FROM student S 
INNER JOIN takes T ON S.st_id=T.st_id
INNER JOIN course C ON T.course_id=C.course_id;


CREATE VIEW instructor_teaching_view AS
SELECT I.id AS Instructor_id,
I.name AS Instructor_name,
C.title AS course,
T.sec_id AS section,
T.semester AS Semester,
T.year AS Year,
S.time_slot_id AS time_slot
FROM instructor I 
INNER JOIN teaches T ON I.id=T.ins_id
INNER JOIN course C ON T.course_id =C.course_id
INNER JOIN section S 
ON T.course_id=S.course_id
AND T.sec_id =S.sec_id
AND T.semester=S.semester
AND T.year=S.year;


CREATE VIEW student_department_view AS 
SELECT S.st_id AS Student_id,
S.name AS Student_name,
D.dept_name AS Department,
D.building AS Building,
D.budget AS Budget
FROM student S
INNER JOIN department D ON S.dept=D.dept_name;



CREATE VIEW section_details AS
SELECT C.title AS Course,
S.sec_id as Section,
S.semester AS Semester,
S.year As Year,
S.building AS Building,
S.room_number AS Room_number,
S.time_slot_id AS Time_slot
FROM course C 
INNER JOIN section S ON C.course_id =S.course_id;


CREATE VIEW prereq_course_details AS
SELECT C.title AS Course,
C1.title AS Prereq_course
FROM prereq P 
INNER JOIN course C ON P.course_id = C.course_id
INNER JOIN course C1 ON P.prereq_id =C1.course_id; 


DELIMITER //
CREATE PROCEDURE get_student_course(
	IN sid INT)
BEGIN 
	SELECT S.name, C.title, T.grade
    FROM student S
    INNER JOIN takes T ON S.st_id=T.st_id
    INNER JOIN course C ON T.course_id=C.course_id
    WHERE S.st_id=sid;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE get_instructor_schedule (IN Iid INT)
BEGIN
	SELECT I.name AS Instructor_name,
    C.title AS Course,
    T.sec_id AS section,
    T.semester AS Semester,
    T.year AS Year,
    C.dept AS Department,
    S.time_slot_id AS TimE_slot
    FROM instructor I 
    INNER JOIN teaches T ON I.id=T.ins_id
    INNER JOIN course C ON T.course_id=C.course_id
    INNER JOIN section S 
    ON  T.course_id=S.course_id
    AND T.sec_id=S.sec_id
    AND T.semester=S.semester
    AND T.year =S.year
    WHERE I.id=Iid;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE get_student_in_section 
(IN course_id INT,
IN sec_id INT,
IN semester VARCHAR(10),
IN year INT)
BEGIN
SELECT S.name AS Student_name
FROM student S
INNER JOIN takes T 
ON S.st_id=T.st_id
WHERE T.course_id=course_id
AND T.sec_id=sec_id
AND T.semester=semester
AND T.year=year;
END //
DELIMITER ;


DELIMITER //
CREATE PROCEDURE enroll_student(
	IN st_id INT,
    IN course_id INT,
    IN sec_id INT, 
    IN semester VARCHAR(10),
    IN year INT,
    IN grade VARCHAR(1)
)
BEGIN
    INSERT INTO takes(st_id, course_id, sec_id, semester, year, grade)
    values(st_id, course_id, sec_id, semester, year, grade);
END //
DELIMITER ;



INSERT INTO department (dept_name, building, budget) VALUES
('CSE', 'Tech Block A', 5000000),
('ECE', 'Tech Block B', 4000000),
('ME', 'Workshop Block', 3500000),
('CE', 'Civil Block', 3000000),
('EE', 'Electrical Block', 3200000),
('IT', 'Tech Block C', 4500000),
('BBA', 'Management Block', 2500000),
('MBA', 'Management Block', 3000000),
('Physics', 'Science Block', 2000000),
('Chemistry', 'Science Block', 2200000),
('Mathematics', 'Science Block', 1800000);

SELECT * FROM department;


INSERT INTO instructor (name, salary, dept) VALUES
('Dr. Sen', 80000, 'CSE'),
('Mr. Roy', 75000, 'ECE'),
('Dr. Das', 70000, 'ME'),
('Ms. Ghosh', 72000, 'CE'),
('Mr. Paul', 68000, 'EE'),
('Dr. Dutta', 85000, 'IT'),
('Ms. Mitra', 60000, 'BBA'),
('Dr. Banerjee', 90000, 'MBA'),
('Mr. Saha', 65000, 'Physics'),
('Ms. Chakraborty', 67000, 'Mathematics');

SELECT * FROM instructor;


INSERT INTO student (name, total_cred, dept) VALUES
('Amit Sharma', 0, 'CSE'),
('Rahul Verma', 0, 'ECE'),
('Sourav Das', 0, 'ME'),
('Ankit Singh', 0, 'CE'),
('Rohit Gupta', 0, 'EE'),
('Priya Sen', 0, 'IT'),
('Neha Agarwal', 0, 'BBA'),
('Pooja Roy', 0, 'MBA'),
('Arindam Ghosh', 0, 'Physics'),
('Subhajit Paul', 0, 'Mathematics'),

('Kunal Mehta', 0, 'CSE'),
('Sneha Kapoor', 0, 'ECE'),
('Abhishek Yadav', 0, 'ME'),
('Vikas Mishra', 0, 'CE'),
('Deepak Kumar', 0, 'EE'),
('Riya Dutta', 0, 'IT'),
('Ananya Banerjee', 0, 'BBA'),
('Shreya Saha', 0, 'MBA'),
('Debanjan Chakraborty', 0, 'Physics'),
('Soumik Mitra', 0, 'Mathematics'),

('Nikhil Jain', 0, 'CSE'),
('Ayesha Khan', 0, 'ECE'),
('Tanmoy Bhattacharya', 0, 'ME'),
('Rakesh Pandey', 0, 'CE'),
('Manish Tiwari', 0, 'EE'),
('Ishita Bose', 0, 'IT'),
('Komal Jain', 0, 'BBA'),
('Ritu Gupta', 0, 'MBA'),
('Sagnik Mukherjee', 0, 'Physics'),
('Kaushik Das', 0, 'Mathematics');

SELECT * FROM student;


INSERT INTO course (course_id, title, dept, credits) VALUES
(101, 'Data Structures', 'CSE', 4),
(102, 'Algorithms', 'CSE', 4),
(103, 'DBMS', 'CSE', 3),
(104, 'Digital Electronics', 'ECE', 3),
(105, 'Thermodynamics', 'ME', 4),
(106, 'Structural Engineering', 'CE', 3),
(107, 'Circuit Theory', 'EE', 3),
(108, 'Operating Systems', 'IT', 4),
(109, 'Management Basics', 'BBA', 3),
(110, 'Finance', 'MBA', 4),
(111, 'Quantum Physics', 'Physics', 4),
(112, 'Linear Algebra', 'Mathematics', 3),
(113, 'Machine Learning', 'CSE', 4),
(114, 'Computer Networks', 'IT', 3),
(115, 'Software Engineering', 'CSE', 3);

SELECT * FROM course;


INSERT INTO classroom VALUES
('Tech Block A', 101, 60),
('Tech Block B', 102, 50),
('Tech Block C', 103, 55),
('Science Block', 201, 70),
('Management Block', 301, 80),
('Civil Block', 401, 65),
('Electrical Block', 501, 60),
('Workshop Block', 601, 75);

SELECT * FROM classroom;

INSERT INTO time_slot (time_slot_id, day, start_time, end_time) VALUES
(1, 'Monday',    '09:00:00', '10:00:00'),
(2, 'Monday',    '10:00:00', '11:00:00'),
(3, 'Tuesday',   '09:00:00', '10:00:00'),
(4, 'Tuesday',   '10:00:00', '11:00:00'),
(5, 'Wednesday', '11:00:00', '12:00:00'),
(6, 'Thursday',  '12:00:00', '13:00:00'),
(7, 'Friday',    '14:00:00', '15:00:00'),
(8, 'Saturday',  '09:00:00', '10:00:00');

SELECT * FROM time_slot;


INSERT INTO section VALUES
(1, 'Semester 1', 1, 101, 'Tech Block A', 101, 1),
(2, 'Semester 2', 1, 102, 'Tech Block A', 101, 2),
(3, 'Semester 3', 2, 104, 'Tech Block B', 102, 3),
(4, 'Semester 4', 2, 105, 'Workshop Block', 601, 4),
(5, 'Semester 4', 2, 106, 'Civil Block', 401, 5),
(6, 'Semester 5', 3, 107, 'Electrical Block', 501, 1),
(7, 'Semester 6', 3, 108, 'Tech Block C', 103, 2),
(8, 'Semester 1', 1, 109, 'Management Block', 301, 3),
(9, 'Semester 2', 1, 110, 'Management Block', 301, 4),
(10, 'Semester 3', 2, 111, 'Science Block', 201, 5),
(11, 'Semester 6', 3, 112, 'Science Block', 201, 1);

SELECT * FROM section;


INSERT INTO teaches VALUES
(1, 101, 1, 'Semester 1', 1),
(1, 102, 2, 'Semester 2', 1),
(2, 104, 3, 'Semester 3', 2),
(3, 105, 4, 'Semester 4', 2),
(4, 106, 5, 'Semester 4', 2),
(5, 107, 6, 'Semester 5', 3),
(6, 108, 7, 'Semester 6', 3),
(7, 109, 8, 'Semester 1', 1),
(8, 110, 9, 'Semester 2', 1),
(9, 111, 10, 'Semester 3', 2),
(10, 112, 11, 'Semester 6', 3);

SELECT * FROM teaches;


INSERT INTO takes VALUES
(1, 101, 1, 'Semester 1', 1, 'A'),
(2, 102, 2, 'Semester 2', 1, 'B'),
(3, 104, 3, 'Semester 3', 2, 'C'),
(4, 105, 4, 'Semester 4', 2, 'A'),
(5, 106, 5, 'Semester 4', 2, 'B'),
(6, 107, 6, 'Semester 5', 3, 'A'),
(7, 108, 7, 'Semester 6', 3, 'B'),
(8, 109, 8, 'Semester 1', 1, 'C'),
(9, 110, 9, 'Semester 2', 1, 'A'),
(10, 111, 10, 'Semester 3', 2, 'B'),
(11, 112, 11, 'Semester 6', 3, 'A');

SELECT * FROM takes;


INSERT INTO prereq (course_id, prereq_id) VALUES
(102, 101),  
(103, 101),  
(113, 102),  
(114, 101),  
(115, 103),  
(110, 109),  
(111, 112);  

SELECT * FROM prereq;

SELECT * FROM instructor_teaching_view;
SELECT * FROM student_course_details;
SELECT * FROM prereq_course_details;
SELECT * FROM section_details;
SELECT * FROM student_department_view;


CALL enroll_student(1,102,2,"Semester 2",1,'A');
SELECT * FROM student;


CALL get_instructor_schedule(1);

CALL get_student_course(2);

CALL get_student_in_section("101",1,"Semester 1",1);

CALL enroll_student(1,102,2,"Semester 2",1,'E');

INSERT INTO instructor VALUES
(12,'Mr. Russell',-2300,'CSE');

INSERT INTO section(building, room_number, time_slot_id) VALUES
('Tech Block A',101,1);


INSERT INTO teaches VALUES 
(1, 101, 1, 'Semester 1', 1);

