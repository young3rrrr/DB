-- olap запити для 4 лабораторної роботи
-- Виконав Рубан Олексій Андрійович ІМ-54


-- 1: Сума угод по кожному клієнту.

SELECT * FROM clients;

SELECT c.company_name, c.contact_person, COUNT(d.id) AS total_deals, SUM(d.total_amount) AS total_revenue
FROM clients c
JOIN deals d ON c.id = d.client_id
GROUP BY c.id, c.company_name, c.contact_person
ORDER BY total_revenue DESC;

-- 2: Сума угод по кожному менеджеру.

SELECT * FROM users;

SELECT u.full_name, u.role, COUNT(d.id) AS total_deals, COALESCE(SUM(d.total_amount), 0) AS total_revenue
FROM users u
LEFT JOIN deals d ON u.id = d.manager_id
GROUP BY u.id, u.full_name, u.role
ORDER BY total_revenue DESC;

-- 3: Популярні товари та їх середня вартість.

SELECT * FROM products;
SELECT * FROM deal_products;

SELECT p.name, COUNT(dp.product_id) AS total_sales, ROUND(AVG(dp.actual_price), 2) AS average_price
FROM products p
JOIN deal_products dp ON p.id = dp.product_id
GROUP BY p.id, p.name
HAVING COUNT(dp.product_id) > 2
ORDER BY total_sales DESC;

-- 4: Кількість завдань по кожній угоді.

SELECT * FROM deals;
SELECT * FROM tasks;

SELECT d.id AS deal_id, d.status AS deal_status, d.total_amount, COUNT(t.id) AS total_tasks
FROM deals d
FULL OUTER JOIN tasks t ON d.id = t.deal_id
GROUP BY d.id, d.status, d.total_amount
ORDER BY d.id;