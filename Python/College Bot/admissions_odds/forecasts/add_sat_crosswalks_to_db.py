"""
Quick script to load the old-to-new SAT score crosswalks into CollegeData
"""

import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine

if __name__ == '__main__':
    sheets = {    
        'total_2400': r'Table 9 (Total 2400) ',
        'total_1600': r'Table 10 (Total 1600)',
        'math': r'Table 12 (M to M to MT)',
        'reading_and_writing': r'Table 11 (W + CR to ERW)',
    }
    engine = create_engine('mssql+pyodbc://sql-cl-dw-pro\datawarehouse/CollegeData?driver=SQL+Server')

    for subject, table in sheets.items():        
        df = pd.read_excel(
                io=(
                    Path.cwd() 
                    / 'etc' 
                    / 'xls_concordance-tables-old-sat-scores-new-sat-scores.xlsx'
                ),
                sheet_name=f'{table}',
                header=1,
            )
            
        cols_cleaned = (
            df.columns
                .str.replace(r'\W', ' ')
                .str.strip()
                .str.replace(r' +', '_')
        )        
        df.columns = cols_cleaned

        df.to_sql(
            name=f'OldToNewSATcrosswalk_{subject}',
            con=engine,
            schema='DAT',
            if_exists='replace',
            index=False,
        )
            
        print(f'Successfully loaded to CollegeData.DAT.OldToNewSATcrosswalk_{subject}')