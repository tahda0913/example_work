--------------------------------------------------------------------------------
--  GPA
--------------------------------------------------------------------------------
WITH 
    graduate_gpas AS (

        SELECT
            student_id
            ,gpa_unweighted
            ,gpa_weighted        

        FROM 
            ODS_CPS.DAT.graduate_gpa

    )
    ,current_gpas_unweighted AS (

        SELECT 
            STUDENTID
            ,GPA
    
        FROM ODS_CPS.PS.CLASSRANK

        WHERE 
            YEARID = 28
            AND GPAMETHOD LIKE '%Uplift Simple%'

    )
    ,current_gpas_weighted AS (

        SELECT 
            STUDENTID
            ,GPA
    
        FROM ODS_CPS.PS.CLASSRANK

        WHERE 
            YEARID = 28
            AND GPAMETHOD LIKE '%Uplift Weighted%'

    )
    ,current_gpas_combined AS (

        SELECT 
            a.STUDENTID AS ps_id
            ,a.GPA AS gpa_unweighted
            ,b.GPA AS gpa_weighted

        FROM 
            current_gpas_unweighted AS a
            LEFT OUTER JOIN current_gpas_weighted AS b
                ON a.STUDENTID = b.STUDENTID

    )
    ,current_gpas_with_student_ids AS (

        SELECT 
            a.STUDENT_NUMBER AS student_id
            ,b.gpa_unweighted
            ,b.gpa_weighted

        FROM 
            ODS_CPS.PS.STUDENTS AS a
            LEFT OUTER JOIN current_gpas_combined AS b
                ON a.ID = b.ps_id

    )
    ,gpa AS (

        SELECT *

        FROM graduate_gpas

        WHERE 
            gpa_unweighted IS NOT NULL
            AND gpa_weighted IS NOT NULL

        UNION

        SELECT *

        FROM current_gpas_with_student_ids

        WHERE 
            gpa_unweighted IS NOT NULL
            AND gpa_weighted IS NOT NULL

    )

--------------------------------------------------------------------------------
--  ACT
--------------------------------------------------------------------------------
    ,date_ranked_acts AS (

        SELECT 
            local_id
            ,composite_scale_score
            ,mathematics_scale_score
            ,science_scale_score
            ,reading_scale_score
            ,english_scale_score
            ,ROW_NUMBER() OVER(
            
                PARTITION BY local_id

                ORDER BY composite_scale_score DESC
        
            ) AS act_rank

        FROM ODS_CPS.RPT.vACT

        GROUP BY 
            local_id
            ,composite_scale_score
            ,mathematics_scale_score
            ,science_scale_score
            ,reading_scale_score
            ,english_scale_score

    )
    ,act AS (

        SELECT
            local_id
            ,composite_scale_score AS composite_act
            ,mathematics_scale_score AS math_act
            ,science_scale_score AS science_act
            ,reading_scale_score AS reading_act
            ,english_scale_score AS english_act

        FROM date_ranked_acts

        WHERE act_rank = 1

    )

--------------------------------------------------------------------------------
--  SAT
--------------------------------------------------------------------------------
    ,pre_2017_sats AS (

        SELECT
            local_student_id
            ,mathematics_score
            ,reading_score + writing_score AS reading_and_writing_score
    
        FROM ODS_CPS.RPT.vSAT

        WHERE writing_score IS NOT NULL

    )
    ,converted_pre_2017_sats AS (

        SELECT 
            a.local_student_id
            ,b.New_SAT_Math_Section_200_800 AS mathematics_score
            ,c.New_SAT_Evidence_Based_Reading_and_Writing_Section_200_800 AS reading_and_writing_score

        FROM 
            pre_2017_sats AS a
            LEFT JOIN CollegeData.DAT.OldToNewSATcrosswalk_math AS b
                ON a.mathematics_score = b.Old_SAT_Math_Section_200_800
            LEFT JOIN CollegeData.DAT.OldToNewSATcrosswalk_reading_and_writing AS c
                ON a.reading_and_writing_score = c.Old_SAT_Writing_plus_Critical_Reading_Sections_400_1600

    )
    ,post_2017_sats AS (

        SELECT 
            local_student_id
            ,mathematics_score
            ,reading_score
    
        FROM ODS_CPS.RPT.vSAT

        WHERE writing_score IS NULL

    )
    ,sat_union AS (

        SELECT *

        FROM converted_pre_2017_sats

        UNION

        SELECT *

        FROM post_2017_sats

    )
    ,date_ranked_sats AS (

        SELECT 
            local_student_id
            ,mathematics_score
            ,reading_and_writing_score
            ,ROW_NUMBER() OVER(
            
                PARTITION BY local_student_id

                ORDER BY (mathematics_score + reading_and_writing_score) DESC
        
            ) AS sat_rank

        FROM sat_union

        GROUP BY 
            local_student_id
            ,mathematics_score
            ,reading_and_writing_score

    )
    ,sat AS (

        SELECT
            local_student_id
            ,mathematics_score AS math_sat
            ,reading_and_writing_score AS reading_and_writing_sat
            ,mathematics_score + reading_and_writing_score AS composite_sat
     
        FROM date_ranked_sats

        WHERE sat_rank = 1

    )

