import pyodbc
import csv

cnxn = pyodbc.connect('DSN=datawarehouse_ODS_CPS_Staging')
cursor = cnxn.cursor()


check_table_isnull = """IF OBJECT_ID('DAT.staar_scale_cut_scores') IS NOT NULL DROP TABLE dat.staar_scale_cut_scores"""

cursor.execute(check_table_isnull)
cnxn.commit()

sql_create = """
CREATE TABLE DAT.staar_scale_cut_scores (
    row_id INT IDENTITY(1, 1) PRIMARY KEY
    ,year_id INT
    ,academic_subject VARCHAR(25)
    ,course_level VARCHAR(15)
    ,approaches_cut_score INT
    ,meets_cut_score INT
    ,masters_cut_score INT
    ,grade_level INT
    ,title VARCHAR(20)
)
"""

cursor.execute(sql_create)
cnxn.commit()

sql_insert = """
INSERT INTO dat.staar_scale_cut_scores (
    year_id
    ,academic_subject
    ,course_level
    ,approaches_cut_score
    ,meets_cut_score
    ,masters_cut_score
    ,grade_level
    ,title
) VALUES (
    ?
    ,?
    ,?
    ,?
    ,?
    ,?
    ,?
    ,?
)
"""

with open('S:/Student Data/Analysts/Projects/CA based STAAR Forecasts/scale_cut_scores.csv') as fp:
    csv_reader = csv.reader(fp, delimiter = ',')
    next(csv_reader)

    results = []
    for row in csv_reader:
        results.append(row)

    for row in results:
        cursor.execute(sql_insert, row)
        cnxn.commit()
