-- ============================================================================
-- Лабораторна робота №3: Маніпулювання даними SQL (OLTP)
-- Предметна область: OpenCRM
-- Автор проєкту: Рубан Олексій
-- Команда: Рубан Олексій, Віталій Гладченко, Симоненко Поліна, Грищенко Ілля
-- ============================================================================

-- ============================================================================
-- РОЗДІЛ 1: ОПЕРАЦІЇ ЧИТАННЯ ТА ФІЛЬТРАЦІЇ ДАНИХ (SELECT / READ)
-- ============================================================================

-- 1.1. Базова проекція: вибірка контактних даних клієнтів (юридичних осіб)
-- Призначення: формування контактного довідника для відділу продажів.
SELECT 
    id,
    company_name,
    contact_person,
    phone,
    email
FROM clients
ORDER BY company_name ASC;

-- 1.2. Фільтрація за ENUM-статусом воронки та сортування за сумою угоди
-- Призначення: моніторинг найбільш перспективних угод на етапах переговорів та погодження договору.
SELECT 
    id,
    client_id,
    manager_id,
    status,
    total_amount
FROM deals
WHERE status IN ('negotiation', 'contract')
ORDER BY total_amount DESC;

-- 1.3. Реляційний запит (INNER JOIN): виграні угоди з іменами менеджерів та клієнтів
-- Призначення: перевірка зв'язків між сутностями та формування звітності про закриті продажі.
SELECT 
    d.id AS deal_id,
    c.company_name AS client_name,
    u.full_name AS manager_name,
    d.status,
    d.total_amount,
    d.updated_at AS won_date
FROM deals d
JOIN clients c ON d.client_id = c.id
JOIN users u ON d.manager_id = u.id
WHERE d.status = 'won';

