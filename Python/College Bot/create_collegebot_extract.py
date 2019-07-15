"""
Author: tharpin
Script: Create data extract for college_bot dashboard
Date: 5/19/19
"""

import pandas as pd
import sqlalchemy
from sqlalchemy import create_engine

engine = create_engine('mssql+pyodbc://tharpin@datawarehouse_ods_cps')

with open('other_queries/get_student_names.sql') as fp:
    student_info_query = fp.read()

df_predictions = pd.read_csv('admissions_odds/forecasts/class_of_2020_predictions.csv')
df_values = pd.read_csv('college_valuation/college_values_extract.csv')
df_admissions = pd.read_csv('admissions_odds/college_ranking/college_admissions_difficulty_ranks.csv')
df_student_info = pd.read_sql(student_info_query, engine)

df_scholar_info = pd.DataFrame({'student_id': df_predictions['StudentID']
                               ,'school': df_predictions['SchoolName']
                               ,'race': df_predictions['Race']
                               ,'gpa_unweighted': df_predictions['gpa_unweighted']
                               ,'composite_act': df_predictions['composite_act']
                               ,'unit_id': df_predictions['UNITID']
                               ,'college_name': df_predictions['Institution_entity_name']
                               ,'admissions_difficulty_level': df_predictions['admissions_difficulty_ranking']
                               ,'probability_of_acceptance': df_predictions['probability']
                               })

df_college_bot_extract = df_scholar_info.merge(df_values.iloc[:, :], how='left', on='unit_id')

df_college_bot_extract = df_college_bot_extract.merge(df_student_info.iloc[:, :], how='left', on='student_id')

df_college_bot_extract.to_csv('college_bot_extract.csv', index=False)
