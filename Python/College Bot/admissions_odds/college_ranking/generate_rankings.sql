/*

Author:         Victor Faner
Date created:   2019-05-09
Description:    Rank colleges on admissions difficulty using test requirements
                and admissions rates.
*/

--------------------------------------------------------------------------------
--  Calculate 3-year average ACTs
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#act') IS NOT NULL DROP TABLE #act

SELECT
    y2017.UNITID
    ,(
        y2017.ACT_Composite_25th_percentile_score
        + y2016.ACT_Composite_25th_percentile_score
        + y2015.ACT_Composite_25th_percentile_score
    ) / 3 AS Average_ACT_Composite_25th_percentile_score

INTO #act

FROM 
    CollegeData.IPEDS_2017_provisional.Admissions_and_Test_Scores AS y2017
    FULL OUTER JOIN CollegeData.IPEDS_2016.Admissions_and_Test_Scores AS y2016
        ON y2017.UNITID = y2016.UNITID
    FULL OUTER JOIN CollegeData.IPEDS_2015.Admissions_and_Test_Scores AS y2015
        ON y2017.UNITID = y2015.UNITID

--------------------------------------------------------------------------------
--  Get raw SAT total scores
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#raw_sat') IS NOT NULL DROP TABLE #raw_sat

SELECT
    y2017.UNITID
    ,(
        y2017.SAT_Math_25th_percentile_score 
        + y2017.SAT_Evidence_Based_Reading_and_Writing_25th_percentile_score 
     ) AS SAT_Total_25th_percentile_2017
    ,(
        y2016.SAT_Math_25th_percentile_score 
        + y2016.SAT_Critical_Reading_25th_percentile_score
    ) AS SAT_Total_25th_percentile_2016
    ,(
        y2015.SAT_Math_25th_percentile_score
        + y2015.SAT_Critical_Reading_25th_percentile_score 
        + y2015.SAT_Writing_25th_percentile_score
    ) AS SAT_Total_25th_percentile_2015

INTO #raw_sat

FROM
    CollegeData.IPEDS_2017_provisional.Admissions_and_Test_Scores AS y2017
    FULL OUTER JOIN CollegeData.IPEDS_2016.Admissions_and_Test_Scores AS y2016
        ON y2017.UNITID = y2016.UNITID
    FULL OUTER JOIN CollegeData.IPEDS_2015.Admissions_and_Test_Scores AS y2015
        ON y2017.UNITID = y2015.UNITID

--------------------------------------------------------------------------------
--  Convert 2015/2016 SAT scores to 2017 range
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#converted_sat') IS NOT NULL DROP TABLE #converted_sat

SELECT
    a.UNITID
    ,a.SAT_Total_25th_percentile_2017
    ,b.New_SAT_Total_Score_400_1600 AS SAT_Total_25th_percentile_2016
    ,c.New_SAT_Total_Score_400_1600 AS SAT_Total_25th_percentile_2015

INTO #converted_sat

FROM 
    #raw_sat AS a
    FULL OUTER JOIN CollegeData.DAT.OldToNewSATcrosswalk_total_1600 AS b
        ON a.SAT_Total_25th_percentile_2016 = b.Old_SAT_Total_Score_400_1600
    FULL OUTER JOIN CollegeData.DAT.OldToNewSATcrosswalk_total_2400 AS c
        ON a.SAT_Total_25th_percentile_2015 = c.Old_SAT_Total_Score_600_2400

--------------------------------------------------------------------------------
--  Calculate 3-year average sats
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#sat') IS NOT NULL DROP TABLE #sat

SELECT
    UNITID
    ,(
        SAT_Total_25th_percentile_2017
        + SAT_Total_25th_percentile_2016
        + SAT_Total_25th_percentile_2015
    ) / 3 AS Average_SAT_Total_25th_percentile

INTO #sat

FROM #converted_sat

--------------------------------------------------------------------------------
--  Calculate 3-year Admissions Percentages
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#admissions_percentages') IS NOT NULL DROP TABLE #admissions_percentages

