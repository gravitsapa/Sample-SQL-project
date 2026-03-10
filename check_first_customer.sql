SELECT
    c.full_name AS customer_name,
    o.order_id,
    p.name AS partner_name,
    o.created_at,
    o.status
FROM customers c
-- Соединяем с таблицами заказов и партнеров, чтобы получить всю информацию
JOIN orders o ON c.customer_id = o.customer_id
JOIN partners p ON o.partner_id = p.partner_id
-- Смотрим на конкретного пользователя
WHERE c.customer_id = 1
-- Берем топ 10 последних заказов по времени
ORDER BY o.created_at DESC
LIMIT 10;
