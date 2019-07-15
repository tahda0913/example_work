import pandas as pd
import sklearn
from sklearn.preprocessing import MinMaxScaler
import numpy as np

import sqlalchemy
import pyodbc
from sqlalchemy import create_engine

### Create DB connection and read get_inputs query
engine = create_engine('mssql+pyodbc://tharpin@datawarehouse_ods_cps')
query_loc = 'queries/college_values_smi.sql'

with open(query_loc, 'r') as fp:
    query = fp.read()

df_inputs = pd.read_sql(query, engine)
# Drop columns for universities with no graduation rate (i.e. <100 students over 3 yr average)
df_inputs = df_inputs.dropna(subset=['grad_rate'])

### Fill null subpop grad rates

#Grad rates for subpops are set to null for 3 yr pops < 100 students. This fill method will automatically assign the next lowest grad rate for all subpop groups

df_grad_rates = df_inputs.iloc[:, 4:11]

df_inputs['aian_grad_rate'] = df_grad_rates['aian_grad_rate'].fillna(df_grad_rates.min(axis=1))
df_inputs['asian_grad_rate'] = df_grad_rates['asian_grad_rate'].fillna(df_grad_rates.min(axis=1))
df_inputs['boaa_grad_rate'] = df_grad_rates['boaa_grad_rate'].fillna(df_grad_rates.min(axis=1))
df_inputs['hisp_grad_rate'] = df_grad_rates['hisp_grad_rate'].fillna(df_grad_rates.min(axis=1))
df_inputs['nhopi_grad_rate'] = df_grad_rates['nhopi_grad_rate'].fillna(df_grad_rates.min(axis=1))
df_inputs['white_grad_rate'] = df_grad_rates['white_grad_rate'].fillna(df_grad_rates.min(axis=1))

### Normalize SMI inputs for value calculation

#scaler transforms input arrays into a 0-1 value in order to more easily apply input weights in SMI calc.

#*Note -- For endowment input, the scaled value is based on the natural log of endowment.
#         This was done to reduce the impact of relative outliers in endowment figures.
#         The assumption is that Harvard's endowment figure of >1b is not 1000x more impactful on SMI than a school with a 1m endowment*

scaler = MinMaxScaler()

df_smi_inputs = df_inputs.iloc[:, [0, 11, 12, 13, 14, 15]]

df_smi_inputs = df_smi_inputs.dropna()

aca_array = np.array(df_smi_inputs['smi_aca']).reshape(-1, 1)
ecs_array = np.array(df_smi_inputs['smi_mecs']).reshape(-1, 1)
end_array = np.array(df_smi_inputs['smi_e']).reshape(-1, 1)

norm_aca = scaler.fit_transform(aca_array)
norm_ecs = scaler.fit_transform(ecs_array)
norm_log_end = scaler.fit_transform(np.log(end_array))

df_smi_inputs['smi_aca'] = norm_aca
df_smi_inputs['smi_mecs'] = norm_ecs
df_smi_inputs['smi_e'] = norm_log_end


### Calculate SMI

#Using normalized smi_inputs, calculate the smi score for each college or university
#Scores are then scaled for use as an input in the value score calculations below

def calc_smi(av_cst_attnd, pct_pell, grad_rate, med_sal, endow):

    aca_weight = -200
    pctp_weight = 155
    grad_weight = 311
    ecs_weight = 311
    endow_weight = 75

    return (
            av_cst_attnd * aca_weight
            + pct_pell * pctp_weight
            + grad_rate * grad_weight
            + med_sal * ecs_weight
            + endow * endow_weight
           )

df_smi_inputs['smi_value'] = calc_smi(
                                      df_smi_inputs['smi_aca']
                                      ,df_smi_inputs['smi_pctp']
                                      ,df_smi_inputs['smi_gr']
                                      ,df_smi_inputs['smi_mecs']
                                      ,df_smi_inputs['smi_e']
                                     )

smi_array = np.array(df_smi_inputs.iloc[:, [6]]).reshape(-1, 1)

norm_smi = scaler.fit_transform(smi_array)

df_smi_inputs.iloc[:, [6]] = norm_smi

df_inputs = df_inputs.merge(df_smi_inputs.iloc[:, [0, 6]], how='left', on='unit_id')


### Impute null SMI values

#Used 0 for nulls to be conservative in cases of unreported inputs

df_inputs['smi_value'] = df_inputs.iloc[:, [16]].fillna(0)


### Setup function to calculate value scores

#Weights are arbitrarily set by RTCC team and subject to change.