SELECT
    y2017.UNITID
    ,(
        (y2017.Admissions_total / y2017.Applicants_total) 
        + (y2016.Admissions_total / y2016.Applicants_total) 
        + (y2015.Admissions_total / y2015.Applicants_total)
    ) / 3 AS Average_Admissions_total_Percentage
    ,(
        (y2017.Admissions_men / y2017.Applicants_men) 
        + (y2016.Admissions_men / y2016.Applicants_men) 
        + (y2015.Admissions_men / y2015.Applicants_men)
    ) / 3 AS Average_Admissions_mens_Percentage
    ,(
        (y2017.Admissions_women / y2017.Applicants_women) 
        + (y2016.Admissions_women / y2016.Applicants_women) 
        + (y2015.Admissions_women / y2015.Applicants_women)
    ) / 3 AS Average_Admissions_women_Percentage
        

INTO #admissions_percentages

FROM 
    CollegeData.IPEDS_2017_provisional.Admissions_and_Test_Scores AS y2017
    FULL OUTER JOIN CollegeData.IPEDS_2016.Admissions_and_Test_Scores AS y2016
        ON y2017.UNITID = y2016.UNITID
    FULL OUTER JOIN CollegeData.IPEDS_2015.Admissions_and_Test_Scores AS y2015
        ON y2017.UNITID = y2015.UNITID

--------------------------------------------------------------------------------
--  Join to 2017 Institutional Data
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#full_table') IS NOT NULL DROP TABLE #full_table

SELECT 
    a.* 

    ,#act.Average_ACT_Composite_25th_percentile_score

    ,#sat.Average_SAT_Total_25th_percentile

    ,(#act.Average_ACT_Composite_25th_percentile_score - 1) 
    / 35 AS Normalized_Average_ACT_Composite_25th_percentile_score
    ,(#sat.Average_SAT_Total_25th_percentile - 400) 
    / 1200 AS Normalized_Average_SAT_Total_25th_percentile

    ,#admissions_percentages.Average_Admissions_total_Percentage
    ,#admissions_percentages.Average_Admissions_mens_Percentage
    ,#admissions_percentages.Average_Admissions_women_Percentage

INTO #full_table

FROM 
    CollegeData.IPEDS_2017_provisional.Institutional_Characteristics AS a
    LEFT JOIN #act
        ON a.UNITID = #act.UNITID

    LEFT JOIN #sat
        ON a.UNITID = #sat.UNITID

    LEFT JOIN #admissions_percentages
        ON a.UNITID = #admissions_percentages.UNITID

--------------------------------------------------------------------------------
--  Calculate ranking scores
--------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#ranking_scores') IS NOT NULL DROP TABLE #ranking_scores

SELECT 
    *
    ,(
        .25 * (1 - ISNULL(Average_Admissions_total_Percentage, 1))
        + .75 * ISNULL((
            ISNULL(Normalized_Average_ACT_Composite_25th_percentile_score, Normalized_Average_SAT_Total_25th_percentile)
            + ISNULL(Normalized_Average_SAT_Total_25th_percentile, Normalized_Average_ACT_Composite_25th_percentile_score)
        ) / 2, 0)
    ) AS ranking_score

INTO #ranking_scores

FROM #full_table

--------------------------------------------------------------------------------
--  Bin ranking scores to generate rankings
--------------------------------------------------------------------------------
IF OBJECT_ID('CollegeData.DAT.college_rankings') IS NOT NULL DROP TABLE CollegeData.DAT.college_rankings

SELECT 
    *
    ,CASE 
        WHEN ranking_score >= .84 THEN 8
        WHEN ranking_score >= .75 AND ranking_score < .84 THEN 7
        WHEN ranking_score >= .60 AND ranking_score < .75 THEN 6
        WHEN ranking_score >= .50 AND ranking_score < .60 THEN 5
        WHEN ranking_score >= .43 AND ranking_score < .50 THEN 4
        WHEN ranking_score >= .30 AND ranking_score < .43 THEN 3
        WHEN ranking_score >= .20 AND ranking_score < .30 THEN 2
        WHEN ranking_score > 0 AND ranking_score < .20 THEN 1
        ELSE 0

        END AS admissions_difficulty_ranking

INTO CollegeData.DAT.college_rankings

FROM #ranking_scores