-- 1.4. Деталізація складу угоди (зв'язок M:N): порівняння фактичної та базової ціни
-- Призначення: аналіз знижок та позицій замовлення для угоди №2 (клієнт «Київстар Дігітал»).
SELECT 
    dp.deal_id,
    p.name AS product_name,
    p.base_price AS catalog_price,
    dp.actual_price AS sold_price,
    dp.quantity,
    (dp.quantity * dp.actual_price) AS line_total,
    (dp.actual_price - p.base_price) AS price_diff
FROM deal_products dp
JOIN products p ON dp.product_id = p.id
WHERE dp.deal_id = 2;

-- 1.5. Фільтрація оперативних завдань для конкретних менеджерів
-- Призначення: формування щоденного розкладу дій для Симоненко Поліни та Грищенка Іллі.
SELECT 
    t.id AS task_id,
    u.full_name AS assigned_manager,
    t.task_type,
    t.status AS task_status,
    t.due_date,
    t.deal_id
FROM tasks t
JOIN users u ON t.assigned_to = u.id
WHERE t.status = 'pending'
  AND u.full_name IN ('Симоненко Поліна', 'Грищенко Ілля')
ORDER BY t.due_date ASC;


-- ============================================================================
-- РОЗДІЛ 2: ДОДАВАННЯ НОВИХ БІЗНЕС-СУТНОСТЕЙ (INSERT / CREATE)
-- ============================================================================

-- 2.1. Додавання нового клієнта з використанням RETURNING (за лекцією 4)
-- Призначення: реєстрація нового корпоративного клієнта із поверненням згенерованого PK.
INSERT INTO clients (company_name, contact_person, phone, email)
VALUES (
    'ТОВ «ДТЕК Енерго Хмарні Рішення»', 
    'Коваль Дмитро Олександрович', 
    '+380509998877', 
    'cloud.solutions@dtek.com'
)
RETURNING id, company_name, created_at;

-- 2.2. Додавання нової сервісної позиції в каталог товарів
-- Призначення: розширення комерційної пропозиції послугою конфігурації аналітики.
INSERT INTO products (name, base_price)
VALUES (
    'Налаштування BI-аналітики та користувацьких дашбордів', 
    16500.00
)
RETURNING id, name, base_price;

-- 2.3. Створення нової первинної угоди для доданого клієнта
-- Призначення: відповідальним менеджером призначається Віталій Гладченко (id = 2).
INSERT INTO deals (client_id, manager_id, status, total_amount)
VALUES (
    6, -- щойно доданий клієнт ДТЕК
    2, -- менеджер Віталій Гладченко
    'new',
    0.00
)
RETURNING id, client_id, manager_id, status;

-- 2.4. Додавання товарних позицій до нової угоди №6 (M:N зв'язок)
INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES 
    (6, 1, 1, 25000.00), -- Базовий пакет CRM
    (6, 7, 1, 16500.00); -- Налаштування BI-аналітики

-- Перевірка створеного замовлення:
SELECT * FROM deal_products WHERE deal_id = 6;


-- ============================================================================
-- РОЗДІЛ 3: МОДИФІКАЦІЯ ДАНИХ ТА ЖИТТЄВИЙ ЦИКЛ ОБ'ЄКТІВ (UPDATE)
-- ============================================================================

-- 3.1. Безпечне оновлення контактної інформації клієнта (обов'язкова умова WHERE)
-- Призначення: оновлення мобільного телефону контактної особи для клієнта №3 («Розетка»).
UPDATE clients
SET 
    phone = '+380639990011',
    contact_person = 'Коваленко Богдан Ігорович (Директор з IT)'
WHERE id = 3;

-- Перевірка результату:
SELECT id, company_name, contact_person, phone FROM clients WHERE id = 3;

-- 3.2. Просування угоди по воронці продажів (Business Workflow)
-- Призначення: Грищенко Ілля провів успішні переговори по угоді №4; переведення з 'new' у 'negotiation'.
UPDATE deals
SET 
    status = 'negotiation',
    updated_at = CURRENT_TIMESTAMP
WHERE id = 4 AND status = 'new';

-- Перевірка результату:
SELECT id, status, updated_at FROM deals WHERE id = 4;

-- 3.3. Виконання оперативного завдання співробітником
-- Призначення: Симоненко Поліна виконала запланований дзвінок клієнту по завданню №1.
UPDATE tasks
SET status = 'completed'
WHERE id = 1 AND status = 'pending';

-- Перевірка результату:
SELECT id, task_type, status FROM tasks WHERE id = 1;

-- 3.4. Автоматичний перерахунок та синхронізація загальної суми угоди №6 за її позиціями
-- Призначення: оновлення поля deals.total_amount агрегованою сумою з deal_products.
UPDATE deals d
SET total_amount = sub.calculated_sum,
    updated_at = CURRENT_TIMESTAMP
FROM (
    SELECT deal_id, SUM(quantity * actual_price) AS calculated_sum
    FROM deal_products
    WHERE deal_id = 6
    GROUP BY deal_id
) sub
WHERE d.id = sub.deal_id;

-- Перевірка актуальної суми угоди №6:
SELECT id, total_amount, updated_at FROM deals WHERE id = 6;


-- ============================================================================
-- РОЗДІЛ 4: ВИДАЛЕННЯ ДАНИХ ТА ПЕРЕВІРКА ОБМЕЖЕНЬ ЦІЛІСНОСТІ (DELETE)
-- ============================================================================

-- 4.1. Безпечне точкове видалення застарілого завдання за первинним ключем
-- Призначення: видалення завершеного завдання №3 з обов'язковою умовою WHERE.
DELETE FROM tasks
WHERE id = 3 AND status = 'completed';

-- 4.2. Перевірка каскадного видалення (ON DELETE CASCADE) та обнулення посилання (ON DELETE SET NULL)
-- Підготовка: створимо тимчасову угоду для перевірки поведінки зовнішніх ключів
INSERT INTO deals (id, client_id, manager_id, status, total_amount)
VALUES (99, 1, 1, 'new', 10000.00);

INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES (99, 1, 1, 10000.00);

INSERT INTO tasks (id, deal_id, assigned_to, task_type, due_date, status)
VALUES (99, 99, 1, 'call', CURRENT_TIMESTAMP + INTERVAL '1 day', 'pending');

-- Видаляємо угоду №99:
DELETE FROM deals WHERE id = 99;

-- Перевірка:
-- 1) Позиція в deal_products повинна бути видалена автоматично (CASCADE):
SELECT COUNT(*) AS cascade_check FROM deal_products WHERE deal_id = 99; -- очікується 0

-- 2) Завдання №99 збереглося, але deal_id став NULL (SET NULL):
SELECT id, deal_id, assigned_to, status FROM tasks WHERE id = 99;

-- Прибираємо тестове завдання:
DELETE FROM tasks WHERE id = 99;

-- 4.3. Демонстрація блокування видалення через обмеження цілісності (ON DELETE RESTRICT)
-- Спроба видалити користувача Рубана Олексія (id = 1), за яким закріплені угоди:
-- ОЧІКУЄТЬСЯ ПОМИЛКА: update or delete on table "users" violates foreign key constraint "deals_manager_id_fkey"
DO $$
BEGIN
    DELETE FROM users WHERE id = 1;
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'УСПІШНИЙ ЗАХИСТ ЦІЛІСНОСТІ: СУБД заблокувала видалення користувача id=1, оскільки існують пов''язані угоди (RESTRICT).';
END $$;


-- ============================================================================
-- РОЗДІЛ 5: КОМПЛЕКСНА OLTP-ТРАНЗАКЦІЯ (ACID ТРАНЗАКЦІЙНІСТЬ)
-- ============================================================================

-- Бізнес-кейс: Клієнт «Київстар» домовляється про розширення співпраці.
-- В одній транзакції виконується:
-- 1. Створення нової угоди менеджером Поліною Симоненко (id = 3).
-- 2. Додавання 2 позицій товарів.
-- 3. Фіксація розрахованої загальної суми угоди.
-- 4. Автоматичне створення завдання менеджеру на підготовку договору.
-- 5. Фіксація операції створення в журналі аудиту audit_logs.

BEGIN;

-- Крок 1: Створення угоди
INSERT INTO deals (id, client_id, manager_id, status, total_amount)
VALUES (10, 2, 3, 'negotiation', 46000.00);

-- Крок 2: Додавання товарних позицій
INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES 
    (10, 3, 2, 18000.00), -- 2 річні підписки на хмару (36 000 грн)
    (10, 6, 1, 10000.00); -- 1 корпоративний тренінг (10 000 грн)

-- Крок 3: Призначення оперативного завдання Поліні
INSERT INTO tasks (deal_id, assigned_to, task_type, due_date, status)
VALUES (10, 3, 'email', CURRENT_TIMESTAMP + INTERVAL '2 days', 'pending');

-- Крок 4: Запис події у незмінний журнал аудиту
INSERT INTO audit_logs (entity_type, entity_id, changed_by, action, new_data)
VALUES (
    'deal', 
    10, 
    3, 
    'CREATE', 
    '{"client_id": 2, "manager_id": 3, "status": "negotiation", "total_amount": 46000.00, "items_count": 2}'::jsonb
);

COMMIT;

-- Фінальна верифікація транзакції:
SELECT d.id, c.company_name, u.full_name AS manager, d.status, d.total_amount
FROM deals d
JOIN clients c ON d.client_id = c.id
JOIN users u ON d.manager_id = u.id
WHERE d.id = 10;
