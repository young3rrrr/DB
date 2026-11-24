-- oltp запити до 3 лабораторної роботи
-- Виконав Рубан Олексій Андрійович ІМ-54


-- 1 Сценарій: Додавання нового користувача та перевірка його наявності.
SELECT * FROM users;

INSERT INTO users (full_name, email, password_hash, role)
VALUES
(
 'John Pork',
 'johnpork@example.com',
 '$2b$12$...',
 'manager'
);

SELECT * FROM users
WHERE full_name = 'John Pork';

UPDATE users
SET email = 'johnpork@gmail.com'
WHERE full_name = 'John Pork'
RETURNING id, full_name, email;

DELETE FROM users
WHERE full_name = 'John Pork'
RETURNING id, full_name;

SELECT * FROM users
WHERE full_name = 'John Pork';

SELECT * FROM users;

-- 2 Сценарій: Перевірка та додавання нових позицій в чек.

SELECT * FROM deals;

SELECT * FROM deal_products
WHERE deal_id = 3;

SELECT * FROM products;

INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES
(
    3, 2, 1, 13500.00
)
RETURNING deal_id, product_id, quantity, actual_price;

INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES
(
    3, 5, 1, 9999.00
)
RETURNING deal_id, product_id, quantity, actual_price;

SELECT * FROM deal_products
WHERE deal_id = 3;

UPDATE deal_products
SET quantity = 2, actual_price = 10000.00
WHERE deal_id = 3 AND product_id = 5
RETURNING deal_id, product_id, quantity, actual_price;

SELECT * FROM deal_products
WHERE deal_id = 3;

DELETE FROM deal_products
WHERE deal_id = 3 AND product_id IN (2, 5);

SELECT * FROM deal_products
WHERE deal_id = 3;