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
