-- 1. Получить информацию об ассортименте товаров, имеющихся в бюро. Отчет представить в виде:
-- Наименование name и артикул товара item_number; наименование фирмы-изготовителя manufacturer_name;
-- текущее количество товара на складе quantity; суммарное количество товара на руках у арендаторов sum_quantity;
-- количество товара, для которого срок аренды уже истек expired_quanyity.

with tab1 as ( -- количество товара, для которого срок аренды уже истек
    select item_number, sum(quantity) as expired_quanyity from rented_items
    join rental_doc on rented_items.rental_docID = rental_doc.rental_docID
    where (return_date is null) and (current_date > (release_date + rental_period * interval '1 day'))
    group by item_number
), tab2 as ( -- суммарное количество товара на руках у арендаторов
    select item_number, sum(quantity) as sum_quantity from rented_items
    join rental_doc on rented_items.rental_docID=rental_doc.rental_docID
    where (return_date is null)
    group by item_number
)
select name, item.item_number, manufacturer_name, quantity, coalesce(sum_quantity , 0) as sum_quantity,
       coalesce(expired_quanyity, 0) as expired_quanyity from item
left join tab1 on item.item_number=tab1.item_number
left join tab2 on item.item_number=tab2.item_number;


-- 2. Получить информацию о состоянии дел арендаторов. Отчет представить в виде:
-- Категория арендатора renter_category; ФИО арендатора (одной колонкой) для физического лица
-- или наименование фир-мы для юридического лица name; адрес address; телефон telephone_number;
-- количество оформленных документов об аренде count; общая стоимость всех аренд all_cost;
-- общая сумма выплат по платежным документам all_payments;
-- количество документов об аренде, для которых нарушены сроки аренды fine_count;
-- сумма штрафа за нарушение условий аренды fine; количество документов об аренде, по которым товар еще не возвращен expired_count.

with tab1 as ( -- количество оформленных документов об аренде;
               -- общая стоимость всех аренд
    select rental_doc.renterID, count(rental_doc.rental_docID) as count, sum(cost * rented_items.quantity) as all_cost
    from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    join item on item.item_number=rented_items.item_number
    group by rental_doc.renterID
), tab2 as ( -- общая сумма выплат по платежным документам;
    select rental_doc.renterID, sum(amount) as all_payments from rental_doc
    join rent_payment on rental_doc.rental_docID = rent_payment.rental_docID
    group by rental_doc.renterID
), tab3 as ( -- количество документов об аренде, для которых нарушены сроки аренды;
             -- сумма штрафа за нарушение условий аренды
    select rental_doc.renterID, count(rental_doc.rental_docID) as fine_count,
           sum((current_date - rental_doc.release_date -
                               rental_period * integer'1') * cost * rented_items.quantity) as fine from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    join item on item.item_number=rented_items.item_number
    where (return_date is null) and (current_date > (release_date + rental_period * interval '1 day'))
    group by rental_doc.renterID
), tab4 as ( -- количество документов об аренде, по которым товар еще не возвращен
    select rental_doc.renterID, count(rental_doc.rental_docID) as expired_count from rental_doc
    where return_date is null
    group by rental_doc.renterID
), tab5 as (
    select renter.renterID, renter_category, name, address, telephone_number from renter
    join legal_person lp on renter.renterID = lp.renterID
    union
    select renter.renterID, renter_category, name, address, telephone_number  from renter
    join private_person pp on renter.renterID = pp.renterID
    order by renterID
)
select renter.renterID, renter.renter_category, name, address, telephone_number, count, all_cost,
       coalesce(all_payments, 0) as all_payments, coalesce(fine_count, 0) as fine_count, coalesce(fine, 0) as fine,
       coalesce(expired_count, 0) as expired_count from renter
left join tab5 on tab5.renterID=renter.renterID
left join tab1 on tab1.renterID=renter.renterID
left join tab2 on tab2.renterID=renter.renterID
left join tab3 on tab3.renterID=renter.renterID
left join tab4 on tab4.renterID=renter.renterID;



