USE [RPA]
GO

/****** Object:  UserDefinedFunction [rpt].[fnDemographics]    Script Date: 3/4/2020 8:48:39 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO













-- =============================================
-- Author:		Trevor Harpin
-- Create date: 11/14/2019
-- Description:	Demographics Function -- Pulls demog indicators for students at given date
-- =============================================
ALTER FUNCTION [rpt].[fnDemographics] 
(	
	@date DATE
)
RETURNS TABLE 
AS
RETURN 
(
SELECT st.OTHER_ID AS LASID
	   ,n.LAST_NAME AS last_name
	   ,n.FIRST_NAME AS first_name
	   ,n.GENDER AS gender
	   ,COALESCE(sch_cross.SCHOOLS, sch.entity_name) AS [entity_name]

	   ,CASE
			WHEN st_ew.SCHOOL_ID = 'NEW' THEN 'Newcomer Academy'
			ELSE COALESCE(sch_cross.SCHOOLS, sch.entity_name)
		END AS school_name

	   ,r.RACE_LDESC AS student_race
	   
	   ,CASE
			WHEN st_ew.student_type_code = 'AA'  THEN 'Advanced Acad'
			WHEN st_ew.student_type_code = 'B'   THEN 'Bilingual'
			WHEN st_ew.student_type_code = 'BEL' THEN 'Bilingual (Exited EL)'
			WHEN st_ew.student_type_code = 'BIN' THEN 'Bilingual Inclusion'
			WHEN st_ew.student_type_code = 'DEI' THEN 'Dual Language English Inclusion'
			WHEN st_ew.student_type_code = 'DLE' THEN 'Dual Language English'
			WHEN st_ew.student_type_code = 'DLS' THEN 'Dual Language Spanish'
			WHEN st_ew.student_type_code = 'DSI' THEN 'Dual Language Spanish Inclusion'
			WHEN st_ew.student_type_code = 'E'   THEN 'ESL - Sheltered'
			WHEN st_ew.student_type_code = 'EI'  THEN 'ESL Inclusion'
			WHEN st_ew.student_type_code = 'ELC' THEN 'ELC'
			WHEN st_ew.student_type_code = 'IE'  THEN 'Inclusion & ELC'
			WHEN st_ew.student_type_code = 'INC' THEN 'Regular Ed. Inclusion'
			WHEN st_ew.student_type_code = 'NEW' THEN 'ESL Newcomer'
			WHEN st_ew.student_type_code = 'PKE' THEN 'PK Eval Team'
			WHEN st_ew.student_type_code = 'R'   THEN 'Regular Ed.'
			WHEN st_ew.student_type_code = 'SB'  THEN 'Sped Bilingual'
			WHEN st_ew.student_type_code = 'SE'  THEN 'SSC & ELC'
			WHEN st_ew.student_type_code = 'SSC' THEN 'Sped Self Cont'
			WHEN st_ew.student_type_code = 'U'   THEN 'Unknown'
		END AS student_type
	   
	   ,CASE
			WHEN lep_clas.SC_RECORD_TYPE IS NOT NULL THEN 1
			ELSE 0
		END AS LEP_indicator

	   ,CASE
			WHEN ene.initial_waiver_date IS NULL AND ene.waiver_renewal_date IS NULL THEN 0
			WHEN CAST(ene.initial_waiver_date AS DATE) >= DATEFROMPARTS(CASE 
																			WHEN MONTH(@date) BETWEEN 7 AND 12 THEN YEAR(@date)
																			ELSE YEAR(@date) - 1 END
																		,'1', '1') THEN 1
			WHEN CAST(ene.waiver_renewal_date AS DATE) >= DATEFROMPARTS(CASE
																			WHEN MONTH(@date) BETWEEN 7 AND 12 THEN YEAR(@date)
																			ELSE YEAR(@date) - 1 END
																		,'9', '1') THEN 1
			ELSE 0
		END AS ENE_indicator

	   ,CASE
			WHEN sped_clas.SC_RECORD_TYPE IS NOT NULL THEN 1
			ELSE 0
		END AS spec_ed_indicator

	   ,dbo.UFN_SEPARATES_COLUMNS(iep.INT_FLD, 6, ';') AS alt_assessment_indicator

	   ,CASE
			WHEN sec504.s504_IAP_BEG_DATE IS NOT NULL THEN 1
			ELSE 0
		END AS sec_504_indicator

	   ,CASE
			WHEN frl.FS_LUN_CODE_ID IS NULL THEN NULL
			WHEN frl.FS_LUN_CODE_ID IN ('A', 'F', 'D') THEN 'F'
			WHEN frl.FS_LUN_CODE_ID IN ('B', 'R') THEN 'R'
			ELSE 'P'
		END AS frl_code

	   ,n.ETHNICITY_HISP_X AS Hispanic
	   ,SUBSTRING(n.FED_RACE_FLAGS, 1, 1) AS Native_Amer_Alaskan
	   ,SUBSTRING(n.FED_RACE_FLAGS, 2, 1) AS Asian
	   ,SUBSTRING(n.FED_RACE_FLAGS, 3, 1) AS African_American
	   ,SUBSTRING(n.FED_RACE_FLAGS, 4, 1) AS Hawaiian_Pacific_Islander
	   ,SUBSTRING(n.FED_RACE_FLAGS, 5, 1) AS White

  FROM rpa.sky.STUDENT AS st

  JOIN rpa.sky.NAME AS n
	ON st.NAME_ID = n.NAME_ID

  JOIN rpa.sky.RACE AS r
	ON n.RACE_CODE = r.RACE_CODE

  JOIN (
		SELECT sew.STUDENT_ID
			   ,sew.[ENTITY_ID] AS sch_id
			   ,sew.SCHOOL_ID
			   ,sew.EW_DATE AS entry_date
			   ,ISNULL(sew.withdrawal_date, '2100-01-01') AS withdrawal_date
			   ,sew.TYPE_STUDENT_ID AS student_type_code

		  FROM rpa.sky.student_ew AS sew

		  JOIN (
				SELECT STUDENT_ID
					   ,MAX(ew_date) AS latest_entry

				  FROM rpa.sky.student_ew 

				 WHERE @date BETWEEN EW_DATE AND ISNULL(WITHDRAWAL_DATE, '2100-01-01')
				   AND CASE
							WHEN MONTH(ew_date) IN ('07', '08', '09', '10', '11', '12') THEN YEAR(ew_date) + 1
							ELSE YEAR(ew_date) 
						END = CASE
								  WHEN MONTH(@date) IN ('07', '08', '09', '10', '11', '12') THEN YEAR(@date) + 1
								  ELSE YEAR(@date)
							   END

				GROUP BY STUDENT_ID
			    ) AS m_entry
			ON sew.STUDENT_ID = m_entry.STUDENT_ID
				AND sew.EW_DATE = m_entry.latest_entry
	   ) AS st_ew
	ON st_ew.STUDENT_ID = st.STUDENT_ID
		AND ISNULL(st_ew.WITHDRAWAL_DATE, '2100-01-01') >= @date

   JOIN rpa.sky.ENTITY AS sch
	 ON st_ew.sch_id = sch.[ENTITY_ID]

LEFT JOIN [DATA VAULT].dbo.schoolcodexwalk AS sch_cross
	ON sch.[ENTITY_ID] = sch_cross.SchoolDISTRICT
		AND CASE WHEN SchoolDISTRICT = 193 THEN 'OPEN' ELSE SCHOOLSTATUS END = SCHOOLSTATUS

LEFT JOIN rpa.sky.STUDENT_CLASSIFICATIONS AS lep_clas
	ON st.STUDENT_ID = lep_clas.STUDENT_ID
		AND lep_clas.SC_RECORD_TYPE = 'RILEP'
		AND @date BETWEEN lep_clas.SC_STR_DATE AND COALESCE(lep_clas.SC_END_DATE, st_ew.withdrawal_date, '2100-01-01')

LEFT JOIN rpa.el.ene_waiver_dates AS ene
	ON st.OTHER_ID = ene.LASID

LEFT JOIN rpa.sky.STUDENT_CLASSIFICATIONS AS sped_clas
	ON st.STUDENT_ID = sped_clas.STUDENT_ID
		AND sped_clas.SC_RECORD_TYPE = 'SE'
		AND @date BETWEEN sped_clas.SC_STR_DATE AND COALESCE(sped_clas.SC_END_DATE, st_ew.withdrawal_date, '2100-01-01')

LEFT JOIN rpa.sky.SE_IEP AS iep
	ON st.STUDENT_ID = iep.STUDENT_ID
		AND iep.IEP_WIP = 0
		AND @date BETWEEN iep.IEP_BEG_DATE AND iep.IEP_END_DATE

LEFT JOIN (
		   SELECT s504.STUDENT_ID
			      ,s504.S504_IAP_BEG_DATE
				  ,s504.S504_IAP_END_DATE
		    
			 FROM rpa.sky.STUDENT_SECTION_504 AS s504
			 
			 JOIN (
				   SELECT STUDENT_ID
					      ,MAX(S504_IAP_BEG_DATE) AS latest_504_date

				     FROM rpa.sky.STUDENT_SECTION_504

					WHERE S504_IAP_BEG_DATE <= @date

				  GROUP BY STUDENT_ID
				  ) AS latest_504
				ON latest_504.STUDENT_ID = s504.STUDENT_ID
					AND latest_504.latest_504_date = s504.S504_IAP_BEG_DATE
					AND @date BETWEEN S504_IAP_BEG_DATE AND ISNULL(S504_IAP_END_DATE, '2100-01-01')

		  ) AS sec504
	   ON st.STUDENT_ID = sec504.STUDENT_ID

LEFT JOIN rpa.sky.lunch_code_transactions AS frl
			ON frl.SKY_ID = st.STUDENT_ID
				AND @date BETWEEN frl.FS_START_DATE AND ISNULL(frl.FS_END_DATE, '2100-01-01')

)













GO


