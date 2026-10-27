# Лабораторна робота №3: Маніпулювання даними SQL (OLTP)

**Дисципліна:** Бази даних (КПІ)  
**Предметна область:** OpenCRM (Система управління взаємовідносинами з клієнтами)  
**Автор проєкту:** Рубан Олексій  
**Команда проєкту:**  
- Рубан Олексій (Tech Lead / Admin)  
- Віталій Гладченко (Sales Manager)  
- Симоненко Поліна (Sales Manager)  
- Грищенко Ілля (Sales Manager)  

---

## 1. Мета роботи
- Практичне опанування операцій маніпулювання даними (DML — Data Manipulation Language) у реляційній СУБД PostgreSQL.
- Моделювання реальних бізнес-сценаріїв у стилі **OLTP (Online Transaction Processing)**: виконання точкових, швидкодіючих транзакцій на читання, вставку, оновлення та видалення записів.
- Застосування безпечних практик DML: обов'язкове використання вибіркових предикатів `WHERE`, конструкції `RETURNING`, багатотабличних `JOIN`-запитів, агрегованих `UPDATE`.
- Дослідження та практичне підтвердження механізмів декларативної цілісності даних при модифікації: робота політик `ON DELETE CASCADE`, `ON DELETE SET NULL` та `ON DELETE RESTRICT`.
- Реалізація комплексної атомарної транзакції (ACID) для синхронної модифікації пов'язаних сутностей воронки продажів та аудиту.

---

## 2. Теоретичні основи: Специфіка OLTP-операцій
Системи типу **OLTP (Online Transaction Processing)** орієнтовані на щоденне оперативне обслуговування бізнес-процесів у реальному часі:
- **Характер операцій:** Велика кількість одночасних, коротких транзакцій, які зачіпають окремі рядки (клієнт вносить замовлення, менеджер оновлює статус дзвінка).
- **Вимоги до схеми:** Високий рівень нормалізації для усунення надлишковості та запобігання аномаліям модифікації.
- **Вимоги до цілісності:** Суворе дотримання вимог ACID (Atomicity, Consistency, Isolation, Durability) через зовнішні ключі, обмеження та транзакційні блоки `BEGIN ... COMMIT`.

---

## 3. Детальний опис та виконання OLTP-сценаріїв

### РОЗДІЛ 1: Операції читання та вибірки (SELECT / READ)

#### 1.1. Базова проекція: Контактний довідник клієнтів
* **Бізнес-мета:** Формування актуального телефонного та поштового довідника клієнтів компанії для відділу продажів.
* **SQL-запит:**
```sql
SELECT 
    id,
    company_name,
    contact_person,
    phone,
    email
FROM clients
ORDER BY company_name ASC;
```
* **Результат:** Отримано впорядкований список юридичних осіб без надлишкових системних полів (`created_at`).

---

#### 1.2. Фільтрація за ENUM-статусом воронки та сортування за сумою
* **Бізнес-мета:** Оперативний моніторинг лідів з високим чеком на активних стадіях переговорів (`negotiation`) та погодження договору (`contract`).
* **SQL-запит:**
```sql
SELECT 
    id,
    client_id,
    manager_id,
    status,
    total_amount
FROM deals
WHERE status IN ('negotiation', 'contract')
ORDER BY total_amount DESC;
```
* **Результат виконання:**
```text
 id | client_id | manager_id |   status    | total_amount 
----+-----------+------------+-------------+--------------
  2 |         2 |          2 | contract    |     71000.00
  3 |         3 |          3 | negotiation |     43000.00
```

---

#### 1.3. Реляційний запит (INNER JOIN): Виграні угоди з іменами менеджерів та клієнтів
* **Бізнес-мета:** Аналітика успішно закритих продажів із розіменуванням зовнішніх ключів `client_id` та `manager_id`.
* **SQL-запит:**
```sql
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
```
* **Результат виконання:**
```text
 deal_id |         client_name         | manager_name  | status | total_amount |        won_date        
---------+-----------------------------+---------------+--------+--------------+------------------------
       1 | ТОВ «Нова Пошта Технолоджі» | Рубан Олексій | won    |     55000.00 | 2026-10-05 16:30:00+03
```

