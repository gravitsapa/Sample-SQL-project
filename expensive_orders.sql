WITH price_count AS (
    -- Суммарная стоимость - это сумма количества товара на его стоимость
    SELECT o.order_id as order_id, SUM(i.quantity * i.price_at_order) AS total_cost
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    GROUP BY o.order_id
)
SELECT
    order_id,
    total_cost
FROM price_count
-- Берем только те заказы, где стоимость больше средней
WHERE total_cost > (
    SELECT AVG(total_cost)
    FROM price_count
)
ORDER BY total_cost DESC;
