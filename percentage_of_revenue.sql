SELECT
    order_id,
    total_cost,
    -- Считаем суммарную выручку
    SUM(total_cost) OVER () AS total_revenue,
    ROUND(
        -- Считаем процент от выручки, принесенный заказом
        total_cost / SUM(total_cost) OVER () * 100,
        2
    ) AS percent_of_total
FROM (
    -- Считаем стоимость заказа
    SELECT o.order_id as order_id, SUM(i.quantity * i.price_at_order) AS total_cost
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    GROUP BY o.order_id
)
-- Группируем по убыванию процента от общей выручки
ORDER BY percent_of_total;
