/*
Script: Create results table for unofficial ACT tests administered through Eduphoria Aware
Author: THarpin
Date: 4/25/19
*/


/*
Create base table with raw results. Pulls from Aware tables to get a complete list of question-level results per scholar

If/Else statement at start checks test names from aware database to ensure they match either pre act or practice act, and throws 
and exception/quits the proc otherwise. This is to ensure we don't get any unexpected results.
*/

IF OBJECT_ID('tempdb..#raw_results') IS NOT NULL DROP TABLE #raw_results	

DECLARE @throw_state INT
SET @throw_state = 1

IF @throw_state = (SELECT MAX(CASE
								WHEN title LIKE '%PreACT%' THEN 0
								WHEN title LIKE '%Practice ACT%' THEN 0
								ELSE 1
							  END)

					 FROM eduphoria.uplift.aw_test
					 
					WHERE test_type = 1005
					  AND test_year >= '2018') 
					THROW 50001, 'uplift.aw_test includes unexpected test title for test_type 1005', 1

ELSE IF @throw_state = (SELECT MAX(CASE
										WHEN title LIKE '%Math%' THEN 0
										WHEN title LIKE '%Reading%' THEN 0
										WHEN title LIKE '%English%' THEN 0
										WHEN title LIKE '%Science%' THEN 0
										ELSE 1
									END)
								  
						  FROM eduphoria.uplift.aw_test
								 
						 WHERE test_type = 1005
						   AND test_year >= '2018')
						 THROW 50002, 'uplift.aw_test includes unexpected test subject in test title for test_type 1005', 1
	 
ELSE								
SELECT t.test_year - 1990 AS year_id

	   ,CASE
			WHEN MONTH(te.entry_date) BETWEEN 8 AND 12 THEN 'Fall'
			WHEN MONTH(te.entry_date) BETWEEN 1 AND 3 THEN 'Winter'
			WHEN MONTH(te.entry_date) BETWEEN 4 AND 6 THEN 'Spring'
		END AS academic_term

	   ,s.local_id
	   ,t.title AS test_title

	   ,CASE
			WHEN t.title LIKE '%PreACT%' THEN 'PreACT'
			WHEN t.title LIKE '%Practice ACT%' THEN 'ACT'
		END AS test_type

	   ,CASE
			WHEN t.title LIKE '%Math%' THEN 'Math'
			WHEN t.title LIKE '%Reading%' THEN 'Reading'
			WHEN t.title LIKE '%English%' THEN 'English'
			WHEN t.title LIKE '%Science%' THEN 'Science'
		END AS test_subject

	   ,q.question_num
	   ,r.response
	   ,q.correct_value
	   ,r.correct
	   ,te.entry_date AS print_date

  INTO #raw_results

  FROM uplift.aw_response AS r

  JOIN uplift.aw_test_entry AS te
	ON r.test_entry_id = te.test_entry_id

  JOIN uplift.aw_test AS t
	ON t.test_id = te.test_id

  JOIN uplift.aw_question AS q
	ON q.question_id = r.test_question_id

  JOIN uplift.so_students AS s
	ON s.aware_student_id = te.student_id

 WHERE t.test_type = 1005
   AND t.test_year >= '2018'

/*
Add CRS tags to question results. Created by using lookup table in eduphoria database that is updated per test admin. window.
Secondary CCs provide CRS tags in form of excel sheets that are loaded into lookup table
*/
IF OBJECT_ID('tempdb..#crs_tagging') IS NOT NULL DROP TABLE #crs_tagging

SELECT rr.year_id
	   ,rr.academic_term
	   ,rr.local_id
	   ,rr.test_title
	   ,rr.test_type	
	   ,rr.test_subject
	   ,rr.question_num
	   ,ct.crs_strand
	   ,ct.crs_skill
	   ,rr.response
	   ,rr.correct_value
	   ,rr.correct
	   ,rr.print_date

  INTO #crs_tagging

  FROM #raw_results AS rr

LEFT JOIN eduphoria.dat.epas_crs_tagging AS ct
	ON ct.year_id = rr.year_id
		AND ct.academic_term = rr.academic_term
		AND ct.academic_subject = rr.test_subject
		AND ct.question_number = rr.question_num
		AND CASE
				WHEN ct.test_name = 'Practice ACT' THEN 'ACT'
				ELSE ct.test_name
			END = rr.test_type