-- 3. Для товаров, которые были арендованы на самый длительный суммарный срок, получить отчет в следующем виде:
-- Наименование name и артикул товара item_number; наименование фирмы-изготовителя manufacturer_name;
-- общая (суммарная) продолжительность аренды sum_duration; средняя продолжительность аренды (на одну аренду) avg_duration;
-- общее количество документов об аренде, содержащих данный товар doc_count;
-- количество разных клиентов, арендовавших данный товар renter_count; суммарный доход от аренды данного товара profit;
-- количество товара на складе quantity; количество товара на руках у арендаторов rent_quantity.

with tab1 as (
    select item_number, sum(rental_period) as sum from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    group by item_number
), tab as (
    select tab1.item_number from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    join tab1 on tab1.item_number=rented_items.item_number
    group by tab1.item_number
    having sum(rental_period) = (select max(sum) from tab1)
), tab2 as ( -- общая (суммарная) продолжительность аренды;
             -- средняя продолжительность аренды (на одну аренду);
             -- общее количество документов об аренде, содержащих данный товар;
             -- количество разных клиентов, арендовавших данный товар
    select tab.item_number, sum(rental_period) as sum_duration, avg(rental_period) as avg_duration, count(rental_doc.rental_docID) as doc_count,
           count(renterID) as renter_count from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    join tab on tab.item_number=rented_items.item_number
    group by tab.item_number
), tab3 as ( -- суммарный доход от аренды данного товара
    select tab.item_number, sum(cost * rented_items.quantity * rental_period) as profit, sum(rented_items.quantity) as rent_quantity from rented_items
    join item on item.item_number=rented_items.item_number
    join rental_doc on rented_items.rental_docID = rental_doc.rental_docID
    join tab on tab.item_number=rented_items.item_number
    group by tab.item_number
)
select name, item.item_number, manufacturer_name, sum_duration, avg_duration, doc_count, renter_count, profit,
      quantity, rent_quantity from item
join tab2 on item.item_number=tab2.item_number
join tab3 on item.item_number=tab3.item_number;
--join tab4 on item.item_number=tab4.item_number;

with tab1 as (
    select item_number, sum(rental_period) as sum from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    group by item_number
)
    select tab1.item_number from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    join tab1 on tab1.item_number=rented_items.item_number
    group by tab1.item_number
    having sum(rental_period) = (select max(sum) from tab1);

select item_number, sum(rental_period) as sum from rental_doc
    join rented_items on rental_doc.rental_docID = rented_items.rental_docID
    group by item_number;
/*, tab4 as ( -- количество товара на руках у арендаторов
    select tab1.item_number,  from rented_items
    join rental_doc on rented_items.rental_docID = rental_doc.rental_docID
    join tab1 on tab1.item_number=rented_items.item_number
    where (return_date is null)
    group by tab1.item_number
)*/

-- 4. Для клиентов, оформивших максимальное количество договоров аренды, получить отчет в виде:
-- Категория арендатора renter_category; ФИО арендатора для физического лица или наименование фир-мы для юридического лица name;
-- адрес address; телефон telephone_number; количество оформленных документов об аренде max_count;
-- общая стоимость всех аренд all_cost; общая сумма выплат по платежным документам payout;
-- общее количество арендованного товара all_quantity;
-- суммарная продолжительность аренды в днях sum_duration.

with tab as (
    select renterID, count(rental_docID) as count from rental_doc
    group by renterID
), tab1 as (
    select renterID from tab
    where count = (select max(count) from tab)
), tab2 as ( -- количество оформленных документов об аренде
             -- суммарная продолжительность аренды в днях
    select tab1.renterID, count(rental_docID) as max_count, sum(rental_period) as sum_duration from rental_doc
    join tab1 on tab1.renterID=rental_doc.renterID
    group by tab1.renterID
), tab3 as ( -- общая стоимость всех аренд;
             -- общая сумма выплат по платежным документам
             -- общее количество арендованного товара
    select tab1.renterID, sum(cost * rented_items.quantity * rental_period) as all_cost, sum(amount) as payout,
           sum(rented_items.quantity) as all_quantity from rented_items
    join rental_doc on rented_items.rental_docID = rental_doc.rental_docID
    join item on item.item_number=rented_items.item_number
    join rent_payment on rental_doc.rental_docID = rent_payment.rental_docID
    join tab1 on tab1.renterID=rental_doc.renterID
    group by tab1.renterID
), tab5 as (
    select renter.renterID, renter_category, name, address, telephone_number from renter
    join legal_person lp on renter.renterID = lp.renterID
    union
    select renter.renterID, renter_category, name, address, telephone_number  from renter
    join private_person pp on renter.renterID = pp.renterID
    order by renterID
)
select renter.renterID, renter.renter_category, name, address, telephone_number,
       max_count, all_cost, payout, all_quantity, sum_duration from renter
