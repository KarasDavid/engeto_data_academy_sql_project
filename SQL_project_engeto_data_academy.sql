CREATE OR REPLACE TABLE t_czechia_payroll_adjusted AS(
SELECT
	value AS average_gross_salary,
	industry_branch_code,
	payroll_year,
	payroll_quarter
FROM czechia_payroll 
WHERE value_type_code = 5958
AND calculation_code = 200
);

CREATE OR REPLACE TABLE t_czechia_price_adjusted AS(
SELECT
	value AS food_price,
	category_code AS food_category,
	date_from AS food_price_measured_from,
	date_to AS food_price_measured_to, 
	quarter(date_from) AS price_quarter,
	year(date_from) AS price_year
FROM czechia_price
WHERE region_code IS NULL 
);


CREATE OR REPLACE TABLE t_david_karas_project_sql_primary_final AS(
SELECT
	cpib.name AS industry_branch,
	cpaya.average_gross_salary,
	cpaya.payroll_year,
	cpaya.payroll_quarter,
	cpc.name AS food_name,
	cpa.food_price,
	concat(cpc.price_value, ' ', cpc.price_unit) AS unit,
	cpa.food_price_measured_from,
	cpa.food_price_measured_to
FROM t_czechia_payroll_adjusted cpaya
JOIN t_czechia_price_adjusted cpa
	ON cpaya.payroll_year = cpa.price_year 
	AND cpaya.payroll_quarter = cpa.price_quarter 
JOIN czechia_payroll_industry_branch cpib  
	ON cpaya.industry_branch_code = cpib.code 
JOIN czechia_price_category cpc 
	ON cpa.food_category = cpc.code
);

/*
 * Task 1
 */

SELECT
	a.industry_branch,
	a.average_gross_salary,
	a.payroll_year,
	a.payroll_quarter,
	b.average_gross_salary,
	b.payroll_year,
	b.payroll_quarter,
	round((b.average_gross_salary / a.average_gross_salary - 1) * 100, 2) AS difference_between_years_in_percentage,
	CASE
		WHEN round((b.average_gross_salary / a.average_gross_salary - 1) * 100, 2) < 0 THEN 1
		ELSE 0
	END AS year_on_year_drop_in_wages
FROM
(
SELECT
	DISTINCT industry_branch,
	average_gross_salary, 
	payroll_year,
	payroll_quarter
FROM t_david_karas_project_sql_primary_final dk1
ORDER BY industry_branch, payroll_year, payroll_quarter
) a
JOIN
(SELECT 
	DISTINCT industry_branch,
    average_gross_salary,
	payroll_year,
	payroll_quarter
FROM t_david_karas_project_sql_primary_final
ORDER by industry_branch, payroll_year, payroll_quarter
) b
ON a.industry_branch = b.industry_branch 
AND a.payroll_year = b.payroll_year -1
AND a.payroll_quarter = b.payroll_quarter
HAVING year_on_year_drop_in_wages = 1;

/*
 * Task 2
 */

SELECT  *,
	round(average_gross_salary / food_price, 2) AS kilograms_of_bread_or_liters_of_milk_for_an_average_gross_salary
FROM t_david_karas_project_sql_primary_final
WHERE (food_name = "Mléko polotučné pasterované" AND (food_price_measured_from = '2006-01-02' OR food_price_measured_from = '2018-12-10'))   
OR (food_name = "Chléb konzumní kmínový" AND (food_price_measured_from = '2006-01-02' OR food_price_measured_from = '2018-12-10'))
ORDER BY food_name, industry_branch, payroll_year, payroll_quarter, food_price_measured_from ;

/*
 * Task 3
 */

SELECT
	older.food_name,
	older.food_price AS food_price_from_2015_12_14_to_2015_12_20,
	newer.food_price AS food_price_from_2018_12_10_to_2018_12_16,
	older.unit,
	round((newer.food_price / older.food_price * 100-100) / 3, 2) AS average_annual_increase
FROM
(
SELECT
	DISTINCT food_name,
	food_price,
	unit,
	food_price_measured_from,
	food_price_measured_to 
FROM t_david_karas_project_sql_primary_final
WHERE food_price_measured_from = '2015-12-14'
ORDER BY food_name, food_price_measured_from
) older
JOIN 
(SELECT
	DISTINCT food_name,
	food_price,
	unit,
	food_price_measured_from,
	food_price_measured_to 
FROM t_david_karas_project_sql_primary_final
WHERE food_price_measured_from = '2018-12-10' 
ORDER BY food_name, food_price_measured_from
) newer
ON older.food_name = newer.food_name
ORDER BY average_annual_increase;