#```rank_types``` dict is set up to create a ranked list for each pop/subpop.
#```boaa_indicator``` field exists to apply an additional HBCU indicator input to the college ranks for african american scholars

def create_ranks(boaa_indicator, grad_rates, partner_type, for_profit_indicator, HBCU_indicator, social_mobility_index):
    """
    Create college value ranks by subpop grad rate.
    """
    grad_rate_weight = 21
    smi_weight = 16
    partner_weight = 1
    hbcu_weight = 1
    for_profit_weight = -5

    if boaa_indicator == 1:
        return (
                grad_rates * grad_rate_weight
                + social_mobility_index * smi_weight
                + partner_type * partner_weight
                + HBCU_indicator * hbcu_weight
                + for_profit_indicator * for_profit_weight
               )

    return (
           grad_rates * grad_rate_weight
           + social_mobility_index * smi_weight
           + partner_type * partner_weight
           + for_profit_indicator * for_profit_weight
           )

rank_types = {
              'overall_value_score': {
                                      'location':'grad_rate',
                                      'boaa_indicator': 0
                                     },
              'aian_value_score': {
                                   'location': 'aian_grad_rate',
                                   'boaa_indicator' : 0
                                  },
              'asian_value_score': {
                                    'location': 'asian_grad_rate',
                                    'boaa_indicator': 0
                                   },
              'boaa_value_score': {
                                   'location': 'boaa_grad_rate',
                                   'boaa_indicator': 1
                                  },
              'hisp_value_score': {
                                   'location': 'hisp_grad_rate',
                                   'boaa_indicator': 0
                                  },
              'nhopi_value_score': {
                                    'location':'nhopi_grad_rate',
                                    'boaa_indicator': 0
                                   },
              'white_value_score': {
                                    'location': 'white_grad_rate',
                                    'boaa_indicator': 0
                                   }
             }

### Loop over rank dict and assign each subpop a ranked array of value scores per university

for rank, rank_dict in rank_types.items():
    for key_type, value in rank_dict.items():
        if key_type == 'location':
            location = value
        elif key_type == 'boaa_indicator':
            boaa_indicator = value



            df_inputs[rank] = create_ranks(
                                           boaa_indicator
                                           ,df_inputs[location]
                                           ,df_inputs['partner_type_indicator']
                                           ,df_inputs['for_profit_indicator']
                                           ,df_inputs['HBCU_indicator']
                                           ,df_inputs['smi_value']
                                          )


### Transform results to extract table for vis use

df_output = pd.DataFrame({'unit_id': df_inputs['unit_id'],
                          'partner_indicator': df_inputs['partner_type_indicator'],
                          'for_profit_indicator': df_inputs['for_profit_indicator'],
                          'HBCU_indicator': df_inputs['HBCU_indicator'],
                          'overall_grad_rate': df_inputs['grad_rate'],
                          'overall_value_score': df_inputs['overall_value_score'],
                          'aian_grad_rate': df_inputs['aian_grad_rate'],
                          'aian_value_score': df_inputs['aian_value_score'],
                          'asian_grad_rate': df_inputs['asian_grad_rate'],
                          'asian_value_score': df_inputs['asian_value_score'],
                          'boaa_grad_rate': df_inputs['boaa_grad_rate'],
                          'boaa_value_score': df_inputs['boaa_value_score'],
                          'hisp_grad_rate': df_inputs['hisp_grad_rate'],
                          'hisp_value_score': df_inputs['hisp_value_score'],
                          'nhopi_grad_rate': df_inputs['nhopi_grad_rate'],
                          'nhopi_value_score': df_inputs['nhopi_value_score'],
                          'white_grad_rate': df_inputs['white_grad_rate'],
                          'white_value_score': df_inputs['white_value_score'],
                          'average_cost_attendance': df_inputs['smi_aca'],
                          'percent_pell_enrolled': df_inputs['smi_pctp'],
                          'median_early_salary': df_inputs['smi_mecs'],
                          'smi_value': df_inputs['smi_value'],
})

### Join to identifying IPEDS data

fetch_college_details = r"""
SELECT UNITID AS unit_id
       ,institution_entity_name AS college_name
       ,degree_of_urbanization_urban_centric_locale
       ,institution_size_category
       ,longitude_location_of_institution
       ,latitude_location_of_institution

  FROM CollegeData.IPEDS_2017_provisional.Institutional_Characteristics
"""

college_names = pd.read_sql(fetch_college_details, engine)

df_output = df_output.merge(college_names.iloc[:, :], how='left', on='unit_id')


### Export results to csv file

df_output.to_csv('college_values_extract_test_1.csv', index=False)
