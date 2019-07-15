/*
NOTE - Below used to test delete query. RUN THESE STATEMENTS BEFORE MERGE STATEMENT TO TEST
*/

/*
INSERT INTO CollegeData.NAVIANCE.college_application_results (
	naviance_student_id
	,local_student_id
	,naviance_school_id
	,local_school_id
	,naviance_college_id
	,CEEB_code
	,application_type
	,application_results_status
	,date_of_status
	) VALUES (
	1, 1, 1, 1, 101, 101, 'RD', 'Pending', '2018-10-20')


IF OBJECT_ID('tempdb..#test_delete') IS NOT NULL DROP TABLE #test_delete

SELECT '1' AS naviance_student_id
	   ,'1' AS local_student_id
	   ,'1' AS naviance_school_id
	   ,'1' AS local_school_id
	   ,'101' AS naviance_college_id
	   ,'101' AS CEEB_code
	   ,'Canceled' AS application_status
	   ,'RD' AS application_type
	   ,'Pending' AS application_results_status
	   ,0 AS active_flag
	   ,'2019-01-10' AS file_date

  INTO #test_delete
*/

/*
Actual Query Starts Here
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
			;

	COMMIT TRAN delete_inactive_from_CAR
	END TRY

BEGIN CATCH
	ROLLBACK TRAN delete_inactive_from_CAR
	;THROW 50001, 'Deletion of inactive applications unsuccessful', 1
END CATCH

DROP TABLE CollegeData_STAGING.DAT.naviance_cas_biweekly_load

