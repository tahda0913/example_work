"""
Author:         Victor Faner
Date Created:   2019-05-15
Description:    Generate forecasts of admissions odds and save off
                predictions/model evaluation metrics.
"""

import pickle
from pathlib import Path
from datetime import date

import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import confusion_matrix, classification_report
from sqlalchemy import create_engine


def rescale(input, min, max):
    """
    Convert data to min-max scale

    :param input:       array-like, input data
    :param min:         numeric, lowest value of data
    :param max:         numeric, highest value of data

    :return output:     array, rescaled data
    """
    output = (
        (input - min)
        / (max - min)
    )

    return output


if __name__ == '__main__':
    engine = create_engine(r'mssql+pyodbc://sql-cl-dw-pro\datawarehouse/CollegeData?driver=SQL+Server')
    query_file = Path.cwd() / 'queries' / 'get_predictors.sql'
    with open(query_file) as f:
        sql = f.read()
    # df = pd.read_sql(sql, engine)
    df = pd.read_csv(Path.cwd() / 'inputs' / 'input_data_backup_20190523.csv')

    df['outcome'] = df['application_results_status'] != 'denied'
    df['composite_act_scaled'] = rescale(df['composite_act'], 1, 36)
    df['total_sat_scaled'] = rescale(df['total_sat'], 400, 1600)
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
        'local_student_id',
        'outcome',
        'ClassOf',
        'gpa_unweighted_scaled',
        'composite_act_scaled',
        'institutional_average_test_score_scaled',
        'Institutional_Average_Admissions_total_Percentage',
        'admissions_difficulty_ranking',
        'Ethnicity',
        'Institutional_HBCU_status',
        'free_lunch',
    ]].dropna(how='any')
    dataset = pd.get_dummies(dataset).drop(
        [
            'Ethnicity_WHITE',
            'Institutional_HBCU_status_No',
        ], axis=1
    )

    y = dataset['outcome']
    x = dataset.drop(['local_student_id', 'outcome', 'ClassOf'], axis=1)

    # Split on student IDs to prevent students showing up in both sets
    student_ids = dataset['local_student_id'].unique()
    train_ids, test_ids = train_test_split(student_ids, random_state=42)

    x_train = x[dataset['local_student_id'].isin(train_ids)]
    y_train = y[dataset['local_student_id'].isin(train_ids)]
    x_test = x[dataset['local_student_id'].isin(test_ids)]
    y_test = y[dataset['local_student_id'].isin(test_ids)]

    rf = RandomForestClassifier(n_estimators=20, max_depth=20, random_state=42)
    rf.fit(x_train, y_train)

    probabilities = rf.predict_proba(x_test)
    preds = rf.predict(x_test)
    report = classification_report(y_test, preds, labels=[True, False])
    feature_importances = rf.feature_importances_
    cm = confusion_matrix(y_test, preds, labels=[True, False])

    today = date.today().strftime(format='%Y_%m_%d')
    out_dir = Path.cwd() / 'model_evaluation' / 'rf'

    pickle.dump(rf, open(out_dir / 'random_forest_model_eth_fafsa_ibdp.pkl', 'wb'))

    with open(out_dir / 'rf_classification_report_eth_fafsa_ibdp.txt', 'w') as f:
        f.write(str(report))

    weights = pd.DataFrame({'variable': x.columns,
                            'feature_importance': feature_importances})
    weights.sort_values(by='feature_importance', ascending=False)
    weights.to_csv(out_dir / f'admissions_odds_weights_rf_eth_fafsa_ibdp_{today}.csv', index=False)

    cm = pd.DataFrame(data=cm, columns=['accepted_predicted',
                                        'denied_predicted'])
    cm['outcome'] = ['accepted_actual', 'denied_actual']
    cm = cm[['outcome', 'accepted_predicted', 'denied_predicted']]
    cm.to_csv(out_dir / f'admissions_odds_confusion_matrix_rf_eth_fafsa_ibdp_{today}.csv', index=False)

    train = x_train.merge(y_train, how='left', left_index=True,
                          right_index=True)
    train = train.merge(df[[
                            'local_student_id',
                            'ClassOf',
                            'naviance_college_id',
                            'application_results_status',
                            'UNITID',
                            'Institution_entity_name',
                        ]], how='left', left_index=True, right_index=True)
    train.to_csv(out_dir / f'admissions_odds_training_data_rf_eth_fafsa_ibdp_{today}.csv', index=False)

    predictions = x_test.merge(y_test, how='left', left_index=True,
                               right_index=True)
    predictions['predicted_outcome'] = preds
    predictions['probability_of_acceptance'] = probabilities[:, 1]
    predictions = predictions.merge(df[[
                                        'local_student_id',
                                        'ClassOf',
                                        'naviance_college_id',
                                        'application_results_status',
                                        'UNITID',
                                        'Institution_entity_name',
                                    ]], how='left', left_index=True,
                                    right_index=True)
    predictions.to_csv(out_dir / f'admissions_odds_test_set_predictions_rf_eth_fafsa_ibdp_{today}.csv',
                       index=False)
