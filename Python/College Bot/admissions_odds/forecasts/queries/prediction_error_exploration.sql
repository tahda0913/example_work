--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#predictions') IS NOT NULL DROP TABLE #predictions

SELECT 
    [local_student_id]
    ,[ClassOf]
    ,[naviance_college_id]
    ,[application_results_status]
    ,[UNITID]
    ,[Institution_entity_name]
    ,ABS(1.0 * outcome - predicted_outcome) AS prediction_error
    ,1.0 * outcome - predicted_outcome AS prediction_error_direction
    ,CASE 
        WHEN outcome < predicted_outcome THEN 1
        ELSE 0
    END AS false_positive
    ,[outcome]
    ,[predicted_outcome]
    ,[probability_of_acceptance]
    ,[gpa_unweighted_scaled] * 4 AS gpa_unweighted
    ,ROUND([composite_act_scaled] * 36, 0) AS composite_act
    ,[gpa_unweighted_scaled]
    ,[composite_act_scaled]
    ,[institutional_average_test_score_scaled]
    ,[Institutional_Average_Admissions_total_Percentage]
    ,[admissions_difficulty_ranking]
    ,[free_lunch]
    ,[Ethnicity_AMERICAN INDIAN OR ALASKAN NATIVE]
    ,[Ethnicity_ASIAN]
    ,[Ethnicity_BLACK OR AFRICAN AMERICAN]
    ,[Ethnicity_HISPANIC]
    ,[Ethnicity_TWOORMORERACES]
    ,[ap_average_category_3 or better]
    ,[ap_average_category_Under 3]
    ,[ib_average_category_4 or better]
    ,[ib_average_category_Under 4]
    ,[Institutional_HBCU_status_Yes]

INTO #predictions

FROM  [CollegeData].[DAT].[admissions_odds_test_set_predictions_rf_eth_fafsa_ibdp]

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#false_positives') IS NOT NULL DROP TABLE #false_positives

SELECT 
    Institution_entity_name
    ,SUM(false_positive) AS num_false_positives
    ,COUNT(Institution_entity_name) AS num_applications
    ,1.0 * SUM(false_positive) / COUNT(Institution_entity_name) AS percent_false_positives

INTO #false_positives

FROM #predictions

GROUP BY Institution_entity_name

HAVING 1.0 * SUM(false_positive) / COUNT(Institution_entity_name) > 0

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
/*
SELECT *

FROM #false_positives

ORDER BY
    percent_false_positives DESC
    */
--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------

SELECT 
    a.[local_student_id]
    ,a.[ClassOf]
    ,a.[naviance_college_id]
    ,a.[application_results_status]
    ,a.[UNITID]
    ,a.[Institution_entity_name]
    ,b.num_false_positives    
    ,b.num_applications
    ,b.percent_false_positives
    ,a.prediction_error
    ,a.prediction_error_direction
    ,a.[outcome]
    ,a.[predicted_outcome]
    ,a.[probability_of_acceptance]
    ,a.gpa_unweighted
    ,a.composite_act
    ,a.[gpa_unweighted_scaled]
    ,a.[composite_act_scaled]
    ,a.[institutional_average_test_score_scaled]
    ,a.[Institutional_Average_Admissions_total_Percentage]
    ,a.[admissions_difficulty_ranking]
    ,a.[free_lunch]
    ,a.[Ethnicity_AMERICAN INDIAN OR ALASKAN NATIVE]
    ,a.[Ethnicity_ASIAN]
    ,a.[Ethnicity_BLACK OR AFRICAN AMERICAN]
    ,a.[Ethnicity_HISPANIC]
    ,a.[Ethnicity_TWOORMORERACES]
    ,a.[ap_average_category_3 or better]
    ,a.[ap_average_category_Under 3]
    ,a.[ib_average_category_4 or better]
    ,a.[ib_average_category_Under 4]
    ,a.[Institutional_HBCU_status_Yes]

FROM 
    #predictions AS a

    RIGHT JOIN #false_positives AS b
        ON a.Institution_entity_name = b.Institution_entity_name

ORDER BY 
    percent_false_positives DESC
    ,prediction_error_direction ASC
    