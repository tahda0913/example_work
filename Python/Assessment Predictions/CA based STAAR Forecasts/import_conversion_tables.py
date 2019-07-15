import csv
import os
import pyodbc

cnxn = pyodbc.connect('DSN=datawarehouse_ODS_CPS_Staging')
cursor = cnxn.cursor()

check_table_isnull = """
IF OBJECT_ID('ODS_CPS_STAGING.DAT.ca_staar_predictions_28_conv_table') IS NOT NULL DROP TABLE dat.ca_staar_predictions_28_conv_table
"""

sql_create = """
CREATE TABLE DAT.ca_staar_predictions_28_conv_table (
    row_id INT IDENTITY(1, 1) PRIMARY KEY
    ,test_name VARCHAR(50)
    ,ca_average INT
    ,Predicted_STAAR DECIMAL(8, 4)
)
"""

cursor.execute(check_table_isnull)
cnxn.commit()

cursor.execute(sql_create)
cnxn.commit()

sql_insert = """
INSERT INTO DAT.ca_staar_predictions_28_conv_table (
    test_name
    ,ca_average
    ,Predicted_STAAR
) VALUES (
    ?
    ,?
    ,?
)
"""

for root, dirs, files in os.walk('S:/Student Data/Analysts/Projects/CA based STAAR Forecasts/predictions/conversion_tables'):
    for file in files:
        print(f'starting load for {file}')
        with open(f'{root}/{file}', 'r') as fp:
            csv_reader = csv.reader(fp, delimiter = ',')
            next(csv_reader)
            results = []
            for row in csv_reader:
                results.append(row)

            for row in results:
                cursor.execute(sql_insert, row)
                cnxn.commit()