--------------------------------------------------------------------------------
--  College characteristics
--------------------------------------------------------------------------------
    ,college_data AS (

        SELECT DISTINCT
            a.*

            ,b.naviance_college_name

            ,c.Institution_entity_name
            ,c.admissions_difficulty_ranking
            ,c.Average_ACT_Composite_25th_percentile_score AS Institutional_Average_ACT_Composite_25th_percentile_score
            ,c.Average_SAT_Total_25th_percentile AS Institutional_Average_SAT_Total_25th_percentile
            ,c.Average_Admissions_total_Percentage AS Institutional_Average_Admissions_total_Percentage
            ,c.Average_Admissions_mens_Percentage AS Institutional_Average_Admissions_mens_Percentage
            ,c.Average_Admissions_women_Percentage AS Institutional_Average_Admissions_women_Percentage
            ,c.Historically_Black_College_or_University AS Institutional_HBCU_status
            ,c.Institutional_category
            ,c.Sector_of_institution

            ,d.Secondary_school_GPA AS Institutional_Secondary_school_GPA
            ,d.Secondary_school_rank AS Institutional_Secondary_school_rank
            ,d.Secondary_school_record AS Institutional_Secondary_school_record
            ,d.Completion_of_college_preparatory_program AS Institutional_Completion_of_college_preparatory_program
            ,d.Formal_demonstration_of_competencies AS Institutional_Formal_demonstration_of_competencies
            ,d.Admission_test_scores AS Institutional_Admission_test_scores
            ,d.TOEFL_Test_of_English_as_Foreign_Language AS Institutional_TOEFL_Test_of_English_as_Foreign_Language
            ,d.Other_Test_Wonderlic_WISC_III_etc AS Institutional_Other_Test_Wonderlic_WISC_III_etc

        FROM 
            CollegeData.DAT.CeebToUnitIDCrosswalk AS a
            LEFT JOIN CollegeData.Naviance.naviance_college_data AS b
                ON a.ceeb_code = b.naviance_college_id
            LEFT JOIN CollegeData.DAT.college_rankings AS c
                ON a.UNITID = c.UNITID
            LEFT JOIN CollegeData.IPEDS_2017_provisional.Admissions_and_Test_Scores AS d
                ON a.UNITID = d.UNITID

    )

--------------------------------------------------------------------------------
--  vStudent
--------------------------------------------------------------------------------
    ,student_info AS (

        SELECT
            StudentID
            ,GraduatedSchoolID
            ,GraduatedSchoolName
            ,ClassOf
            ,FedEthnicity

        FROM ODS_CPS.RPT.vStudent
    
        WHERE GradeLevel = 12

    )

--------------------------------------------------------------------------------
--  Demographics
--------------------------------------------------------------------------------
    ,demographics_union AS (

        SELECT
            StudentID
            ,Race
            ,Ethnicity
            ,EconomicDisadvantagedDescription
            ,28 AS demographics_year_id

        FROM ODS_CPS.RPT.vDemographicsCurrent

        UNION

        SELECT
            StudentID
            ,Race
            ,Ethnicity
            ,EconomicDisadvantagedCode
            ,27 AS demographics_year_id

        FROM ODS_CPS.dbo.fnDemographics('2017-08-25')

        WHERE GradeLevel = 12

        UNION

        SELECT
            StudentID
            ,Race
            ,Ethnicity
            ,EconomicDisadvantagedDescription
            ,26 AS demographics_year_id

        FROM ODS_CPS.dbo.fnDemographics('2016-08-25')

        WHERE GradeLevel = 12
    
        UNION

        SELECT
            StudentID
            ,Race
            ,Ethnicity
            ,EconomicDisadvantagedDescription
            ,25 AS demographics_year_id

        FROM ODS_CPS.dbo.fnDemographics('2015-08-25')

        WHERE GradeLevel = 12
        
    )
    ,most_recent_demographics_year AS (

        SELECT
            StudentID
            ,MAX(demographics_year_id) AS most_recent_demographics

        FROM demographics_union

        GROUP BY
            StudentID

    )
    ,demographics AS (

        SELECT
            b.StudentID
            ,b.Race
            ,b.Ethnicity
            ,CASE
                WHEN b.EconomicDisadvantagedDescription LIKE 'FREE LUNCH' THEN 1
                ELSE 0

                END AS free_lunch
        
        FROM
            most_recent_demographics_year AS a
            LEFT JOIN demographics_union AS b
                ON a.StudentID = b.StudentID
                AND a.most_recent_demographics = b.demographics_year_id

    )

