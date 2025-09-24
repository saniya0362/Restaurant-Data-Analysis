-- 1. What are the top 10 most ordered items?
SELECT 
    m.item_name, COUNT(o.order_details_id) AS total_orders
FROM
    order_details o
        JOIN
    menu_items m ON o.item_id = m.menu_item_id
GROUP BY m.item_name
ORDER BY total_orders DESC
LIMIT 10;

-- 2. Which food category has the highest number of menu items?
SELECT 
    category, COUNT(menu_item_id) AS total_menu_items
FROM
    menu_items
GROUP BY category
ORDER BY total_menu_items DESC; 

-- 3. What is the average price of menu items per category?
SELECT 
    category, ROUND(AVG(price), 2) AS avg_price
FROM
    menu_items
GROUP BY category; 

-- 4. On which day of the week do we receive the most orders?
SELECT 
    DAYNAME(order_date) AS day_name,
    COUNT(distinct order_id) AS total_orders
FROM
    order_details
GROUP BY DAYNAME(order_date)
ORDER BY total_orders DESC;

-- 5. What is the distribution of orders by time of day (morning, afternoon, evening, night)?
SELECT 
    CASE
        WHEN HOUR(order_time) < 12 THEN 'morning'
        WHEN HOUR(order_time) < 17 THEN 'afternoon'
        WHEN HOUR(order_time) < 20 THEN 'evening'
        ELSE 'night'
    END AS time_of_day,
    count(*) as total_orders
FROM
    order_details
    group by time_of_day;


-- Intermediate
-- 1. What is the total revenue generated per category? 
SELECT 
    m.category, SUM(m.price) AS revenue
FROM
    menu_items m
        JOIN
    order_details o ON m.menu_item_id = o.item_id
GROUP BY m.category;

-- 2. Which 5 menu items contribute the most to total revenue?
SELECT 
    m.item_name,
    sum(price) as total_revenue
FROM
    menu_items m
        JOIN
    order_details o ON m.menu_item_id = o.item_id
GROUP BY m.item_name
ORDER BY total_revenue DESC
LIMIT 5;

-- 3. What are the daily sales trends for the last 30 days?
SELECT 
    order_date, COUNT(order_details_id) AS qty_sold
FROM
    order_details
WHERE order_date >= (
SELECT 
        MAX(order_date) - INTERVAL 30 DAY
FROM
        order_details)
GROUP BY order_date;
        
-- 4.Which days of the week generate the highest average revenue?
SELECT 
    DAYNAME(order_date) AS days,
    ROUND(AVG(daily_revenue),2) AS avg_revenue
FROM
(SELECT 
    o.order_date, SUM(m.price) AS daily_revenue
FROM
    order_details o
        JOIN
    menu_items m ON o.item_id = m.menu_item_id
GROUP BY o.order_date
) AS daily_revenue
GROUP BY days
ORDER BY avg_revenue DESC;

-- 5. Find the top-selling item for each category.
WITH data AS (
SELECT 
    m.category, m.item_name, COUNT(o.order_details_id) AS sales,
    ROW_NUMBER() OVER (PARTITION BY m.category ORDER BY COUNT(o.order_details_id) DESC) AS ranks
FROM
    menu_items m
        JOIN
    order_details o ON m.menu_item_id = o.item_id
GROUP BY m.category , m.item_name)

SELECT 
    *
FROM
    data d
WHERE
    ranks = 1;
 
-- 6. What percentage of total sales comes from the top 3 menu items?
SELECT 
    m.item_name,
    COUNT(o.order_details_id) AS total_sales,
    ROUND((COUNT(o.order_details_id) / (SELECT 
                    COUNT(order_details_id)
                FROM
                    order_details)) * 100,
            2) AS pct_of_total_sales
FROM
    order_details o
        JOIN
    menu_items m ON o.item_id = m.menu_item_id
GROUP BY m.item_name
ORDER BY total_sales DESC
LIMIT 3;

-- 7. Identify the top 5 least ordered items (could be candidates for menu removal).
SELECT 
    m.item_name, COUNT(o.order_details_id) AS total_orders
FROM
    order_details o
        JOIN
    menu_items m ON o.item_id = m.menu_item_id
