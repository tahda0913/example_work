import pyodbc
import os
import csv

cnxn = pyodbc.connect('DSN=datawarehouse_ODS_CPS_Staging')
cursor = cnxn.cursor()

check_table_isnull = """IF OBJECT_ID('ODS_CPS_STAGING.DAT.ca_staar_predictions_28') IS NOT NULL DROP TABLE ODS_CPS_STAGING.DAT.ca_staar_predictions_28"""

sql_create = """
CREATE TABLE ODS_CPS_STAGING.DAT.ca_staar_predictions_28 (
    row_id INT IDENTITY(1, 1) PRIMARY KEY
    ,local_id VARCHAR(10)
    ,test_name VARCHAR(50)
    ,ca1_overall VARCHAR(20)
    ,ca2_overall VARCHAR(20)
    ,ca_average VARCHAR(20)
    ,predicted_STAAR VARCHAR(20)
)
"""

sql_insert = """
INSERT INTO ODS_CPS_STAGING.DAT.ca_staar_predictions_28 (
    local_id
    ,test_name
    ,ca1_overall
    ,ca2_overall
    ,ca_average
    ,predicted_STAAR
) VALUES (
    ?
    ,?
    ,?
    ,?
    ,?
    ,?
)
"""

cursor.execute(check_table_isnull)
cnxn.commit()

cursor.execute(sql_create)
cnxn.commit()

for root, dir, files in os.walk('S:/Student Data/Analysts/Projects/CA based STAAR Forecasts/predictions'):
    for file in files:
        print(f'Starting load for {file}')
        with open(f'{root}/{file}', 'r') as fp:
            csv_reader = csv.reader(fp, delimiter = ',')
            next(csv_reader)
            results = []
            for row in csv_reader:
                results.append(row)

            for row in results:
                cursor.execute(sql_insert, row)
                cnxn.commit()
