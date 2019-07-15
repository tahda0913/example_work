/*
Author: THarpin
Date: 5/12/19
Query: Pull inputs for college valuation index from IPEDs data

Schemas used currently: IPEDS_2015, IPEDS_2016, IPEDS_2017_provisional
*/

--Variable for minimum number of enrollees to assign a college/demographic group a graduation rate
DECLARE @min_enrollment INT
SET @min_enrollment = 100;

/*
College institutional characteristics from latest year. 
No need to find previous info on this data, as most current is most likely to be accurate today
*/
WITH college_info_cte AS (
SELECT UNITID AS unit_id

	   ,CASE 
			WHEN Sector_of_institution LIKE '%4-year%' THEN '1'
			WHEN Sector_of_institution LIKE '%2-year%' THEN '0'
		END AS college_type

	   ,CASE
			WHEN Sector_of_institution NOT LIKE '% for-profit%' THEN 0
			WHEN Sector_of_institution LIKE '% for-profit%' THEN 1
		END AS for_profit_indicator

	   ,CASE
			WHEN Historically_Black_College_or_University IS NULL THEN NULL
			WHEN Historically_Black_College_or_University = 'Yes' THEN 1
			WHEN Historically_Black_College_or_University = 'No' THEN 0
		END AS HBCU_indicator

  FROM CollegeData.IPEDS_2017_provisional.Institutional_Characteristics

 WHERE Sector_of_institution NOT IN ('Sector unknown (not active)', 'Administrative Unit')
)
/*
Get enrollment and graduation rates for earliest year in 3 yr avg
*/
,college_enroll_1_cte AS (
--Enrollment numbers
SELECT i.unit_id
	   ,i.college_type
	   ,i.for_profit_indicator
	   ,i.HBCU_indicator
	   ,'2015' AS data_year

	   ,g.Grand_total AS total_enrollment
	   ,g.American_Indian_or_Alaska_Native_total AS AIAN_enrollment
	   ,g.Asian_total AS asian_enrollment
	   ,g.Black_or_African_American_total AS boaa_enrollment
	   ,g.Hispanic_total AS hisp_enrollment
	   ,g.Native_Hawaiian_or_Other_Pacific_Islander_total AS nhopi_enrollment
	   ,g.White_total AS white_enrollment

  FROM college_info_cte AS i

  JOIN CollegeData.IPEDS_2015.Graduation_Rates AS g
	ON i.unit_id = g.UNITID

 WHERE (i.college_type = 0 AND g.Cohort_data = 'Degree/certif-seeking students ( 2-yr institution)')
	OR (i.college_type = 1 AND g.Cohort_data = '4-year institutions, Adjusted cohort (revised cohort minus exclusions)')
)

,college_grad_1_cte AS (
--Graduate numbers (150% normal time)
SELECT i.unit_id
	   ,i.college_type
	   ,i.for_profit_indicator
	   ,i.HBCU_indicator
	   ,'2015' AS data_year

	   ,g.Grand_total AS total_graduates
	   ,g.American_Indian_or_Alaska_Native_total AS AIAN_graduates
	   ,g.Asian_total AS asian_graduates
	   ,g.Black_or_African_American_total AS boaa_graduates
	   ,g.Hispanic_total AS hisp_graduates
	   ,g.Native_Hawaiian_or_Other_Pacific_Islander_total AS nhopi_graduates
	   ,g.White_total AS white_graduates

  FROM college_info_cte AS i

  JOIN CollegeData.IPEDS_2015.Graduation_Rates AS g
	ON i.unit_id = g.UNITID

 WHERE (i.college_type = 0 AND g.Cohort_data = 'Degree/certif-seeking students ( 2-yr institution) Completers within 150% of normal time total')
    OR (i.college_type = 1 AND g.Cohort_data = '4-year institutions, Completers within 150% of normal time')
)


--Join enrollment with graduate numbers by demographic for earliest year
,grad_rates_2015_cte AS (
SELECT e.unit_id
	   ,e.college_type
	   ,e.for_profit_indicator
	   ,e.HBCU_indicator
	   ,e.data_year

	   ,e.total_enrollment
	   ,g.total_graduates
	   
	   ,e.AIAN_enrollment
	   ,g.AIAN_graduates

	   ,e.asian_enrollment
	   ,g.asian_graduates

	   ,e.boaa_enrollment
	   ,g.boaa_graduates

	   ,e.hisp_enrollment
	   ,g.hisp_graduates
	   
	   ,e.nhopi_enrollment
	   ,g.nhopi_graduates

	   ,e.white_enrollment
	   ,g.white_graduates

  FROM college_enroll_1_cte AS e

  JOIN college_grad_1_cte AS g
	ON e.unit_id = g.unit_id
)