/*
Perform calculations for overall scores. Sum of points earned used later with scale conversion lookup table. 
Skill level column used to give idea of how scholars perform on questions by level of difficulty
Skill level percent score IS unique to a test subject inside each administration window
*/
IF OBJECT_ID('tempdb..#overall_scores') IS NOT NULL DROP TABLE #overall_scores

SELECT ct.year_id
	   ,ct.academic_term
	   ,ct.local_id
	   ,ct.test_title
	   ,ct.test_type
	   ,ct.test_subject
	   ,ct.question_num
	   ,ct.crs_strand
	   ,ct.crs_skill
	   ,ct.response
	   ,ct.correct_value
	   ,ct.correct

	   ,SUM(ct.correct) OVER (PARTITION BY ct.year_id, ct.academic_term, ct.local_id, ct.test_subject) AS subject_points_earned

	   ,COUNT(ct.correct) OVER (PARTITION BY ct.year_id, ct.academic_term, ct.local_id, ct.test_subject) AS subject_points_possible

	   ,SUM(CAST(ct.correct AS DECIMAL(6, 3))) OVER (PARTITION BY ct.year_id, ct.academic_term, ct.local_id, ct.crs_strand)
		/ COUNT(CAST(ct.correct AS DECIMAL(6, 3))) OVER (PARTITION BY ct.year_id, ct.academic_term, ct.local_id, ct.crs_strand) AS crs_percent_score

	   ,ROUND(ct.crs_skill, -2) AS skill_level

	   ,SUM(CAST(ct.correct AS DECIMAL(6, 3))) OVER (PARTITION BY ct.year_id, ct.academic_term, ct.local_id, ct.test_subject, ROUND(ct.crs_skill, -2))
		/ COUNT(CAST(ct.correct AS DECIMAL(6, 3))) OVER (PARTITION BY ct.year_id, ct.academic_term, ct.local_id, ct.test_subject, ROUND(ct.crs_skill, -2)) AS skill_level_percent_score

	   ,print_date

  INTO #overall_scores

  FROM #crs_tagging AS ct


/*
Join overall scores to scale conversion lookup table. 
Lookup table is updated each test administration window by securing a copy of the test scoring guide from assessment team 
and then uploading to database.
*/
IF OBJECT_ID('tempdb..#scale_conversions') IS NOT NULL DROP TABLE #scale_conversions

SELECT os.year_id
	   ,os.academic_term
	   ,os.local_id
	   ,os.test_title
	   ,os.test_type
	   ,os.test_subject
	   ,os.question_num
	   ,os.crs_strand
	   ,os.crs_skill
	   ,os.response
	   ,os.correct_value
	   ,os.correct
	   ,os.subject_points_earned
	   ,os.subject_points_possible
	   ,sc.scale_score
	   ,os.crs_percent_score
	   ,os.skill_level
	   ,os.skill_level_percent_score
	   ,os.print_date

  INTO #scale_conversions

  FROM #overall_scores AS os

LEFT JOIN eduphoria.dat.epas_scale_conversions AS sc
	ON sc.year_id = os.year_id
		AND sc.academic_term = os.academic_term
		AND sc.test_subject = os.test_subject
		AND sc.raw_score = os.subject_points_earned
		AND CASE
				WHEN sc.test_name LIKE '%Practice%' THEN 'ACT'
				ELSE sc.test_name
			END = os.test_type


/*
Calculates a composite score in a new column for each scholar per assessment window

--Limits to one subject first and then pull composite for exactly 4 subject.

*/
IF OBJECT_ID('tempdb..#distinct_subscores') IS NOT NULL DROP TABLE #distinct_subscores
SELECT DISTINCT
		year_id
		,academic_term
		,local_id
		,test_title
		,test_type
		,test_subject
		,scale_score		

  INTO #distinct_subscores

  FROM #scale_conversions


IF OBJECT_ID('tempdb..#composites') IS NOT NULL DROP TABLE #composites
SELECT year_id
	   ,academic_term
	   ,local_id

	   ,CASE 
			WHEN COUNT(DISTINCT test_title) != 4 THEN NULL
			ELSE AVG(scale_score * 1.0)
		END AS composite_score

  INTO #composites

  FROM #distinct_subscores

GROUP BY year_id
	     ,academic_term
		 ,local_id