---

#### 1.4. Деталізація складу замовлення (зв'язок M:N): Аналіз фактичних цін
* **Бізнес-мета:** Перевірка складу товарних позицій угоди №2 («Київстар Дігітал») та розрахунок наданої клієнту знижки шляхом порівняння `actual_price` з `base_price`.
* **SQL-запит:**
```sql
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
```
* **Результат виконання:**
```text
 deal_id |                product_name                | catalog_price | sold_price | quantity | line_total | price_diff 
---------+--------------------------------------------+---------------+------------+----------+------------+------------
       2 | Впровадження CRM OpenCRM (базовий пакет)   |      25000.00 |   24000.00 |        1 |   24000.00 |   -1000.00
       2 | Інтеграція з IP-телефонією та месенджерами |      12000.00 |   12000.00 |        1 |   12000.00 |       0.00
       2 | Розробка індивідуального модуля аналітики  |      35000.00 |   35000.00 |        1 |   35000.00 |       0.00
```
*Фіксується персональна знижка 1 000.00 грн на базовий пакет.*

---

#### 1.5. Вибірка невиконаних завдань співробітників команди
* **Бізнес-мета:** Формування оперативного розкладу невиконаних дзвінків та зустрічей для Симоненко Поліни та Грищенка Іллі.
* **SQL-запит:**
```sql
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
```

---

### РОЗДІЛ 2: Додавання нових даних (INSERT / CREATE)

#### 2.1. Реєстрація нового клієнта з поверненням ID через `RETURNING`
* **Бізнес-мета:** Додавання контрагента та миттєве отримання згенерованого сервером `id` без повторного запиту (рекомендація Лекції 4).
* **SQL-запит:**
```sql
INSERT INTO clients (company_name, contact_person, phone, email)
VALUES (
    'ТОВ «ДТЕК Енерго Хмарні Рішення»', 
    'Коваль Дмитро Олександрович', 
    '+380509998877', 
    'cloud.solutions@dtek.com'
)
RETURNING id, company_name, created_at;
```
* **Результат:** Згенеровано `id = 6`.

---

#### 2.2. Додавання нової позиції в каталог товарів
* **SQL-запит:**
```sql
INSERT INTO products (name, base_price)
VALUES ('Налаштування BI-аналітики та користувацьких дашбордів', 16500.00)
RETURNING id, name, base_price;
```
* **Результат:** Додано позицію з `id = 7`.

---

#### 2.3. Створення угоди та наповнення складу позицій
* **SQL-запит:**
```sql
INSERT INTO deals (client_id, manager_id, status, total_amount)
VALUES (6, 2, 'new', 0.00)
RETURNING id; -- Отримано id = 6

INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES 
    (6, 1, 1, 25000.00),
    (6, 7, 1, 16500.00);
```

---

### РОЗДІЛ 3: Модифікація та актуалізація даних (UPDATE)

#### 3.1. Безпечне оновлення контакту клієнта
* **SQL-запит:**
```sql
UPDATE clients
SET 
    phone = '+380639990011',
    contact_person = 'Коваленко Богдан Ігорович (Директор з IT)'
WHERE id = 3;
```
* **Результат:** Оновлено строго 1 цільовий рядок (`UPDATE 1`).

---

#### 3.2. Просування угоди по воронці продажів
* **SQL-запит:**
```sql
UPDATE deals
SET 
    status = 'negotiation',
    updated_at = CURRENT_TIMESTAMP
WHERE id = 4 AND status = 'new';
```
* **Результат:** Статус змінено з `new` на `negotiation` з оновленням аудиторської часової мітки.

---

#### 3.3. Виконання оперативного завдання
* **SQL-запит:**
```sql
UPDATE tasks
SET status = 'completed'
WHERE id = 1 AND status = 'pending';
```

---