/*
Get enrollment and graduation rates for middle year in 3 yr avg
*/

--Enrollment numbers
,college_enroll_2_cte AS (
SELECT i.unit_id
	   ,i.college_type
	   ,i.for_profit_indicator
	   ,i.HBCU_indicator
	   ,'2016' AS data_year

	   ,g.Grand_total AS total_enrollment
	   ,g.American_Indian_or_Alaska_Native_total AS AIAN_enrollment
	   ,g.Asian_total AS asian_enrollment
	   ,g.Black_or_African_American_total AS boaa_enrollment
	   ,g.Hispanic_total AS hisp_enrollment
	   ,g.Native_Hawaiian_or_Other_Pacific_Islander_total AS nhopi_enrollment
	   ,g.White_total AS white_enrollment

  FROM college_info_cte AS i

  JOIN CollegeData.IPEDS_2016.Graduation_Rates AS g
	ON i.unit_id = g.UNITID

 WHERE (i.college_type = 0 AND g.Cohort_data = 'Degree/certif-seeking students ( 2-yr institution)')
	OR (i.college_type = 1 AND g.Cohort_data = '4-year institutions, Adjusted cohort (revised cohort minus exclusions)')
)

--Graduate numbers (150% normal time)
,college_grad_2_cte AS (
SELECT i.unit_id
	   ,i.college_type
	   ,i.for_profit_indicator
	   ,i.HBCU_indicator
	   ,'2016' AS data_year

	   ,g.Grand_total AS total_graduates
	   ,g.American_Indian_or_Alaska_Native_total AS AIAN_graduates
	   ,g.Asian_total AS asian_graduates
	   ,g.Black_or_African_American_total AS boaa_graduates
	   ,g.Hispanic_total AS hisp_graduates
	   ,g.Native_Hawaiian_or_Other_Pacific_Islander_total AS nhopi_graduates
	   ,g.White_total AS white_graduates

  FROM college_info_cte AS i

  JOIN CollegeData.IPEDS_2016.Graduation_Rates AS g
	ON i.unit_id = g.UNITID

 WHERE (i.college_type = 0 AND g.Cohort_data = 'Degree/certif-seeking students ( 2-yr institution) Completers within 150% of normal time total')
    OR (i.college_type = 1 AND g.Cohort_data = '4-year institutions, Completers within 150% of normal time')
)


--Join enrollment with graduate numbers by demographic for middle year
,grad_rates_2016_cte AS (
SELECT e.unit_id
	   ,e.college_type
	   ,e.for_profit_indicator
	   ,e.HBCU_indicator
	   ,e.data_year

	   ,e.total_enrollment
	   ,g.total_graduates
	   
	   ,e.AIAN_enrollment
	   ,g.AIAN_graduates

	   ,e.asian_enrollment
	   ,g.asian_graduates

	   ,e.boaa_enrollment
	   ,g.boaa_graduates

	   ,e.hisp_enrollment
	   ,g.hisp_graduates
	   
	   ,e.nhopi_enrollment
	   ,g.nhopi_graduates

	   ,e.white_enrollment
	   ,g.white_graduates

  FROM college_enroll_2_cte AS e

  JOIN college_grad_2_cte AS g
	ON e.unit_id = g.unit_id
)


/*
Get enrollment and graduation rates for latest year in 3 yr avg
*/

--Enrollment numbers
,college_enroll_3_cte AS (
SELECT i.unit_id
	   ,i.college_type
	   ,i.for_profit_indicator
	   ,i.HBCU_indicator
	   ,'2017' AS data_year

	   ,g.Grand_total AS total_enrollment
	   ,g.American_Indian_or_Alaska_Native_total AS AIAN_enrollment
	   ,g.Asian_total AS asian_enrollment
	   ,g.Black_or_African_American_total AS boaa_enrollment
	   ,g.Hispanic_total AS hisp_enrollment
	   ,g.Native_Hawaiian_or_Other_Pacific_Islander_total AS nhopi_enrollment
	   ,g.White_total AS white_enrollment


  FROM college_info_cte AS i

  JOIN CollegeData.IPEDS_2017_provisional.Graduation_Rates AS g
	ON i.unit_id = g.UNITID

 WHERE (i.college_type = 0 AND g.Cohort_data = 'Degree/certif-seeking students ( 2-yr institution)')
	OR (i.college_type = 1 AND g.Cohort_data = '4-year institutions, Adjusted cohort (revised cohort minus exclusions)')
)


