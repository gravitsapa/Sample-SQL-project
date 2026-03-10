SELECT
    pr.product_id,
    pr.name AS product_name,
    -- Считаем количество заказов, где встречается этот продукт
    COUNT(oi.order_id) AS times_ordered
FROM products pr
-- Соединяем с таблицей заказов
JOIN order_items oi ON pr.product_id = oi.product_id
-- Группируем заказы по id, чтобы посчитать количество заказов для каждого
GROUP BY pr.product_id
-- Берем топ 10 по времени
ORDER BY times_ordered DESC
LIMIT 10;
