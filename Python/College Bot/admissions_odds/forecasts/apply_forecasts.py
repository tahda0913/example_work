"""
Author:         Victor Faner
Date Created:   2019-05-29
Description:    Generate forecasts for next year's senior class.
"""

import pickle
from pathlib import Path

import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sqlalchemy import create_engine
from forecasts import rescale


if __name__ == '__main__':
    engine = create_engine(r'mssql+pyodbc://sql-cl-dw-pro\datawarehouse/CollegeData?driver=SQL+Server')
    query_file = Path.cwd() / 'queries' / 'class_of_2020_predictors.sql'
    with open(query_file) as f:
        sql = f.read()
    # df = pd.read_sql(sql, engine)
    df = pd.read_csv(Path.cwd()
                     / 'inputs'
                     / 'class_of_2020_inputs_20190613.csv')

    df['composite_act_scaled'] = rescale(df['composite_act'], 1, 36)
    df['gpa_unweighted_scaled'] = rescale(df['gpa_unweighted'], 0.0, 4.0)
    df['institutional_average_composite_act_scaled'] = rescale(
        df['Institutional_Average_ACT_Composite_25th_percentile_score'], 1, 36
    )
    df['institutional_average_composite_sat_scaled'] = rescale(
        df['Institutional_Average_SAT_Total_25th_percentile'], 400, 1600
    )

    # Use the higher of ACT/SAT to account for schools who only report 1
    df['institutional_average_test_score_scaled'] = df[[
        'institutional_average_composite_act_scaled',
        'institutional_average_composite_sat_scaled',
    ]].max(axis=1)

    dataset = df[[
        'StudentID',
        'ClassOf',
        'gpa_unweighted_scaled',
        'composite_act_scaled',
        'institutional_average_test_score_scaled',
        'Institutional_Average_Admissions_total_Percentage',
        # 'admissions_difficulty_ranking',
        # 'Ethnicity',
        # 'Institutional_HBCU_status',
        # 'free_lunch',
    ]].dropna(how='any')
    # dataset = pd.get_dummies(dataset).drop(
    #     [
    #         'Ethnicity_WHITE',
    #         'Institutional_HBCU_status_No',
    #     ], axis=1
    # )

    x_data = dataset.drop(['StudentID', 'ClassOf'], axis=1)

    pkl = Path.cwd() / 'model_evaluation' / 'rf' / 'random_forest_model.pkl'
    with open(pkl, 'rb') as f:
        rf = pickle.load(f)

    probabilities = rf.predict_proba(x_data)[:, 1]
    dataset['probability'] = probabilities

    df = df.merge(dataset['probability'], how='left', left_index=True,
                  right_index=True)
    df.to_csv(Path.cwd() / 'class_of_2020_predictions.csv', index=False)
