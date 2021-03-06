IF OBJECT_ID('tempdb..#predictions') IS NOT NULL DROP TABLE #predictions

SELECT [row_id]
      ,[local_id]
      ,[test_name]
      ,CAST(ROUND(ca1_overall, 2) AS DECIMAL(5,2)) AS ca1_overall
	  ,CAST(ROUND(ca2_overall, 2) AS DECIMAL(5,2)) AS ca2_overall
	  ,CAST(ROUND(ca_average, 2) AS DECIMAL(5,2)) AS ca_average
      ,CAST(ROUND(predicted_STAAR, 0) AS DECIMAL(4,0)) AS predicted_STAAR

  INTO #predictions

  FROM [ODS_CPS_STAGING].[DAT].[ca_staar_predictions_28]


IF OBJECT_ID('tempdb..#pred_plus_id_info') IS NOT NULL DROP TABLE #pred_plus_id_info

SELECT p.local_id
	   ,v.StudentFirstName AS student_first_name
	   ,v.StudentLastName AS student_last_name
	   ,v.GradeLevel
	   ,v.SchoolNameAbbreviated AS school_name
	   ,p.test_name
	   ,p.ca1_overall
	   ,p.ca2_overall
	   ,p.ca_average
	   ,p.predicted_STAAR
	   ,cs.approaches_cut_score
	   ,cs.meets_cut_score
	   ,cs.masters_cut_score
	 
  INTO #pred_plus_id_info	   

  FROM #predictions AS p

  JOIN ODS_CPS.rpt.vStudent AS v
	ON p.local_id = v.StudentID
		AND GETDATE() BETWEEN v.SchoolEntryDate AND v.SchoolExitDate

  JOIN ODS_CPS_STAGING.dat.staar_scale_cut_scores AS cs
	ON p.test_name = cs.title


IF OBJECT_ID('DAT.final_ca_staar_predictions_28') IS NOT NULL DROP TABLE DAT.final_ca_staar_predictions_28

SELECT local_id
	   ,student_first_name
	   ,student_last_name
	   ,GradeLevel
	   ,school_name
	   ,test_name
	   ,ca1_overall
	   ,ca2_overall
	   ,ca_average
	   ,predicted_STAAR
	   ,approaches_cut_score
	   ,meets_cut_score
	   ,masters_cut_score

	   ,CASE
			WHEN predicted_STAAR > approaches_cut_score THEN 1
			ELSE 0
		END AS predicted_to_approach

	   ,CASE
			WHEN predicted_STAAR > meets_cut_score THEN 1
			ELSE 0
		END AS predicted_to_meet

		,CASE
			WHEN predicted_STAAR > masters_cut_score THEN 1
			ELSE 0
		END AS predicted_to_master

		,CASE
			WHEN predicted_STAAR > masters_cut_score THEN 'Masters'
			WHEN predicted_STAAR > meets_cut_score THEN 'Meets'
			WHEN predicted_STAAR > approaches_cut_score THEN 'Approaches'
			ELSE 'Does Not Approach'
		END AS best_predicted_level

  --INTO ODS_CPS_STAGING.DAT.final_ca_staar_predictions_28

  FROM #pred_plus_id_info