import pyodbc
import csv
from sys import argv

### Interaction variables for users who run the program
script, csv_name = argv
csv_location = f'S:/Student Data/Analysts/Projects/naviance_decomposition/College Acceptance Status/biweekly_naviance_files/{csv_name}'
table_name = 'DAT.naviance_cas_biweekly_load'


### Setup connection to SQL database ###
#REDACTED cnxn = pyodbc.connect("""
                      # DRIVER={SQL SERVER};
                      # SERVER=;
                      # DATABASE=;
                      # """)
cursor = cnxn.cursor()


### Function to create staging table in database
def create_staging_table(table_name):
    """
    Creates a table in the CollegeData_STAGING database according to the name fed into function
    """
    null_test = 'IF OBJECT_ID(' + '\'' + table_name + '\'' + ') IS NOT NULL DROP TABLE' + ' ' + table_name
    cursor.execute(null_test)

    query = f""" CREATE TABLE {table_name} (
        row_id INT IDENTITY(1,1)
        ,naviance_student_id VARCHAR(15)
        ,local_student_id VARCHAR(10)
        ,naviance_school_id VARCHAR(15)
        ,local_school_id VARCHAR(10)
        ,naviance_college_id VARCHAR(20)
        ,ceeb_code VARCHAR(8)
        ,application_status VARCHAR(50)
        ,application_type VARCHAR(10)
        ,application_results_status VARCHAR(50)
        ,active_flag BIT
        ,file_date DATE
    );
    """
    return cursor.execute(query)

### Function to create a list of data from bi-weekly naviance CAS CSV
def create_insert_list(csv_location):
    with open(csv_location, 'r') as fp:
        csv_reader = csv.reader(fp, delimiter = ',')
        next(csv_reader)
        data = [x for x in csv_reader]

    return data

### Variable which houses the SQL insertion query
insertion_query = f"""INSERT INTO {table_name} (
        naviance_student_id
        ,local_student_id
        ,naviance_school_id
        ,local_school_id
        ,naviance_college_id
        ,ceeb_code
        ,application_status
        ,application_type
        ,application_results_status
        ,active_flag
        ,file_date
    ) VALUES (
        ?
        ,?
        ,?
        ,?
        ,?
        ,?
        ,?
        ,?
        ,?
        ,?
        ,?
    );
"""

### Looks through each cell from csv file and replaces any blank fields with NULLs
def clean_data(data):
    def clean_parameter(parameter):
        if parameter == '':
            parameter = None

        return parameter

    clean_data = []
    for row in data:
        cleaned_row = [clean_parameter(x) for x in row]
        clean_data.append(cleaned_row)

    return clean_data

### Looks through a list of data provided to the function and removes any canceled records that still
### have a matching active record
def duplicate_parser(csv):
    final_list = []
    final_list_identifiers = []
    active_identifiers = [f'{row[1]}||{row[4]}' for row in csv if row[9] == '1']
    canceled_rows = [row for row in csv if row[9] == '0']
    active_rows = [row for row in csv if row[9] == '1']

    for row in canceled_rows:
        if f'{row[1]}||{row[4]}' in active_identifiers:
            continue

        elif f'{row[1]}||{row[4]}' in final_list_identifiers:
            continue

        else:
            final_list_identifiers.append(f'{row[1]}||{row[4]}')
            final_list.append(row)


    for row in active_rows:
        if f'{row[1]}||{row[4]}' in final_list_identifiers:
            continue

        else:
            final_list_identifiers.append(f'{row[1]}||{row[4]}')
            final_list.append(row)

    return final_list


### Script instructions, step by step. Create table, set up insert data, insert into table
print("""Beginning Naviance College Application Status Procedure
.
.
.""")

print(f'Data from {csv_name} will be loaded into CollegeData_STAGING.{table_name}.')
input('Enter to continue or CTRL-C to Cancel')

create_staging_table(table_name)
cnxn.commit()

data = create_insert_list(csv_location)
clean_data = clean_data(data)
final_data = duplicate_parser(clean_data)

for i, row in enumerate(final_data):
    print(f'Inserting row number {i + 1}')
    cursor.execute(insertion_query, row)

cnxn.commit()

print('Loaded Successfully. Ending Procedure')
