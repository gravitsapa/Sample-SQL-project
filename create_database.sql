-- Создадим таблицы заново, если они уже были

DROP TABLE IF EXISTS 
    customers, addresses, partners, products, 
    orders, order_items, couriers, deliveries, payments;

-- Все таблицы имеют 3НФ, т. к. отсутствуют частичные и транзитивные зависимости

-- Таблица клиентов
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    email TEXT,
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- Адреса доставки
CREATE TABLE addresses (
    address_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    street TEXT NOT NULL,
    house TEXT NOT NULL,
    apartment TEXT,
    comment TEXT
);

-- Партнёры (рестораны и магазины)
CREATE TABLE partners (
    partner_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    partner_type TEXT NOT NULL CHECK (partner_type IN ('restaurant', 'store')),
    address TEXT NOT NULL,
    working_hours TEXT
);

-- Товары
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    partner_id INT NOT NULL REFERENCES partners(partner_id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    is_available BOOLEAN NOT NULL DEFAULT TRUE
);

-- Заказы
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    partner_id INT NOT NULL REFERENCES partners(partner_id),
    address_id INT NOT NULL REFERENCES addresses(address_id),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL CHECK (
        status IN ('created', 'accepted', 'delivering', 'completed', 'cancelled')
    )
);

-- Позиции заказа
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    price_at_order NUMERIC(10,2) NOT NULL CHECK (price_at_order > 0)
);

-- Курьеры
CREATE TABLE couriers (
    courier_id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone VARCHAR(20) NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('free', 'busy', 'not at work'))
);

-- Доставка
CREATE TABLE deliveries (
    delivery_id SERIAL PRIMARY KEY,
    order_id INT UNIQUE NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    courier_id INT NOT NULL REFERENCES couriers(courier_id),
    start_time TIMESTAMP,
    end_time TIMESTAMP
);

-- Оплата
CREATE TABLE payments (
    payment_id SERIAL PRIMARY KEY,
    order_id INT UNIQUE NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL CHECK (payment_method IN ('card', 'cash')),
    payment_status TEXT NOT NULL CHECK (
        payment_status IN ('pending', 'paid', 'cancelled')
    )
);

-- Функция изменения статуса курьера
CREATE OR REPLACE FUNCTION set_courier_busy()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE couriers
    -- Устанавливаем курьеру статус "занят"
    SET status = 'busy'
    -- Если номер курьера совпадает с выполняющим заказ
    WHERE courier_id = NEW.courier_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Меняем статус курьера, как только начинается доставка
CREATE OR REPLACE TRIGGER trg_courier_busy
AFTER INSERT ON deliveries
FOR EACH ROW
EXECUTE FUNCTION set_courier_busy();

-- Функция завершения доставки
CREATE OR REPLACE FUNCTION finish_delivery()
RETURNS TRIGGER AS $$
BEGIN
    -- Проверяем, что доставка действительно завершена
    IF NEW.end_time IS NOT NULL AND OLD.end_time IS NULL THEN

        -- Обновляем статус заказа
        UPDATE orders
        SET status = 'completed'
        WHERE order_id = NEW.order_id;

        -- Освобождаем курьера
        UPDATE couriers
        SET status = 'free'
        WHERE courier_id = NEW.courier_id;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Меняем статусы заказа и курьера при завершении доставки
CREATE OR REPLACE TRIGGER trg_finish_delivery
AFTER UPDATE OF end_time ON deliveries
FOR EACH ROW
EXECUTE FUNCTION finish_delivery();

-- Считаем выручку партнера за период
CREATE OR REPLACE FUNCTION partner_revenue(
    p_partner_id INT,
    date_from DATE,
    date_to DATE
)
RETURNS NUMERIC AS $$
DECLARE
    revenue NUMERIC;
BEGIN
    -- Стоимость заказа - это сумма произведений количества товара на его стоимость
    SELECT SUM(i.quantity * i.price_at_order)
    INTO revenue
    FROM orders o
    JOIN order_items i ON i.order_id = o.order_id
    -- Соединяем с таблицей строк заказа, чтобы получить информацию о стоимости
    WHERE o.partner_id = p_partner_id
      AND o.created_at BETWEEN date_from AND date_to
      -- Берем только завершенные заказы
      AND o.status = 'completed';

    RETURN COALESCE(revenue, 0);
END;
$$ LANGUAGE plpgsql;

-- Считаем количество заказов клиента
CREATE OR REPLACE FUNCTION customer_order_count(p_customer_id INT)
RETURNS INT AS $$
DECLARE
    cnt INT;
BEGIN
    -- Считаем строки
    SELECT COUNT(*)
    INTO cnt
    FROM orders
    -- Если заказчик тот, про кого спрашивается
    WHERE customer_id = p_customer_id;

    RETURN cnt;
END;
$$ LANGUAGE plpgsql;


-- Заполнение таблицы клиентов
INSERT INTO customers (full_name, phone, email, registration_date) VALUES
('Иванов Пётр Сергеевич', '+79161234567', 'ivanov@example.com', '2024-01-15'),
('Смирнова Анна Викторовна', '+79262345678', 'smirnova@mail.ru', '2024-02-20'),
('Кузнецов Дмитрий Иванович', '+79373456789', 'kuznetsov@gmail.com', '2024-03-10'),
('Васильева Екатерина Олеговна', '+79484567890', 'vasilieva@yandex.ru', '2024-04-05'),
('Петров Алексей Николаевич', '+79595678901', 'petrov@example.com', '2024-05-12');