#### 3.4. Автоматичний перерахунок загальної суми угоди через підзапит
* **Бізнес-мета:** Синхронізація поля `deals.total_amount` із сумою доданих товарних позицій:
* **SQL-запит:**
```sql
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
```
* **Результат:** Сума угоди №6 успішно встановлена у `41500.00` ($25000 + 16500$).

---

### РОЗДІЛ 4: Видалення даних та перевірка обмежень цілісності (DELETE)

#### 4.1. Безпечне точкове видалення за PK
* **SQL-запит:**
```sql
DELETE FROM tasks
WHERE id = 3 AND status = 'completed';
```
* **Результат:** Видалено 1 завершене завдання (`DELETE 1`).

---

#### 4.2. Перевірка каскадного видалення (`CASCADE`) та обнулення (`SET NULL`)
* **Тест:** Створено тестову угоду `id = 99`, прив'язано рядок у `deal_products` та завдання у `tasks`.
* **Команда видалення:**
```sql
DELETE FROM deals WHERE id = 99;
```
* **Верифікація:**
  1. `SELECT COUNT(*) FROM deal_products WHERE deal_id = 99;` $\rightarrow$ повернуло `0` (позиції видалено каскадно).
  2. `SELECT deal_id, assigned_to FROM tasks WHERE id = 99;` $\rightarrow$ рядок зберігся, а поле `deal_id` автоматично стало `NULL`.

---

#### 4.3. Демонстрація блокування видалення через обмеження цілісності (`RESTRICT`)
* **Спроба видалення користувача Рубана Олексія (`id = 1`):**
```sql
DELETE FROM users WHERE id = 1;
```
* **Результат у СУБД:**  
  `ERROR: update or delete on table "users" violates foreign key constraint "deals_manager_id_fkey" on table "deals"`  
  `DETAIL: Key (id)=(1) is still referenced from table "deals".`  
*Обмеження цілісності надійно запобігло видаленню менеджера з активними угодами.*

---

### РОЗДІЛ 5: Комплексна OLTP-транзакція (ACID)
* **Бізнес-кейс:** Одночасне укладання нової угоди менеджером Поліною Симоненко, включення 2 товарів, призначення завдання та фіксація в аудиті.
```sql
BEGIN;

-- 1. Створення угоди
INSERT INTO deals (id, client_id, manager_id, status, total_amount)
VALUES (10, 2, 3, 'negotiation', 46000.00);

-- 2. Додавання товарних позицій
INSERT INTO deal_products (deal_id, product_id, quantity, actual_price)
VALUES 
    (10, 3, 2, 18000.00),
    (10, 6, 1, 10000.00);

-- 3. Призначення завдання менеджеру
INSERT INTO tasks (deal_id, assigned_to, task_type, due_date, status)
VALUES (10, 3, 'email', CURRENT_TIMESTAMP + INTERVAL '2 days', 'pending');

-- 4. Фіксація події у незмінному журналі аудиту
INSERT INTO audit_logs (entity_type, entity_id, changed_by, action, new_data)
VALUES (
    'deal', 
    10, 
    3, 
    'CREATE', 
    '{"client_id": 2, "manager_id": 3, "status": "negotiation", "total_amount": 46000.00, "items_count": 2}'::jsonb
);

COMMIT;
```
*Усі операції успішно зафіксовані в базі як єдиний атомарний крок.*

---

## 4. Висновки
У ході лабораторної роботи №3 повністю реалізовано та протестовано комплекс типових OLTP-операцій над базою даних OpenCRM. Було підтверджено:
1. Коректність обробки складних вибірок `SELECT` з аналізом зв'язків M:N та фільтрацією.
2. Ефективність сучасних конструкцій `RETURNING` та агрегованих оновлень `UPDATE ... FROM`.
3. Захист від втрати даних та порушення цілісності посилань завдяки політикам `RESTRICT`, `CASCADE` та `SET NULL`.
4. Бездоганну роботу транзакційного механізму ACID під час узгодженої зміни кількох сутностей одночасно.
