CREATE OR REPLACE TABLE t_czechia_payroll_adjusted AS(
SELECT
	value AS gross_salary,
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
	QUARTER(date_from) AS price_quarter,
	YEAR(date_from) AS price_year
FROM czechia_price
WHERE region_code IS NULL 
);

CREATE OR REPLACE TABLE t_david_karas_project_sql_primary_final AS(
SELECT
	cpib.name AS industry_branch,
	cpaya.gross_salary,
	cpaya.payroll_year,
	cpaya.payroll_quarter,
	cpc.name AS food_name,
	cpa.food_price,
	CONCAT(cpc.price_value, ' ', cpc.price_unit) AS unit,
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
	ROUND((GDP_y / GDP_x*100)-100,2) AS GDP_growth_years_y_x_in_percent
FROM(
	SELECT
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
JOIN(
	SELECT
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
	a.avg_gross_salary_x,
	b.payroll_year_y,
	b.payroll_quarter_y,
	b.avg_gross_salary_y,
	ROUND((b.avg_gross_salary_y / a.avg_gross_salary_x - 1) * 100, 2) AS avg_salary_diff_years_y_x_in_percent,
	CASE
		WHEN ROUND((b.avg_gross_salary_y / a.avg_gross_salary_x - 1) * 100, 2) < 0 
		THEN 1
		ELSE 0
	END AS year_on_year_drop_in_avg_wages
FROM(
	SELECT
		industry_branch,
		AVG(gross_salary) AS avg_gross_salary_x, 
		payroll_year AS payroll_year_x,
		payroll_quarter AS payroll_quarter_x
	FROM t_david_karas_project_sql_primary_final dk1
	GROUP BY industry_branch, payroll_year_x, payroll_quarter_x 
	ORDER BY industry_branch, payroll_year, payroll_quarter
) a
JOIN(
	SELECT 
		industry_branch,
    	AVG(gross_salary) AS avg_gross_salary_y,
		payroll_year AS payroll_year_y,
		payroll_quarter AS payroll_quarter_y
	FROM t_david_karas_project_sql_primary_final
	GROUP BY industry_branch, payroll_year_y, payroll_quarter_y 
	ORDER by industry_branch, payroll_year, payroll_quarter
) b
	ON a.industry_branch = b.industry_branch 
	AND a.payroll_year_x = b.payroll_year_y -1
	AND a.payroll_quarter_x = b.payroll_quarter_y
HAVING year_on_year_drop_in_avg_wages = 1;

/*
 * Task 2
 */

SELECT
	industry_branch,
	payroll_year,
	payroll_quarter, 
	AVG(gross_salary) AS avg_gross_salary,
	food_name,
	food_price_measured_from,
	food_price_measured_to,
	AVG(food_price) AS avg_food_price,
	unit,
	ROUND(AVG(gross_salary) / AVG(food_price), 2) AS kg_bread_l_milk_avg_gross_salary
FROM t_david_karas_project_sql_primary_final
WHERE (food_name = "Mléko polotučné pasterované" 
	AND (food_price_measured_from = '2006-01-02' 
		OR food_price_measured_from = '2018-12-10'))   
	OR (food_name = "Chléb konzumní kmínový"
		AND (food_price_measured_from = '2006-01-02' 
			OR food_price_measured_from = '2018-12-10'))
GROUP BY industry_branch, payroll_year, payroll_quarter, food_name, food_price_measured_from, food_price_measured_to, unit
ORDER BY food_name, industry_branch, payroll_year, payroll_quarter, food_price_measured_from;

/*
 * Task 3
 */

SELECT
	older.food_name,
	older.avg_food_price AS food_price_14_12_to_20_12_2015,
	newer.avg_food_price AS food_price_10_12_to_16_12_2018,
	older.unit,
	ROUND((newer.avg_food_price / older.avg_food_price * 100-100) / 3, 2) AS avg_annual_price_increase
FROM(
	SELECT
		food_name,
		AVG(food_price) AS avg_food_price,
		unit,
		food_price_measured_from,
		food_price_measured_to 
	FROM t_david_karas_project_sql_primary_final
	WHERE food_price_measured_from = '2015-12-14'
	GROUP BY food_name, unit, food_price_measured_from, food_price_measured_to
	ORDER BY food_name, food_price_measured_from
) older
JOIN(
	SELECT
		food_name,
		AVG(food_price) AS avg_food_price,
		unit,
		food_price_measured_from,
		food_price_measured_to 
	FROM t_david_karas_project_sql_primary_final
	WHERE food_price_measured_from = '2018-12-10' 
	GROUP BY food_name, unit, food_price_measured_from, food_price_measured_to
	ORDER BY food_name, food_price_measured_from
) newer
	ON older.food_name = newer.food_name
ORDER BY avg_annual_price_increase;

/*
 * Task 4
 */

SELECT
	salary.payroll_year_x,
	salary.payroll_year_y,
	salary.avg_gross_salary_diff_years_y_x_in_percent,
	price.avg_price_diff_years_y_x_in_percent,
	ROUND((price.avg_price_diff_years_y_x_in_percent-salary.avg_gross_salary_diff_years_y_x_in_percent)
		/salary.avg_gross_salary_diff_years_y_x_in_percent*100,2) AS diff_price_gross_salary_years_y_x_in_percent,
	CASE 
		WHEN ROUND((price.avg_price_diff_years_y_x_in_percent-salary.avg_gross_salary_diff_years_y_x_in_percent)
			/salary.avg_gross_salary_diff_years_y_x_in_percent*100,2) > 10
		OR (salary.avg_gross_salary_diff_years_y_x_in_percent <0 
			AND ROUND((price.avg_price_diff_years_y_x_in_percent-salary.avg_gross_salary_diff_years_y_x_in_percent)
				/salary.avg_gross_salary_diff_years_y_x_in_percent*100,2) <-10)
		THEN 1
		ELSE 0
	END more_significant_rise_in_food_price_than_salary    
FROM(
	SELECT
		a.avg_gross_salary AS avg_gross_salary_x,
		a.payroll_year AS payroll_year_x,
		b.avg_gross_salary AS avg_gross_salary_y,
		b.payroll_year AS payroll_year_y,
		ROUND((b.avg_gross_salary / a.avg_gross_salary*100)-100,2) AS avg_gross_salary_diff_years_y_x_in_percent
	FROM(
		SELECT
			AVG(gross_salary) AS avg_gross_salary,
			payroll_year
		FROM t_david_karas_project_sql_primary_final
		GROUP BY payroll_year
	) a
	JOIN(
		SELECT
			AVG(gross_salary) AS avg_gross_salary,
			payroll_year
		FROM t_david_karas_project_sql_primary_final
		GROUP BY payroll_year
	) b
		ON a.payroll_year = b.payroll_year-1
) salary
JOIN(
	SELECT
		a.avg_price AS avg_price_x,
		a.price_year AS price_year_x,
		b.avg_price AS avg_price_y,
		b.price_year AS price_year_y,
		ROUND((b.avg_price / a.avg_price*100)-100,2) AS avg_price_diff_years_y_x_in_percent
	FROM(
		SELECT
			ROUND(AVG(food_price),2) AS avg_price,
			YEAR(food_price_measured_from) AS price_year
		FROM t_david_karas_project_sql_primary_final
		GROUP BY price_year
	)a
	JOIN(
		SELECT
			ROUND(AVG(food_price),2) AS avg_price,
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
	t_david_karas_project_SQL_secondary_final.GDP_growth_years_y_x_in_percent,
	salary.avg_gross_salary_growth_years_y_x_in_percent,
	price.avg_food_price_growth_years_y_x_in_percent
FROM(
	SELECT *,
		ROUND((average_gross_salary_y / average_gross_salary_x*100)-100,2) AS avg_gross_salary_growth_years_y_x_in_percent
	FROM(
		SELECT 
			payroll_year AS payroll_year_x,
			ROUND(AVG(gross_salary),0) AS average_gross_salary_x
		FROM t_david_karas_project_sql_primary_final
		GROUP BY payroll_year
	)a
	JOIN(
		SELECT 
			payroll_year AS payroll_year_y,
			ROUND(AVG(gross_salary),0) AS average_gross_salary_y
		FROM t_david_karas_project_sql_primary_final
		GROUP BY payroll_year
	)b
		ON a.payroll_year_x = b.payroll_year_y-1
) salary
JOIN(
	SELECT *,
		ROUND((average_food_price_y / average_food_price_x*100)-100,2) AS avg_food_price_growth_years_y_x_in_percent
	FROM(
		SELECT
			ROUND(AVG(food_price),2) AS average_food_price_x,
			YEAR(food_price_measured_from) AS price_year_x
		FROM t_david_karas_project_sql_primary_final
		GROUP BY YEAR(food_price_measured_from)
	)a
	JOIN(
		SELECT
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








