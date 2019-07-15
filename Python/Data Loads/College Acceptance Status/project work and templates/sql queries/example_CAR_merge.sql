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