IF OBJECT_ID('tempdb..#joined_composite') IS NOT NULL DROP TABLE #joined_composite

SELECT sc.year_id
	   ,sc.academic_term
	   ,sc.local_id
	   ,sc.test_title
	   ,sc.test_type
	   ,sc.test_subject
	   ,sc.question_num
	   ,sc.crs_strand
	   ,sc.crs_skill
	   ,sc.response
	   ,sc.correct_value
	   ,sc.correct
	   ,sc.subject_points_earned
	   ,sc.subject_points_possible
	   ,sc.scale_score
	   ,ROUND(cs.composite_score, 0) AS composite_score
	   ,sc.crs_percent_score
	   ,sc.skill_level
	   ,sc.skill_level_percent_score
	   ,sc.print_date

  INTO #joined_composite

  FROM #scale_conversions AS sc

  JOIN #composites AS cs
	ON cs.local_id = sc.local_id
		AND cs.year_id = sc.year_id
		AND cs.academic_term = sc.academic_term

/*
Select out composite score as its own test subject to union back to main table for use in dashboard
*/
IF OBJECT_ID('tempdb..#comp_as_subject') IS NOT NULL DROP TABLE #comp_as_subject
SELECT
	   year_id
	   ,academic_term
	   ,local_id
	   ,NULL AS test_title
	   ,test_type
	   ,'Composite' AS test_subject
	   ,NULL AS question_num
	   ,NULL AS crs_strand
	   ,NULL AS crs_skill
	   ,NULL AS response
	   ,NULL AS correct_value
	   ,NULL AS correct
	   ,NULL AS subject_points_earned
	   ,NULL AS subject_points_possible
	   ,composite_score AS scale_score
	   ,composite_score
	   ,NULL as crs_percent_score
	   ,NULL as skill_level
	   ,NULL as skill_level_percent_score
	   ,MAX(print_date) AS print_date

  INTO #comp_as_subject

  FROM #joined_composite

 WHERE composite_score IS NOT NULL

GROUP BY year_id
		 ,academic_term
		 ,local_id
		 ,test_type
		 ,composite_score


/*
Creates permanent results table and inserts all records from final temp table
*/
IF OBJECT_ID('eduphoria.dat.unofficial_EPAs_results') IS NOT NULL DROP TABLE eduphoria.dat.unofficial_EPAs_results

CREATE TABLE eduphoria.dat.unofficial_EPAs_results (
	year_id INT
	,academic_term VARCHAR(25)
	,local_id VARCHAR(20)
	,test_title NVARCHAR(100) NULL
	,test_type VARCHAR(25) NULL
	,test_subject VARCHAR(25) NULL
	,question_num INT NULL
	,crs_strand VARCHAR(10) NULL
	,crs_skill INT NULL
	,response VARCHAR(1) NULL
	,correct_value VARCHAR(1) NULL
	,correct BIT NULL
	,subject_points_earned INT NULL
	,subject_points_possible INT NULL
	,scale_score INT NULL
	,composite_score INT NULL
	,crs_percent_score DECIMAL(4, 3) NULL
	,skill_level INT NULL
	,skill_level_percent_score DECIMAL(4, 3) NULL
	,print_date DATE NULL
)

INSERT INTO eduphoria.dat.unofficial_EPAs_results 
SELECT year_id
	   ,academic_term
	   ,local_id
	   ,test_title
	   ,test_type
	   ,test_subject
	   ,question_num
	   ,crs_strand
	   ,crs_skill
	   ,response
	   ,correct_value
	   ,correct
	   ,subject_points_earned
	   ,subject_points_possible
	   ,scale_score
	   ,composite_score
	   ,crs_percent_score
	   ,skill_level
	   ,skill_level_percent_score
	   ,print_date

  FROM #joined_composite

INSERT INTO eduphoria.dat.unofficial_EPAs_results
SELECT year_id
	   ,academic_term
	   ,local_id
	   ,test_title
	   ,test_type
	   ,test_subject
	   ,question_num
	   ,crs_strand
	   ,crs_skill
	   ,response
	   ,correct_value
	   ,correct
	   ,subject_points_earned
	   ,subject_points_possible
	   ,scale_score
	   ,composite_score
	   ,crs_percent_score
	   ,skill_level
	   ,skill_level_percent_score
	   ,print_date

  FROM #comp_as_subject