--Graduate numbers (150% normal time)
,college_grad_3_cte AS (
SELECT i.unit_id
	   ,i.college_type
	   ,i.for_profit_indicator
	   ,i.HBCU_indicator
	   ,'2017' AS data_year

	   ,g.Grand_total AS total_graduates
	   ,g.American_Indian_or_Alaska_Native_total AS AIAN_graduates
	   ,g.Asian_total AS asian_graduates
	   ,g.Black_or_African_American_total AS boaa_graduates
	   ,g.Hispanic_total AS hisp_graduates
	   ,g.Native_Hawaiian_or_Other_Pacific_Islander_total AS nhopi_graduates
	   ,g.White_total AS white_graduates


  FROM college_info_cte AS i

  JOIN CollegeData.IPEDS_2017_provisional.Graduation_Rates AS g
	ON i.unit_id = g.UNITID

 WHERE (i.college_type = 0 AND g.Cohort_data = 'Degree/certif-seeking students ( 2-yr institution) Completers within 150% of normal time total')
    OR (i.college_type = 1 AND g.Cohort_data = '4-year institutions, Completers within 150% of normal time')
)


--Join enrollment with graduate numbers by demographic for earliest year
,grad_rates_2017_cte AS (
SELECT e.unit_id
	   ,e.college_type
	   ,e.for_profit_indicator
	   ,e.HBCU_indicator
	   ,e.data_year

	   ,e.total_enrollment
	   ,g.total_graduates
	   
	   ,e.AIAN_enrollment
	   ,g.AIAN_graduates

	   ,e.asian_enrollment
	   ,g.asian_graduates

	   ,e.boaa_enrollment
	   ,g.boaa_graduates

	   ,e.hisp_enrollment
	   ,g.hisp_graduates
	   
	   ,e.nhopi_enrollment
	   ,g.nhopi_graduates

	   ,e.white_enrollment
	   ,g.white_graduates


  FROM college_enroll_3_cte AS e

  JOIN college_grad_3_cte AS g
	ON e.unit_id = g.unit_id
)

/*
Union 3 years of raw data together for aggregation
*/
,unioned_rates_cte AS (
SELECT * FROM grad_rates_2015_cte
UNION
SELECT * FROM grad_rates_2016_cte
UNION
SELECT * FROM grad_rates_2017_cte
)


/*
Find rolling avg grad rates from unioned raw tables
*/
,three_yr_enrollment_cte AS (
SELECT unit_id
	   ,college_type
	   ,for_profit_indicator
	   ,HBCU_indicator

	   ,SUM(total_enrollment) AS total_enrollment
	   ,SUM(total_graduates) AS total_grads

	   ,SUM(aian_enrollment) AS aian_enrollment
	   ,SUM(aian_graduates) AS aian_grads

	   ,SUM(asian_enrollment) AS asian_enrollment
	   ,SUM(asian_graduates) AS asian_grads
	   
	   ,SUM(boaa_enrollment) AS boaa_enrollment
	   ,SUM(boaa_graduates) AS boaa_grads

	   ,SUM(hisp_enrollment) AS hisp_enrollment
	   ,SUM(hisp_graduates) AS hisp_grads

	   ,SUM(nhopi_enrollment) AS nhopi_enrollment
	   ,SUM(nhopi_graduates) AS nhopi_grads

	   ,SUM(white_enrollment) AS white_enrollment
	   ,SUM(white_graduates) AS white_grads

  FROM unioned_rates_cte

GROUP BY unit_id
	     ,college_type
		 ,for_profit_indicator
		 ,HBCU_indicator
)

/* 
Get latest endowment for each college
*/
,endowment_cte AS (
SELECT UNITID
       ,Value_of_endowment_assets_at_the_beginning_of_the_fiscal_year AS endowment
  FROM CollegeData.IPEDS_2017_provisional.Finances_Private_Not_For_Profit_Institution

UNION 

SELECT UNITID
       ,Value_of_endowment_assets_at_the_beginning_of_the_fiscal_year AS endowment
  FROM CollegeData.IPEDS_2017_provisional.Finances_Public_Institution
)