GROUP BY m.item_name
ORDER BY total_orders
limit 5;


-- Advanced
-- 1. Rank all items within each category by revenue and show the top 3.
WITH revenue_per_item AS (
SELECT 
    m.category,
    m.item_name,
    SUM(m.price) AS revenue,
    DENSE_RANK() OVER (PARTITION BY category ORDER BY SUM(m.price) DESC) AS ranks
FROM
    menu_items m
        JOIN
    order_details o ON m.menu_item_id = o.item_id
GROUP BY m.category , m.item_name)
SELECT 
    *
FROM
    revenue_per_item
WHERE
    ranks <= 3;
    
-- 2. Find the hourly revenue trend — at what times do we sell the most?
SELECT 
    Hour(o.order_time) AS hours,
    COUNT(o.order_details_id) AS sales,
    SUM(m.price ) AS revenue
FROM
    order_details o
        JOIN
    menu_items m ON o.item_id = m.menu_item_id
GROUP BY hours
ORDER BY sales DESC;

-- 3. Calculate revenue growth week-over-week. 
WITH weekly_revenue AS( 
SELECT 
    WEEK(order_date) AS week,
    SUM(m.price) AS cur_week_revenue
FROM
    order_details o
        JOIN
    menu_items m ON o.item_id = m.menu_item_id
GROUP BY week)

SELECT 
    week,
    cur_week_revenue,
    LAG(cur_week_revenue) OVER (ORDER BY week) AS prev_week_revenue,
    ROUND(((cur_week_revenue - LAG(cur_week_revenue) OVER (ORDER BY week)) /LAG(cur_week_revenue) OVER (ORDER BY week)) * 100,
            2) AS WoW_change
FROM
    weekly_revenue;
    
-- 4. Identify items that are “seasonal” (appear in orders only in certain months). 
SELECT 
    m.item_name,
    COUNT(DISTINCT MONTH(o.order_date)) AS active_months
FROM
    menu_items m
        JOIN
    order_details o ON m.menu_item_id = o.item_id
GROUP BY m.item_name
HAVING active_months < 3
ORDER BY active_months;

-- 5. Find the revenue contribution split between high-priced items (above avg. price) vs low-priced items. 
SELECT 
    CASE
        WHEN
            m.price > (SELECT 
                    ROUND(AVG(mi.price), 2)
                FROM
                    menu_items mi)
        THEN
            'high_price'
        ELSE 'low_price'
    END AS price_type,
    SUM(m.price) AS revenue,
    ROUND((SUM(m.price) / (SELECT 
                    SUM(price)
                FROM
                    menu_items mi
                        JOIN
                    order_details od ON mi.menu_item_id = od.item_id)) * 100,
            2) AS pct_revenue
FROM
    menu_items m
        JOIN
    order_details o ON m.menu_item_id = o.item_id
GROUP BY price_type;

-- 6. Which category shows the highest variability in daily sales?
SELECT 
    category, ROUND(STDDEV(daily_sales),2) AS variability
FROM
    (SELECT 
        m.category,
            o.order_date,
            COUNT(o.order_details_id) AS daily_sales
    FROM
        menu_items m
    JOIN order_details o ON m.menu_item_id = o.item_id
    GROUP BY m.category , o.order_date) AS d
GROUP BY category
ORDER BY variability DESC;

-- 7. Calculate customer basket size (avg number of items per order).
SELECT 
    ROUND(AVG(item_per_order), 2) AS avg_busket_size
FROM
    (SELECT DISTINCT
        o.order_id, COUNT(o.item_id) AS item_per_order
    FROM
        order_details o
    JOIN menu_items m ON o.item_id = m.menu_item_id
    GROUP BY o.order_id) AS data;
    
-- 8. What are the peak ordering periods across the week? To identify when the restaurant receives the highest number of orders.
SELECT 
    DAYNAME(o.order_date) AS days,
    CASE
        WHEN HOUR(order_time) < 12 THEN 'morning'
        WHEN HOUR(order_time) < 17 THEN 'afternoon'
        WHEN HOUR(order_time) < 20 THEN 'evening'
        ELSE 'night'
    END AS time_slot,
    COUNT(o.order_details_id) AS total_order
FROM
    order_details o
GROUP BY days , time_slot;