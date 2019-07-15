IF OBJECT_ID('tempdb..#8th_ids') IS NOT NULL DROP TABLE #8th_ids

SELECT DISTINCT
	   StudentID

  INTO #8th_ids

  FROM rpt.vRosterCurrent

 WHERE GETDATE() BETWEEN SchoolEntryDate AND SchoolExitDate
   AND GradeLevel = 8


SELECT DISTINCT
	   c1.local_student_id
	   ,c1.test_myp_excluded_avg AS ca1_overall
	   ,c2.test_myp_excluded_avg AS ca2_overall
	   ,(c1.test_myp_excluded_avg + c2.test_myp_excluded_avg) / 2 * 100 AS ca_average

  FROM eduphoria.dat.ca_results AS c1

  JOIN eduphoria.dat.ca_results AS c2
	ON c1.local_student_id = c2.local_student_id

 WHERE c1.ca_number = 1
   AND c2.ca_number = 2
   AND (c1.test_title = 'Algebra 1' AND c2.test_title = 'Algebra 1')
   AND (c1.test_myp_excluded_avg + c2.test_myp_excluded_avg) / 2 IS NOT NULL
   AND c1.local_student_id IN (
		SELECT *
		  FROM #8th_ids
		)