--join tab1 on tab1.renterID=renter.renterID
join tab5 on tab5.renterID=renter.renterID
join tab2 on tab2.renterID=renter.renterID
join tab3 on tab3.renterID=renter.renterID;


with tab1 as (
    select renterID, count(rental_docID) as count from rental_doc
    group by renterID
),
tab4 as ( -- количество товара, находящегося в данный момент у арендатора
    select tab1.renterID, sum(rented_items.quantity) as rented_quantity from rented_items
    join rental_doc on rented_items.rental_docID = rental_doc.rental_docID
    join tab1 on tab1.renterID=rental_doc.renterID
    where return_date is null
    group by tab1.renterID
)
select tab1.renterID from rental_doc
    join tab1 on tab1.renterID=rental_doc.renterID
    where (select count from tab1) = (select max(count) from tab1)
    group by tab1.renterID, rental_docID;




-- 5. Для категорий прайс-листов, чаще всего используемых при оформлении аренды, получить отчет в виде:
-- Категория прайс-листа categoryID; среднее количество товаров, включенных в один прайс-лист данной категории avg_count;
-- количество разных товаров, включенных во все прайс-листы данной категории sum_count;
-- количество документов об аренде, оформленных по прайс-листам данной категории count;
-- общее количество арендаторов, обслуживаемых по прайс-листам данной категории renter_count;
-- количество арендаторов, оформивших документы об аренде count(renterID).

with tab1 as (
    select price_list_categoryID, count(rental_docID) as count from price_list_category
    join price_list on price_list_category.price_listID = price_list.price_listID
    join rental_doc on price_list.price_listID = rental_doc.price_listID
    group by price_list_categoryID
), tab2 as ( -- количество документов об аренде, оформленных по прайс-листам данной категории count
    select tab1.price_list_categoryID as categoryID, count from price_list_category
    join price_list on price_list_category.price_listID = price_list.price_listID
    join rental_doc on price_list.price_listID = rental_doc.price_listID
    join tab1 on tab1.price_list_categoryID=price_list_category.price_list_categoryID
    group by tab1.price_list_categoryID, count
    having count(rental_docID) = (select max(count) from tab1)
), tab3 as (
    select p.price_listID, count(item_number) as item_count from price_list
    join price_list_category p on price_list.price_listID = p.price_listID
    join tab2 on price_list_categoryID=categoryID
    join item_list_line ill on price_list.price_listID = ill.price_listID
    group by p.price_listID
), tab4 as( -- среднее количество товаров, включенных в один прайс-лист данной категории
            -- количество разных товаров, включенных во все прайс-листы данной категории
    select categoryID, avg(item_count) as avg_count, sum(item_count) as sum_count from tab3
    join price_list_category on tab3.price_listID=price_list_category.price_listID
    join tab2 on price_list_categoryID=categoryID
    group by price_list_categoryID, categoryID
), tab5 as ( -- общее количество арендаторов, обслуживаемых по прайс-листам данной категории;
    select tab2.categoryID, count(renter.renterID) as renter_count from renter
    join price_list_category plc on renter.renterID = plc.renterID
    join tab2 on tab2.categoryID=plc.price_list_categoryID
    group by tab2.categoryID
 )
select tab2.categoryID, avg_count, sum_count, count, renter_count, count(renter.renterID) from renter
join price_list_category on renter.renterID = price_list_category.renterID
join tab2 on price_list_categoryID=tab2.categoryID
join tab4 on tab4.categoryID=tab2.categoryID
join tab5 on tab5.categoryID=tab2.categoryID
group by tab2.categoryID, avg_count, sum_count, count, renter_count;
