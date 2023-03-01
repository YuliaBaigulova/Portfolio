/* a.	Вывод количества всех транзакций, сгруппированных по месяцам, совершенных пользователями, 
которые зарегистрировались в тот же месяц, что и осуществили транзакцию. 
(Т.е. За июль 2019 - это пользователи, зарегистрированные в июле 2019, за август 2019 - в августе 2019 и т.д.)*/

--неоднозначно сформулировано. Если считать количество всех транзакций то вот так:
SELECT to_char(finished_at, 'YYYY-MM') AS months, COUNT(*) AS trans_qty 
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE to_char(finished_at, 'YYYY-MM') = to_char(registered_at, 'YYYY-MM') 
GROUP BY to_char(finished_at, 'YYYY-MM');

--если считать только уникальных пользователей, кто провел транзакцию в меяц регистрации, то вот:*/
SELECT to_char(finished_at, 'YYYY-MM') AS months, COUNT(distinct user_id) AS users_qty 
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
WHERE to_char(finished_at, 'YYYY-MM') = to_char(registered_at, 'YYYY-MM') 
GROUP BY to_char(finished_at, 'YYYY-MM');

/* b.	Вывод количества пользователей не из России, зарегистрировавшихся в 2019 году, 
доход (ввод минус вывод) с каждого из которых за все время составил больше 1000$ */

SELECT COUNT(user_id) FROM
(SELECT u.id AS user_id, SUM(o.amount_usd) AS income
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
LEFT JOIN countries c ON u.country_id = c.id
WHERE c.iso != 'RU' AND date_part('year', u.registered_at) = '2019'
GROUP BY u.id
HAVING SUM(o.amount_usd) > 1000) t;

/* c.	Вывод, в котором бы каждому месяцу из orders соответствовала бы каждая страна из countries 
(month x - iso A; month x - iso B; month y = iso A; month y - iso B …) */

--речь о пересечениях?
SELECT DISTINCT to_char(finished_at, 'YYYY-MM') AS months, c.iso
FROM orders o
LEFT JOIN users u ON o.user_id = u.id
LEFT JOIN countries c ON u.country_id = c.id;

-- или о декартовом произведении?
SELECT DISTINCT date_part('month', finished_at) AS months, iso
FROM orders, countries
ORDER BY months;

/* d.	Вывод id пяти пользователей, имеющих наибольшую сумму депозитов (положительных транзакций) за все время*/

SELECT user_id FROM 
	(SELECT user_id, SUM(amount_usd) AS deposit, ROW_NUMBER() OVER(ORDER BY SUM(amount_usd) DESC) AS rn
	FROM orders
	WHERE amount_usd > 0
	GROUP BY user_id) t
WHERE rn <= 5;

/* e.	Вывод id пользователей, доход (пополнения минус выводы) с которых за май 2021 
составил более 5% общего дохода со страны */

SELECT user_id FROM
	(SELECT o.user_id, 
		   (SUM(o.amount_usd))/(SUM(SUM(o.amount_usd)) OVER(PARTITION BY u.country_id))*100 AS share
	FROM orders o
	LEFT JOIN users u ON o.user_id = u.id
	WHERE to_char(o.finished_at, 'YYYY-MM') = '2021-05'
	GROUP BY o.user_id, u.country_id) t
WHERE share > 5;

/* f.	Вывод id пользователей, у которых каждое следующее пополнение счета было выше предыдущего*/

WITH cte AS
(SELECT user_id, amount_usd,
	   CASE WHEN 
			amount_usd > LAG(amount_usd) OVER(PARTITION BY user_id ORDER BY finished_at)   
			THEN 1 ELSE 0 
	   END is_dep_exceeds_prev,
	   (COUNT(*) OVER(PARTITION BY user_id))-1 AS repeated_deposit
FROM orders
WHERE amount_usd > 0) 

SELECT user_id
FROM cte
GROUP BY user_id
HAVING MAX(repeated_deposit) > 0 AND SUM(is_dep_exceeds_prev) = MAX(repeated_deposit) 
