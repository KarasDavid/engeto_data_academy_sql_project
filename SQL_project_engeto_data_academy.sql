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

CREATE OR REPLACE TABLE t_david_karas_project_SQL_secondary_final
SELECT
	a.country_x AS country,
	a.year_x,
	a.GDP_x, 
	a.gini_x,
	a.population_x, 
	b.year_y,
	b.GDP_y,
	b.gini_y,
	b.population_y,
	ROUND((GDP_y / GDP_x*100)-100,2) AS GDP_growth_between_years_y_and_x_in_percentage
FROM
(SELECT
	e.country AS country_x,
	e.`year`AS year_x,
	ROUND(e.GDP) AS GDP_x,
	e.gini AS gini_x,
	e.population AS population_x 
FROM economies e
JOIN countries c
	ON e.country = c.country 
WHERE c.continent = "Europe"
AND e.year >=2005 AND e.year<=2018
) a
JOIN 
(SELECT
	e.country AS country_y,
	e.`year`AS year_y,
	ROUND(e.GDP) AS GDP_y,
	e.gini AS gini_y,
	e.population AS population_y 
FROM economies e
JOIN countries c
	ON e.country = c.country 
WHERE c.continent = "Europe"
AND e.year >=2005 AND e.year<=2018
) b
ON a.year_x = b.year_y-1
AND a.country_x = b.country_y;

/*
 * Task 1
 */

SELECT
	a.industry_branch,
	a.payroll_year_x,
	a.payroll_quarter_x,
	a.average_gross_salary_x,
	b.payroll_year_y,
	b.payroll_quarter_y,
	b.average_gross_salary_y,
	round((b.average_gross_salary_y / a.average_gross_salary_x - 1) * 100, 2) AS salary_difference_between_years_x_and_y_in_percentage,
	CASE
		WHEN round((b.average_gross_salary_y / a.average_gross_salary_x - 1) * 100, 2) < 0 THEN 1
		ELSE 0
	END AS year_on_year_drop_in_wages
FROM
(
SELECT
	DISTINCT industry_branch,
	average_gross_salary AS average_gross_salary_x, 
	payroll_year AS payroll_year_x,
	payroll_quarter AS payroll_quarter_x
FROM t_david_karas_project_sql_primary_final dk1
ORDER BY industry_branch, payroll_year, payroll_quarter
) a
JOIN
(SELECT 
	DISTINCT industry_branch,
    average_gross_salary AS average_gross_salary_y,
	payroll_year AS payroll_year_y,
	payroll_quarter AS payroll_quarter_y
FROM t_david_karas_project_sql_primary_final
ORDER by industry_branch, payroll_year, payroll_quarter
) b
ON a.industry_branch = b.industry_branch 
AND a.payroll_year_x = b.payroll_year_y -1
AND a.payroll_quarter_x = b.payroll_quarter_y
HAVING year_on_year_drop_in_wages = 1;

/*
 * Task 2
 */

SELECT
	industry_branch,
	payroll_year,
	payroll_quarter, 
	average_gross_salary,
	food_name,
	food_price_measured_from,
	food_price_measured_to,
	food_price,
	unit,
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
	round((newer.food_price / older.food_price * 100-100) / 3, 2) AS average_annual_price_increase
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
ORDER BY average_annual_price_increase;

/*
 * Task 4
 */

SELECT
	salary.payroll_year_x,
	salary.payroll_year_y,
	salary.average_gross_salary_difference_between_years_y_and_x_in_percentage,
	price.average_price_difference_between_years_y_and_x_in_percentage,
	round((price.average_price_difference_between_years_y_and_x_in_percentage-salary.average_gross_salary_difference_between_years_y_and_x_in_percentage)
	/salary.average_gross_salary_difference_between_years_y_and_x_in_percentage*100,2) AS difference_between_price_and_gross_salary_between_years_y_and_x_in_percentage,
	CASE 
		WHEN round((price.average_price_difference_between_years_y_and_x_in_percentage-salary.average_gross_salary_difference_between_years_y_and_x_in_percentage)
		/salary.average_gross_salary_difference_between_years_y_and_x_in_percentage*100,2) > 10 OR (salary.average_gross_salary_difference_between_years_y_and_x_in_percentage <0 
		AND round((price.average_price_difference_between_years_y_and_x_in_percentage-salary.average_gross_salary_difference_between_years_y_and_x_in_percentage)
		/salary.average_gross_salary_difference_between_years_y_and_x_in_percentage*100,2) <-10)
		THEN 1
		ELSE 0
	END is_year_on_year_increase_in_food_price_more_significant_than_10_percentage_than_the_increase_in_salary
