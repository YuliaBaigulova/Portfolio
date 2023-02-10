#!/usr/bin/env python
# coding: utf-8

# In[ ]:

import pandas as pd
import numpy as np
import sys

def main(params1, params2, params3):
    df1 = pd.read_csv(params1)
    df2 = pd.read_csv(params2)
    df3 = pd.read_csv(params3)

    df2 = df2.merge(df3, on = 'id', how = 'left')
    global df_full
    df_full = pd.concat([df1,df2], ignore_index=True)


def data_cleaning(df_full):
    global df 
    df = df_full.copy()
    
    # отбираем строки, где в стоблце date стоит дата
    df['date'] = pd.to_datetime(df['date'],errors='coerce')
    df = df[pd.notnull(df['date'])]
    if len(df) != len(df_full):
        print('\nУдалены строки с некорректными значениями даты в столбце date')

    # убираем строки с нечисловыми значениями в столбцах invest и registrations
    df[['invest','registrations']] = df[['invest','registrations']].apply(pd.to_numeric, errors='coerce')

    if (df['invest'].values < 0).any() or df['invest'].isnull().any():
        print('\nУдалены строки с некорректными значениями в столбце invest')

    if (df['registrations'].values < 0).any() or df['registrations'].isnull().any():
        print('\nУдалены строки с некорректными значениями в столбце registrations')

    # отбираем только положительные и нулевые значения в столбцах invest и registrations
    df = df.loc[(df['invest']>=0) & (df['registrations']>=0)]        

    return df


def month_defining(df):
    global months 
    months = df['date'].dt.month.unique().tolist()
    print(f'\nДоступны данные за следующие месяцы: {", ".join(map(str, months))}')


def month_selecting():
    try:
        user_input = int(input('Пожалуйста, введите номер месяца из указанного списка ')) 
        while user_input not in months:
            user_input = int(input('Месяц введен неверно. Попробуйте еще раз '))
        else:
            return user_input
    except ValueError:  
        print("\nВы ввели не число. Значение по умолчанию - январь 2019")
        return 1


def m_result_creating(df):
    df = df.loc[(df['date'].dt.month == month_selecting())]
    period = df['date'].dt.to_period('m')
    print(f'\nИтоговые значения представлены за {max(period)}. Результат сохранен в файле new_file.csv')
    global m_result
    m_result = df.groupby('manager')[['invest','registrations']].sum().reset_index()
    return m_result


def new_columns(m_result):
    m_result['registration_cost'] = (m_result['invest'].div(m_result['registrations']).replace(np.inf, np.nan)).round(2)
    m_result['no_regs_manager_A']=np.where((m_result['registrations'] == 0) & (m_result['manager'].str.startswith('A')),True,False)
    m_result = m_result.set_index('manager').sort_values(by = 'registration_cost')
    return m_result

if __name__ == "__main__": 
    if len(sys.argv) != 4:
        print('Введите 3 файла с данными об эффективности рекламных кампаний')
    else:
        main(sys.argv[1], sys.argv[2], sys.argv[3])

        print('\nДоброго времени суток! \nНаша программа объединяет 3 полученных файла и выводит итоговую информацию \nпо эффективности работы каждого менеджера за выбранный месяц') 

        month_defining(data_cleaning(df_full))
        m_result_creating(df)

        new_columns(m_result).to_csv('new_file.csv')
        print(f'\n{new_columns(m_result)}')