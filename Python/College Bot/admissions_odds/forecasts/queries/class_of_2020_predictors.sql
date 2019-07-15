--------------------------------------------------------------------------------
--  GPA
--------------------------------------------------------------------------------
WITH 
    gpa AS (

        SELECT 
            b.STUDENT_NUMBER AS student_id
            ,a.GPA AS gpa_unweighted
    
        FROM 
            ODS_CPS.PS.CLASSRANK AS a
            LEFT JOIN ODS_CPS.PS.STUDENTS AS b
                ON a.STUDENTID = b.ID

        WHERE 
            YEARID = 28
            AND GPAMETHOD LIKE '%Uplift Simple%'

    )

--------------------------------------------------------------------------------
--  ACT
--------------------------------------------------------------------------------
    ,date_ranked_acts AS (

        SELECT 
            local_id
            ,composite_scale_score
            ,ROW_NUMBER() OVER(
            
                PARTITION BY local_id

                ORDER BY composite_scale_score DESC
        
            ) AS act_rank

        FROM ODS_CPS.RPT.vACT

        GROUP BY 
            local_id
            ,composite_scale_score

    )
    ,act AS (

        SELECT
            local_id
            ,composite_scale_score AS composite_act

        FROM date_ranked_acts

        WHERE act_rank = 1

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

        SELECT DISTINCT
            StudentID
            ,SchoolName
            ,ClassOf
            ,FedEthnicity

        FROM ODS_CPS.RPT.vStudent
    
        WHERE 
            ClassOf = 2020
            AND SchoolName LIKE '%hs%'
            AND SchoolExitDate = '2019-05-28'

    )

--------------------------------------------------------------------------------
--  Demographics
--------------------------------------------------------------------------------
    ,demographics AS (

        SELECT
            StudentID
            ,Race
            ,Ethnicity
            ,CASE
                WHEN EconomicDisadvantagedDescription LIKE 'FREE LUNCH' THEN 1
                ELSE 0

            END AS free_lunch
        
        FROM ODS_CPS.dbo.fnDemographics('2019-04-15')

    )

--------------------------------------------------------------------------------
--  Final table
--------------------------------------------------------------------------------
SELECT DISTINCT    
    student_info.StudentID
    ,student_info.ClassOf
    ,student_info.FedEthnicity
    ,student_info.SchoolName

    ,demographics.Race
    ,demographics.Ethnicity
    ,demographics.free_lunch

    ,gpa.gpa_unweighted

    ,act.composite_act

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

FROM 
    student_info
    LEFT JOIN demographics
        ON student_info.StudentID = demographics.StudentID
    LEFT JOIN gpa
        ON student_info.StudentID = gpa.student_id
    LEFT JOIN act
        ON student_info.StudentID = act.local_id
    LEFT JOIN college_data
        ON 1 = 1

ORDER BY StudentID