-- Заполнение таблицы адресов
INSERT INTO addresses (customer_id, street, house, apartment, comment) VALUES
(1, 'ул. Ленина', '10', '25', 'Домофон 25'),
(1, 'пр. Мира', '15', '7', 'Подъезд 3'),
(2, 'ул. Центральная', '5', '12', 'Этаж 3'),
(3, 'ул. Садовая', '8', '30', 'Белая дверь'),
(4, 'ул. Лесная', '3', '14', NULL),
(5, 'ул. Школьная', '1', '5', 'Квартира на первом этаже');

-- Заполнение таблицы партнёров
INSERT INTO partners (name, partner_type, address, working_hours) VALUES
('Суши-бар "Сакура"', 'restaurant', 'ул. Гастрономическая, 12', '10:00-23:00'),
('Пиццерия "Маргарита"', 'restaurant', 'пр. Итальянский, 5', '11:00-00:00'),
('Магазин "Продукты 24/7"', 'store', 'ул. Круглосуточная, 1', 'круглосуточно'),
('Кофейня "Арабика"', 'restaurant', 'ул. Кофейная, 7', '08:00-22:00'),
('Магазин "Фруктовый рай"', 'store', 'ул. Фруктовая, 3', '09:00-21:00');

-- Заполнение таблицы товаров
INSERT INTO products (partner_id, name, description, price, is_available) VALUES
(1, 'Ролл "Филадельфия"', 'Лосось, сливочный сыр, огурец', 450.00, TRUE),
(1, 'Ролл "Калифорния"', 'Краб-микс, авокадо, икра', 380.00, TRUE),
(1, 'Суши с угрем', 'Угорь, соус унаги, кунжут', 320.00, FALSE),
(2, 'Пицца "Пепперони"', 'Пепперони, сыр моцарелла, томатный соус', 650.00, TRUE),
(2, 'Пицца "4 сыра"', 'Моцарелла, пармезан, горгонзола, дор-блю', 720.00, TRUE),
(3, 'Молоко 3.2%', 'Пастеризованное, 1 л', 85.00, TRUE),
(3, 'Хлеб "Бородинский"', 'Ржаной, 500 г', 65.00, TRUE),
(4, 'Латте', 'Кофе с молоком', 250.00, TRUE),
(4, 'Капучино', 'Кофе с молочной пенкой', 230.00, TRUE),
(5, 'Яблоки "Голден"', 'Свежие, 1 кг', 120.00, TRUE),
(5, 'Бананы', 'Спелые, 1 кг', 90.00, TRUE);

-- Заполнение таблицы заказов
INSERT INTO orders (customer_id, partner_id, address_id, created_at, status) VALUES
(1, 1, 1, '2024-10-01 18:30:00', 'completed'),
(2, 2, 3, '2024-10-02 19:15:00', 'delivering'),
(3, 3, 4, '2024-10-02 20:00:00', 'accepted'),
(4, 4, 5, '2024-10-03 09:45:00', 'created'),
(5, 5, 6, '2024-10-03 10:20:00', 'cancelled'),
(1, 2, 2, '2024-10-03 12:00:00', 'accepted');

-- Заполнение таблицы позиций заказа
INSERT INTO order_items (order_id, product_id, quantity, price_at_order) VALUES
(1, 1, 2, 450.00),
(1, 2, 1, 380.00),
(2, 4, 1, 650.00),
(2, 5, 1, 720.00),
(3, 6, 2, 85.00),
(3, 7, 1, 65.00),
(4, 8, 1, 250.00),
(4, 9, 2, 230.00),
(5, 10, 3, 120.00),
(6, 4, 1, 650.00),
(6, 5, 1, 720.00);

-- Заполнение таблицы курьеров
INSERT INTO couriers (full_name, phone, status) VALUES
('Сидоров Максим Игоревич', '+79031112233', 'busy'),
('Ковалёва Ольга Дмитриевна', '+79042223344', 'busy'),
('Новиков Артём Владимирович', '+79053334455', 'not at work'),
('Морозова Ирина Сергеевна', '+79064445566', 'busy'),
('Кривощеков Виктор Антонович', '+79042281337', 'free');

-- Заполнение таблицы доставок
INSERT INTO deliveries (order_id, courier_id, start_time, end_time) VALUES
(1, 1, '2024-10-01 18:45:00', '2024-10-01 19:30:00'),
(2, 2, '2024-10-02 19:30:00', NULL),
(3, 1, '2024-10-02 20:15:00', NULL),
(6, 4, '2024-10-03 12:20:00', NULL);

-- Заполнение таблицы оплат
INSERT INTO payments (order_id, payment_method, payment_status) VALUES
(1, 'card', 'paid'),
(2, 'cash', 'pending'),
(3, 'card', 'paid'),
(4, 'card', 'pending'),
(5, 'cash', 'cancelled'),
(6, 'card', 'paid');
