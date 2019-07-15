"""
Author: Tharpin
Date: 12/18/2018
"""
# Note: This script converted from jupyter notebook. Some intermediate visualizations and checks of data have been removed

import numpy as np
import pandas as pd
import seaborn as sb
import matplotlib.pyplot as plt
from sklearn.linear_model import LinearRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error

#Get input data from csv file pulled from SQL database
df = pd.read_csv('S:/Student Data/Analysts/Projects/CA based STAAR Forecasts/result_csvs/ca_8th_algebra1_27.csv')

#Average assessment results from two distinct administrations. Each admin covers half of the standards tested at EOY
df['ca_average'] = (df['ca1_overall_score'] + df['ca2_overall_score']) / 2

#Declare regression variables
X = df['ca_average'].values.reshape(-1, 1)
Y = np.log(df['scale_score']).values.reshape(-1, 1)

#Split data into test/train sets
X_train, X_test, y_train, y_test = train_test_split(X, Y, test_size = 0.3, random_state = 0)

#Declare regressor variable and fit data
regressor = LinearRegression()
regressor.fit(X_train, y_train)

#Generate predicted EOY assessment results for test data and score model
y_pred = regressor.predict(X_test)
regressor.score(X_test, y_test)

#Additional model validation variables
lin_mse = mean_squared_error(y_pred, y_test)
lin_rmse = np.sqrt(lin_mse)

#Send results to dataframe for visual inspection
results = pd.DataFrame({'ca_score':X_test.flatten(),
                        'STAAR_score':np.exp(y_test).flatten(),
                        'Predicted_STAAR':np.exp(y_pred).flatten()})
results['residuals'] = results['STAAR_score'] - results['Predicted_STAAR']

#Generate plot of actual vs predicted scores for visual inspection
sb.regplot(x='STAAR_score', y='Predicted_STAAR', data=results, scatter=True)


#Create array of possible test scores (1-100), and then fit to model to generate a lookup chart for campus staff
X_1 = np.arange(1, 101).reshape(-1, 1)

conv_y = regressor.predict(X_1)

conv_results = pd.DataFrame({'test_name':'Algebra 1',
                             'ca_average':X_1.flatten(),
                             'Predicted_STAAR':np.exp(conv_y).flatten()})

df2 = pd.read_csv('S:/Student Data/Analysts/Projects/CA based STAAR Forecasts/result_csvs/ca_8th_algebra1_28.csv')
df2.columns = ['local_student_id', 'ca1_overall', 'ca2_overall', 'ca_average']


#Declare variables for prediction of current year results, run through model, and export to csv file
X_2 = df2['ca_average'].values.reshape(-1, 1)

cy_pred = regressor.predict(X_2)

cy_results = pd.DataFrame({'local_student_id':df2['local_student_id'],
                           'test_name':'Algebra 1',
                           'ca1_overall':(df2['ca1_overall'] * 100),
                           'ca2_overall':(df2['ca2_overall'] * 100),
                           'ca_average':X_2.flatten(),
                           'Predicted_STAAR':np.exp(cy_pred).flatten()})

cy_results.to_csv('S:/Student Data/Analysts/Projects/CA based STAAR Forecasts/predictions/algebra_1_predictions.csv', index=False)
