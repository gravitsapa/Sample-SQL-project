SELECT
    c.courier_id,
    c.full_name AS courier_name,
    COUNT(d.delivery_id) AS deliveries_count
FROM couriers c
-- Соединяем с таблицей доставок
LEFT JOIN deliveries d ON c.courier_id = d.courier_id
-- Группируем по id курьера, чтобы посчитать количество его доставок
GROUP BY c.courier_id
ORDER BY deliveries_count DESC;
