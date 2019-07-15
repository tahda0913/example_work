/*
Step 1: Update/Insert all records from csv into college_application_progress table. 

This query will update statuses on any existing applications, or insert new rows for new scholar/college application pairs
*/

BEGIN TRAN merge_to_naviance_CAS
	BEGIN TRY

		MERGE CollegeData.NAVIANCE.college_application_progress AS t
		USING CollegeData_STAGING.DAT.naviance_cas_biweekly_load AS s
		   ON t.local_student_id = s.local_student_id
				AND t.naviance_college_id = s.naviance_college_id

		WHEN MATCHED 
			AND t.naviance_student_id    != s.naviance_student_id
			 OR t.naviance_school_id	 != s.naviance_school_id
			 OR t.local_school_id		 != s.local_school_id
			 OR t.CEEB_code				 != s.CEEB_code
			 OR t.application_type  	 != s.application_type
			 OR t.application_status	 != s.application_status 
			 OR t.active_flag            != s.active_flag
				

		THEN
			UPDATE SET
				t.naviance_student_id 	  = s.naviance_student_id
				,t.naviance_school_id	  = s.naviance_school_id
				,t.local_school_id		  = s.local_school_id
				,t.CEEB_code			  = s.CEEB_code
				,t.application_status	  = s.application_status
				,t.application_type		  = s.application_type
				,t.active_flag            = s.active_flag


		WHEN NOT MATCHED THEN
			INSERT (naviance_student_id
					,local_student_id
					,naviance_school_id
					,local_school_id
					,naviance_college_id
					,CEEB_code
					,application_type
					,application_status
					,active_flag
					) VALUES (
						s.naviance_student_id
						,s.local_student_id
						,s.naviance_school_id
						,s.local_school_id
						,s.naviance_college_id
						,s.CEEB_code
						,s.application_type
						,s.application_status
						,s.active_flag
					);

		COMMIT TRAN merge_to_naviance_CAS

	END TRY

BEGIN CATCH
	ROLLBACK TRAN merge_to_naviance_CAS
	;THROW 50001, 'Unsuccessful merge to production. Check Staging table for adherence to uniqueness constraint of production table.', 1
END CATCH


/*
Step 2: This query will update records in the application results table for all applications that scholars have submitted to colleges. 

In the case of a new application submission, it will add a new record to the table
*/

BEGIN TRAN merge_to_naviance_CAR
	BEGIN TRY

		MERGE CollegeData.NAVIANCE.college_application_results AS t
		USING CollegeData_STAGING.DAT.naviance_cas_biweekly_load AS s
		   ON t.local_student_id = s.local_student_id
				AND t.naviance_college_id = s.naviance_college_id
				AND t.application_results_status = s.application_results_status
				AND s.active_flag = 1

		WHEN MATCHED
			AND t.naviance_student_id	  != s.naviance_student_id
			 OR t.naviance_school_id	  != s.naviance_school_id
			 OR t.local_school_id		  != s.local_school_id
			 OR t.CEEB_code				  != s.CEEB_code
			 OR t.application_type		  != s.application_type


		THEN
			UPDATE SET
				t.naviance_student_id	   = s.naviance_student_id
				,t.naviance_school_id	   = s.naviance_school_id
				,t.local_school_id		   = s.local_school_id
				,t.CEEB_code			   = s.CEEB_code
				,t.application_type		   = s.application_type
				,t.date_of_status		   = s.file_date

		WHEN NOT MATCHED AND (s.active_flag = 1 AND s.application_status != 'pending') THEN
			INSERT (naviance_student_id
					,local_student_id
					,naviance_school_id
					,local_school_id
					,naviance_college_id
					,CEEB_code
					,application_type
					,application_results_status
					,date_of_status
					) VALUES (
						s.naviance_student_id
						,s.local_student_id
						,s.naviance_school_id
						,s.local_school_id
						,s.naviance_college_id
						,s.CEEB_code
						,s.application_type
						,s.application_results_status
						,s.file_date
					);

		COMMIT TRAN merge_to_naviance_CAR

	END TRY

BEGIN CATCH
	ROLLBACK TRAN merge_to_naviance_CAR
	;THROW 50001, 'Unsuccessful merge to production. Check Staging table for adherence to uniqueness constraint of production table.', 1
END CATCH


/*
Step 3: In the event that a scholar cancels an application that's already been submitted to a college, this query will remove that record from the "application results"
		table, but it will remain in the "application progress" table as canceled.

Any record that is deleted as a result of this query will be returned for visual confirmation. 
*/
BEGIN TRAN delete_inactive_from_CAR
	BEGIN TRY

		MERGE CollegeData.NAVIANCE.college_application_results AS t
		USING CollegeData_STAGING.DAT.naviance_cas_biweekly_load AS s
		   ON t.local_student_id = s.local_student_id
				AND t.naviance_college_id = s.naviance_college_id 
				AND s.active_flag = 0

		WHEN MATCHED THEN
			DELETE
			OUTPUT $action
		    ,DELETED.row_id AS deleted_row
			,DELETED.local_student_id AS deleted_SID
			,DELETED.naviance_college_id AS deleted_CID
			,DELETED.application_results_status AS deleted_status
			,DELETED.date_of_status AS deleted_status_date
			;

	COMMIT TRAN delete_inactive_from_CAR
	END TRY

BEGIN CATCH
	ROLLBACK TRAN delete_inactive_from_CAR
	;THROW 50001, 'Deletion of inactive applications unsuccessful', 1
END CATCH


/*
Step 4: Remove the staging table in an effort to keep things tidy. If the file ever needs to be re-loaded for some reason, just re-run the python script.
*/
DROP TABLE CollegeData_STAGING.DAT.naviance_cas_biweekly_load
PRINT('Merge Successful. Staging table has been removed.')