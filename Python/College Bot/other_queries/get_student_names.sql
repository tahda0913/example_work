DECLARE @roster_date DATE
SET @roster_date = CASE
					  WHEN MONTH(GETDATE()) IN (6, 7) THEN DATEFROMPARTS(YEAR(GETDATE()), 5, 1)
					  ELSE GETDATE()
				   END

SELECT CAST(studentid AS BIGINT) AS student_id
	   ,studentname AS student_name

  FROM ODS_CPS.rpt.vStudent

 WHERE @roster_date BETWEEN schoolentrydate AND schoolexitdate
 