/*
Find average grad rates over three years per university
*/
,avg_grad_rates_cte AS (
SELECT unit_id
	   ,college_type
	   ,for_profit_indicator
	   ,HBCU_indicator

	   ,CASE
			WHEN total_enrollment < @min_enrollment THEN NULL
			ELSE total_grads / (total_enrollment * 1.0) 
		END AS grad_rate

	   ,CASE
			WHEN aian_enrollment < @min_enrollment THEN NULL
			ELSE aian_grads / (aian_enrollment * 1.0) 
		END AS aian_grad_rate
	   
	   ,CASE
			WHEN asian_enrollment < @min_enrollment THEN NULL
			ELSE asian_grads / (asian_enrollment * 1.0)
		END AS asian_grad_rate

	   ,CASE
			WHEN boaa_enrollment < @min_enrollment THEN NULL
			ELSE boaa_grads / (boaa_enrollment * 1.0)
		END AS boaa_grad_rate

	   ,CASE
			WHEN hisp_enrollment < @min_enrollment THEN NULL
			ELSE hisp_grads / (hisp_enrollment * 1.0)
		END AS hisp_grad_rate

	   ,CASE
			WHEN nhopi_enrollment < @min_enrollment THEN NULL
			ELSE nhopi_grads / (nhopi_enrollment * 1.0)
		END AS nhopi_grad_rate

	   ,CASE
			WHEN white_enrollment < @min_enrollment THEN NULL
			ELSE white_grads / (white_enrollment * 1.0) 
		END AS white_grad_rate

  FROM three_yr_enrollment_cte
)

/*
Get all 5 inputs for SMI
*/
,SMI_inputs_cte AS (
SELECT g.unit_id
       
	   ,CASE
	    WHEN ISNUMERIC(s.COSTT4_A) = 0 THEN NULL
		WHEN ISNUMERIC(s.COSTT4_A) = 1 THEN CAST(s.COSTT4_A AS DECIMAL(38, 2))
		END AS average_cost_of_attendance
       
	   ,CAST(s.PCTPELL AS DECIMAL(5,4)) AS pct_pell
	   
	   ,g.grad_rate
	   
	   ,CASE
	    WHEN ISNUMERIC(s.MD_EARN_WNE_P6) = 0 THEN NULL
		WHEN ISNUMERIC(s.MD_EARN_WNE_P6) = 1 THEN CAST(s.MD_EARN_WNE_P6 AS DECIMAL(38, 2))
		END AS median_early_career_salary --use 6 years after enrollment; choice by RTC team*/
	   
	   ,e.endowment

  FROM avg_grad_rates_cte AS g

  LEFT JOIN endowment_cte AS e 
	ON e.UNITID = g.unit_id

  LEFT JOIN CollegeData.ScoreCard.selected_fields AS s
	ON s.UNITID = g.unit_id

 WHERE s.year_id = 24 --Latest available data; NULL for years 25, 26 and 27 for columns needed
)

/*
Generate output table for value rank calculation
*/
SELECT DISTINCT
	   g.unit_id

	   ,CASE
			WHEN p.PartnershipType IS NULL THEN 0
			WHEN p.PartnershipType = 'Partner' THEN 1
			ELSE 0
		END AS partner_type_indicator

	   ,g.for_profit_indicator
	   ,g.HBCU_indicator

	   ,g.grad_rate
	   ,g.aian_grad_rate
	   ,g.asian_grad_rate
	   ,g.boaa_grad_rate
	   ,g.hisp_grad_rate
	   ,g.nhopi_grad_rate
	   ,g.white_grad_rate

	   ,s.average_cost_of_attendance AS smi_aca
	   ,s.pct_pell AS smi_pctp
	   ,s.grad_rate AS smi_gr
	   ,s.median_early_career_salary AS smi_mecs
	   ,CASE
			WHEN s.endowment = 0 THEN 1
			ELSE s.endowment
		END AS smi_e

  FROM avg_grad_rates_cte AS g

  JOIN SMI_inputs_cte AS s
	ON g.unit_id = s.unit_id

LEFT JOIN collegedata.dat.UpliftPartnersAffliates AS p
	ON g.unit_id = p.UnitID