--------------------------------------------------------------------------------
--  Naviance applications
--------------------------------------------------------------------------------
    ,date_ranked_applications AS (

        SELECT 
            local_student_id
            ,local_school_id
            ,naviance_college_id
            ,CEEB_code
            ,application_results_status
            ,date_of_status
            ,ROW_NUMBER() OVER(
            
                PARTITION BY 
                    local_student_id
                    ,CEEB_code

                ORDER BY date_of_status DESC
        
            ) AS application_date_rank

        FROM CollegeData.Naviance.college_application_results

        WHERE 
            application_results_status NOT LIKE 'incomplete'
            AND application_results_status NOT LIKE 'unknown'
            AND application_results_status NOT LIKE 'withdrawn'
            AND application_results_status NOT LIKE 'no decision'
            AND application_results_status IS NOT NULL

        GROUP BY
            local_student_id
            ,local_school_id
            ,naviance_college_id
            ,CEEB_code
            ,application_results_status
            ,date_of_status

    )
    ,applications AS (

        SELECT
            local_student_id
            ,naviance_college_id
            ,CEEB_code
            ,application_results_status

        FROM date_ranked_applications

        WHERE application_date_rank = 1

    )

--------------------------------------------------------------------------------
--  Final table
--------------------------------------------------------------------------------
SELECT DISTINCT
    applications.*

    ,college_data.UNITID
    ,college_data.Institution_entity_name
    ,college_data.admissions_difficulty_ranking
    ,college_data.Institutional_Average_ACT_Composite_25th_percentile_score
    ,college_data.Institutional_Average_SAT_Total_25th_percentile
    ,college_data.Institutional_Average_Admissions_total_Percentage
    ,college_data.Institutional_Average_Admissions_mens_Percentage
    ,college_data.Institutional_Average_Admissions_women_Percentage
    ,college_data.Institutional_HBCU_status
    ,college_data.Institutional_category
    ,college_data.Sector_of_institution
    ,college_data.Institutional_Secondary_school_GPA
    ,college_data.Institutional_Secondary_school_rank
    ,college_data.Institutional_Secondary_school_record
    ,college_data.Institutional_Completion_of_college_preparatory_program
    ,college_data.Institutional_Formal_demonstration_of_competencies
    ,college_data.Institutional_Admission_test_scores
    ,college_data.Institutional_TOEFL_Test_of_English_as_Foreign_Language
    ,college_data.Institutional_Other_Test_Wonderlic_WISC_III_etc
    
    ,student_info.ClassOf
    ,student_info.FedEthnicity
    ,student_info.GraduatedSchoolID
    ,student_info.GraduatedSchoolName

    ,demographics.Race
    ,demographics.Ethnicity
    ,demographics.free_lunch

    ,gpa.gpa_unweighted
    ,gpa.gpa_weighted

    ,act.composite_act
    ,act.english_act
    ,act.math_act
    ,act.reading_act
    ,act.science_act

    ,sat.math_sat
    ,sat.reading_and_writing_sat
    ,sat.math_sat + sat.reading_and_writing_sat AS total_sat

FROM 
    applications
    LEFT JOIN college_data
        ON applications.CEEB_code = college_data.ceeb_code
    LEFT JOIN student_info
        ON applications.local_student_id = student_info.StudentID
    LEFT JOIN demographics
        ON applications.local_student_id = demographics.StudentID
    LEFT JOIN gpa
        ON applications.local_student_id = gpa.student_id
    LEFT JOIN act
        ON applications.local_student_id = act.local_id
    LEFT JOIN sat
        ON applications.local_student_id = sat.local_student_id

ORDER BY
    applications.local_student_id
    ,applications.ceeb_code