FROM 
(
SELECT
	a.average_gross_salary AS average_gross_salary_x,
	a.payroll_year AS payroll_year_x,
	b.average_gross_salary AS average_gross_salary_y,
	b.payroll_year AS payroll_year_y,
	round((b.average_gross_salary / a.average_gross_salary*100)-100,2) AS average_gross_salary_difference_between_years_y_and_x_in_percentage
FROM 
(SELECT
	avg(average_gross_salary) AS average_gross_salary,
	payroll_year
FROM t_david_karas_project_sql_primary_final
GROUP BY payroll_year
) a
JOIN
(SELECT
	avg(average_gross_salary) AS average_gross_salary,
	payroll_year
FROM t_david_karas_project_sql_primary_final
GROUP BY payroll_year
) b
ON a.payroll_year = b.payroll_year-1
) salary
JOIN
(
SELECT
	a.average_price AS average_price_x,
	a.price_year AS price_year_x,
	b.average_price AS average_price_y,
	b.price_year AS price_year_y,
	round((b.average_price / a.average_price*100)-100,2) AS average_price_difference_between_years_y_and_x_in_percentage
FROM
(SELECT
	round(avg(food_price),2) AS average_price,
	YEAR(food_price_measured_from) AS price_year
FROM t_david_karas_project_sql_primary_final
GROUP BY price_year
)a
JOIN
(SELECT
	round(avg(food_price),2) AS average_price,
	YEAR(food_price_measured_from) AS price_year
FROM t_david_karas_project_sql_primary_final
GROUP BY price_year
)b
ON a.price_year = b.price_year-1
) price
ON salary.payroll_year_x = price.price_year_x;

/*
 *  Task 5
 */

SELECT
	t_david_karas_project_SQL_secondary_final.year_x,
	t_david_karas_project_SQL_secondary_final.GDP_x,
	salary.average_gross_salary_x,
	price.average_food_price_x,
	t_david_karas_project_SQL_secondary_final.year_y,
	t_david_karas_project_SQL_secondary_final.GDP_y,
	salary.average_gross_salary_y,
	price.average_food_price_y,
	t_david_karas_project_SQL_secondary_final.GDP_growth_between_years_y_and_x_in_percentage,
	salary.average_gross_salary_growth_between_years_y_and_x_in_percentage,
	price.average_food_price_growth_between_years_y_and_x_in_percentage
FROM
(SELECT *,
	ROUND((average_gross_salary_y / average_gross_salary_x*100)-100,2) AS average_gross_salary_growth_between_years_y_and_x_in_percentage
FROM 
(SELECT 
	payroll_year AS payroll_year_x,
	ROUND(AVG(average_gross_salary),0) AS average_gross_salary_x
FROM t_david_karas_project_sql_primary_final
GROUP BY payroll_year
)a
JOIN
(SELECT 
	payroll_year AS payroll_year_y,
	ROUND(AVG(average_gross_salary),0) AS average_gross_salary_y
FROM t_david_karas_project_sql_primary_final
GROUP BY payroll_year
)b
ON a.payroll_year_x = b.payroll_year_y-1
) salary
JOIN 
(SELECT *,
	ROUND((average_food_price_y / average_food_price_x*100)-100,2) AS average_food_price_growth_between_years_y_and_x_in_percentage
FROM 
(SELECT
	ROUND(AVG(food_price),2) AS average_food_price_x,
	YEAR(food_price_measured_from) AS price_year_x
FROM t_david_karas_project_sql_primary_final
GROUP BY YEAR(food_price_measured_from)
)a
JOIN
(SELECT
	ROUND(AVG(food_price),2) AS average_food_price_y,
	YEAR(food_price_measured_from) AS price_year_y
FROM t_david_karas_project_sql_primary_final
GROUP BY YEAR(food_price_measured_from)
)b
ON a.price_year_x = b.price_year_y-1
) price
ON salary.payroll_year_x = price.price_year_x
RIGHT JOIN t_david_karas_project_SQL_secondary_final
ON salary.payroll_year_x = t_david_karas_project_SQL_secondary_final.year_x
WHERE t_david_karas_project_SQL_secondary_final.country = "Czech republic";








