IF OBJECT_ID('tempdb..#ca_scores') IS NOT NULL DROP TABLE #ca_scores

SELECT c1.student_local_id
	   ,SUM(CAST(c1.correct AS DECIMAL(6, 4))) / COUNT(c1.correct) * 100 AS ca1_overall_score
	   ,SUM(CAST(c2.correct AS DECIMAL(6, 4))) / COUNT(c2.correct) * 100 AS ca2_overall_score

  INTO #ca_scores

  FROM DAT.CA1_2017_2018 AS c1

  JOIN DAT.CA2_2017_2018 AS c2
	ON c1.Student_Local_ID = c2.Student_Local_ID

 WHERE c1.Test_Grade = 8
   AND c2.Test_Grade = 8
   AND c1.test_title LIKE '%ALGEBRA%'
   AND c2.test_title LIKE '%ALGEBRA%'
   AND c1.test_title NOT LIKE '%CR%'
   AND c2.test_title NOT LIKE '%CR%'
   AND c1.Campus_Name LIKE '%MS'
   AND c2.Campus_Name LIKE '%MS'

GROUP BY c1.Student_Local_ID



IF OBJECT_ID('tempdb..#tested_scholar_ids') IS NOT NULL DROP TABLE #tested_scholar_ids

SELECT student_local_id

  INTO #tested_scholar_ids

  FROM #ca_scores



IF OBJECT_ID('tempdb..#eoc_scores') IS NOT NULL DROP TABLE #eoc_scores

SELECT local_student_id
	   ,Administration_Date
	   ,raw_score
	   ,Scale_Score
	   ,ROW_NUMBER() OVER (PARTITION BY local_student_id ORDER BY administration_date) AS test_taken_#

  INTO #eoc_scores

  FROM FF.EOC_27_SPRING

 WHERE End_of_Course_Code = 'A1'
   AND Score_Code = 'S'
   AND Local_Student_ID IN (
		SELECT student_local_id 
		  FROM #tested_scholar_ids
		)


SELECT c.*
	   ,e.raw_score
	   ,e.scale_score

  FROM #ca_scores AS c

  JOIN #eoc_scores AS e
	ON c.Student_Local_ID = e.local_student_id
		AND e.test_taken_# = 1