CREATE TABLE CollegeData.NAVIANCE.college_application_progress (
	row_id INT IDENTITY(1, 1) PRIMARY KEY
	,naviance_student_id VARCHAR(10)
	,local_student_id VARCHAR(10)
	,naviance_school_id VARCHAR(10)
	,local_school_id VARCHAR(10)
	,naviance_college_id VARCHAR(10)
	,CEEB_code VARCHAR(10)
	,application_type VARCHAR(4)
	,application_status VARCHAR(100)
	,active_flag BIT
	,UNIQUE(local_student_id, naviance_college_id)
)


CREATE TABLE CollegeData.NAVIANCE.college_application_results (
	row_id INT IDENTITY(1,1) PRIMARY KEY
	,naviance_student_id VARCHAR(10)
	,local_student_id VARCHAR(10)
	,naviance_school_id VARCHAR(10)
	,local_school_id VARCHAR(10)
	,naviance_college_id VARCHAR(10)
	,CEEB_code VARCHAR(10)
	,application_type VARCHAR(4)
	,application_results_status VARCHAR(100)
	,date_of_status DATE
	,UNIQUE(local_student_id, naviance_college_id, application_results_status)
)

