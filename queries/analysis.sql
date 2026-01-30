/* ============================================
   АНАЛИЗ БАЗЫ ДАННЫХ DVD RENTAL
   Автор: Тимофеев Евгений
   Дата: 30.01.2026
   ============================================ */

-- ---------------------------------------------------------
-- 0. ТЕСТОВЫЙ ЗАПРОС (проверка подключения)
-- ---------------------------------------------------------
SELECT 'База данных подключена успешно!' as status;


-- ---------------------------------------------------------
-- 1. ОБЩАЯ СТАТИСТИКА БИЗНЕСА (БЫСТРЫЙ ВАРИАНТ)
-- ---------------------------------------------------------
WITH business_stats AS (
    SELECT 
        (SELECT COUNT(*) FROM customer) as total_customers,
        (SELECT COUNT(*) FROM film) as total_films,
        (SELECT COUNT(*) FROM rental) as total_rentals,
        (SELECT ROUND(SUM(amount), 2) FROM payment) as total_revenue,
        (SELECT ROUND(AVG(amount), 2) FROM payment) as avg_payment,
        (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (return_date - rental_date))/86400), 2) 
         FROM rental WHERE return_date IS NOT NULL) as avg_rental_days
)
SELECT * FROM business_stats;


-- ---------------------------------------------------------
-- 2. ТОП-10 САМЫХ ПОПУЛЯРНЫХ ФИЛЬМОВ
-- ---------------------------------------------------------
SELECT 
    f.title as film_title,
    c.name as category,
    COUNT(r.rental_id) as rental_count,
    ROUND(SUM(p.amount), 2) as total_revenue,
    ROUND(AVG(f.rental_rate), 2) as rental_rate,
    f.rating as age_rating
FROM film f
INNER JOIN inventory i ON f.film_id = i.film_id
INNER JOIN rental r ON i.inventory_id = r.inventory_id
INNER JOIN payment p ON r.rental_id = p.rental_id
INNER JOIN film_category fc ON f.film_id = fc.film_id
INNER JOIN category c ON fc.category_id = c.category_id
GROUP BY f.film_id, c.name
ORDER BY total_revenue DESC
LIMIT 10;


-- ---------------------------------------------------------
-- 3. АНАЛИЗ КЛИЕНТОВ (RFM-АНАЛИЗ)
-- ---------------------------------------------------------
WITH customer_stats AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name as customer_name,
        DATE_PART('day', CURRENT_DATE - MAX(r.rental_date)) as recency,
        COUNT(r.rental_id) as frequency,
        SUM(p.amount) as monetary
    FROM customer c
    INNER JOIN rental r ON c.customer_id = r.customer_id
    INNER JOIN payment p ON r.rental_id = p.rental_id
    GROUP BY c.customer_id
)
SELECT 
    CASE 
        WHEN recency <= 30 THEN 'Активные'
        WHEN recency BETWEEN 31 AND 90 THEN 'Уходящие'
        ELSE 'Потерянные'
    END as recency_segment,
    
    CASE 
        WHEN frequency >= 30 THEN 'VIP'
        WHEN frequency BETWEEN 15 AND 29 THEN 'Постоянные'
        WHEN frequency BETWEEN 5 AND 14 THEN 'Средние'
        ELSE 'Новые'
    END as frequency_segment,
    
    CASE 
        WHEN monetary >= 200 THEN 'Высокий чек'
        WHEN monetary BETWEEN 100 AND 199 THEN 'Средний чек'
        ELSE 'Низкий чек'
    END as monetary_segment,
    
    COUNT(*) as customers_count,
    ROUND(AVG(monetary), 2) as avg_revenue_per_customer,
    ROUND(SUM(monetary), 2) as segment_revenue
FROM customer_stats
GROUP BY recency_segment, frequency_segment, monetary_segment
ORDER BY segment_revenue DESC;


-- ---------------------------------------------------------
-- 4. АНАЛИЗ ДОХОДОВ ПО МЕСЯЦАМ
-- ---------------------------------------------------------
SELECT 
    TO_CHAR(p.payment_date, 'YYYY-MM') as payment_month,
    COUNT(p.payment_id) as transactions_count,
    ROUND(SUM(p.amount), 2) as monthly_revenue,
    COUNT(DISTINCT p.customer_id) as unique_customers,
    ROUND(SUM(p.amount) / COUNT(DISTINCT p.customer_id), 2) as avg_revenue_per_customer
FROM payment p
GROUP BY TO_CHAR(p.payment_date, 'YYYY-MM')
ORDER BY payment_month;


-- ---------------------------------------------------------
-- 5. ПРОСТОЙ АНАЛИЗ ДЛЯ НАЧАЛА
-- ---------------------------------------------------------
-- 5.1 Сколько всего фильмов в каждой категории?
SELECT 
    c.name as category_name,
    COUNT(fc.film_id) as films_count,
    ROUND(AVG(f.rental_rate), 2) as avg_rental_rate
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN film f ON fc.film_id = f.film_id
GROUP BY c.category_id
ORDER BY films_count DESC;

-- 5.2 Топ-5 самых активных клиентов
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    COUNT(r.rental_id) as rentals_count,
    ROUND(SUM(p.amount), 2) as total_spent
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON r.rental_id = p.rental_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 5;