DROP DATABASE IF EXISTS test_smile;
CREATE DATABASE test_smile;
USE test_smile;

DROP TABLE IF EXISTS shops;
CREATE TABLE shops (
shopnumber SERIAL PRIMARY KEY,
city VARCHAR (10) NOT NULL,
address VARCHAR (50) NOT NULL
) COMMENT = 'Магазины';

INSERT INTO shops (city, address) VALUES 
('СПб',	'Ленина, 5'),
('МСК',	'Пушкина, 10'),
--//-//-//-//-//-//-//-;

DROP TABLE IF EXISTS goods;
CREATE TABLE goods (
id_good BIGINT UNSIGNED NOT NULL PRIMARY KEY,
category VARCHAR (10) NOT NULL,
good_name VARCHAR (50) NOT NULL,
price DECIMAL NOT NULL
) COMMENT = 'Товары';

INSERT INTO goods VALUES
('1234567',	'КРАСОТА',	'шамунь',	100),
('1234568',	'ЧИСТОТА',	'стиральный порошок',	120),
('1234571',	'ДЕКОР',	'резинка для волос',	20),
--//-//-//-//-//-//-//-;

DROP TABLE IF EXISTS sales;
CREATE TABLE sales (
id_sale SERIAL PRIMARY KEY 
'date' DATE NOT NULL,
shopnumber BIGINT UNSIGNED NOT NULL,
id_good BIGINT UNSIGNED NOT NULL,
qty BIGINT UNSIGNED NOT NULL

/*,FOREIGN KEY (shopnumber) REFERENCES shops(shopnumber),
FOREIGN KEY (id_good) REFERENCES goods(id_good)*/
) COMMENT = 'Продажи';

INSERT INTO sales (`date`, shopnumber, id_good, qty) VALUES
('2016-01-01',	'1',	'1234569',	100),
('2016-01-01',	'2',	'1234577',	800),
('2016-01-01',	'5',	'1234580',	800),
('2016-01-03',	'16',	'1234580',	600),
--//-//-//-//-//-//-//-;


-- 1. Необходимо получить все возможные варианты магазин-товар (без использования таблицы SALES)
SELECT shopnumber, city, id_good, category 
FROM shops, goods

-- 2. Условие: выборка по продажам за 2.01.2016

SELECT s.shopnumber, sh.city, sh.address, SUM(s.qty) AS sum_qty, SUM(g.price*s.qty) AS sum_value 
FROM sales s
LEFT JOIN shops sh ON s.shopnumber = sh.shopnumber 
LEFT JOIN goods g ON s.id_good = g.id_good
WHERE s.date = '2016-01-02'
GROUP BY s.shopnumber, sh.city, sh.address

-- 3.	Дата	Город	Доля в суммарных продажах в руб на дату
--   	Условие: выборка только по товарам направления ЧИСТОТА	

SELECT s.date, sh.city, SUM(g.price*s.qty)/SUM(SUM(g.price*s.qty)) OVER(PARTITION BY s.date)*100 AS share  
FROM sales s
LEFT JOIN shops sh ON s.shopnumber = sh.shopnumber 
LEFT JOIN goods g ON s.id_good = g.id_good
WHERE g.category = 'ЧИСТОТА'
GROUP BY s.date, sh.city
ORDER BY s.date, sh.city DESC

-- 4. Дата	Магазин	Товар
--   Условие: информация о топ-3 товарах по продажам в штуках в каждом магазине в каждую дату		

WITH cte AS 
(
	SELECT ROW_NUMBER() OVER (PARTITION BY s.date, s.shopnumber ORDER BY SUM(s.qty) DESC ) AS rn, 
	   	   s.date, s.shopnumber, s.id_good, g.good_name, SUM(s.qty) AS sum_qty
	FROM sales s
	LEFT JOIN goods g ON s.id_good = g.id_good
	GROUP BY s.date, s.shopnumber, s.id_good, g.good_name
)
SELECT `date`, shopnumber, CONCAT(id_good,'-',good_name) AS good
FROM cte
WHERE rn <= 3


-- 5	Дата	Магазин	Товарное направление	Сумма в руб за предыдущую дату
	    Условие: только магазины СПб			

/* так как не по всем категориям товарных направлений есть данные на каждую дату, я создала отдельную таблицу-каркас (t2), 
 к которой присоединила расчеты */

WITH t1 AS -- добавляем к имеющимся датам 4 января 2016
	(SELECT DISTINCT `date` dt FROM sales 
	UNION
	SELECT DATE_ADD(MAX(`date`), INTERVAL 1 DAY) dt FROM sales), -- решала в mysql
t2 AS 	
	(SELECT DISTINCT dt, shopnumber, category
	FROM t1, sales, goods
	WHERE shopnumber IN (SELECT shopnumber FROM shops WHERE city = 'СПб')
    ), -- создана таблица-каркас с пересечением дат (включая 4 января), номеров магазинов в городе Санкт-Петербург и категорий товаров 
t3 AS 
	(SELECT s.date, s.shopnumber, g.category, SUM(s.qty*g.price) AS value
	FROM sales s
	JOIN goods g ON s.id_good = g.id_good
	GROUP BY s.date, s.shopnumber, g.category)
SELECT t2.dt, t2.shopnumber, t2.category,  
	   COALESCE(LAG(t3.value) OVER(PARTITION BY shopnumber, category ORDER BY dt),0) prev_value -- аргумент default функции LAG не заменяет все NULL, поэтому использовала функцию COALESCE
FROM t2
LEFT JOIN t3 ON t2.dt = t3.date AND t2.shopnumber = t3.shopnumber AND t2.category = t3.category
ORDER BY t2.dt, t2.shopnumber, t2.category

