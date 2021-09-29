--Если добавляется арендатор - юридическое лицо,
--проверка, что в таблице частных лиц ID этого арендатора нет
create or replace function check_legal() returns trigger as $check_legal_renter$
    declare
        private_renterID int;
    begin
        select distinct renterID from private_person
        where private_person.renterID=new.renterID
        into private_renterID;

        if (private_renterID is not null) then
            raise exception '% is illegal renter ID', new.renterID;
        end if;
        return new;
    end
$check_legal_renter$ language plpgsql;

--drop trigger check_legal_renter on legal_person;

create trigger check_legal_renter
    before insert on legal_person
    for each row EXECUTE PROCEDURE check_legal();




--Если добавляется арендатор - частное лицо,
--проверка, что в таблице  юр. лиц ID этого арендатора нет
create or replace function check_private() returns trigger as $check_private_renter$
    declare
        legal_renterID int;
    begin
        select distinct renterID from legal_person
        where legal_person.renterID=new.renterID
        into legal_renterID;

        if (legal_renterID is not null) then
            raise exception '% is illegal renter ID', new.renterID;
        end if;
        return new;
    end
$check_private_renter$ language plpgsql;

--drop trigger check_private_renter on private_person;

create trigger check_private_renter
    before insert on private_person
    for each row EXECUTE PROCEDURE check_private();


create or replace function check_item() returns trigger as $checkitem$
    declare
        priceID int;
        itemquantity int;
    begin
        select distinct price_listID from rental_doc
        where rental_doc.rental_docID=new.rental_docID
        into priceID;

        --Проверка, что при включении товара в документ об аренде,
        --он указан в соответсвующем прайс-листе
        if (priceID != new.price_listID) then
            raise exception '% is illegal price-list ID', new.price_listID;
        end if;

        select distinct quantity from item
        where item.item_number=new.item_number
        into itemquantity;

        --Уменьшение товара на складе
        if (itemquantity < new.quantity) then
            raise exception 'shortage of items in stock';
        end if;
        update item
            set quantity=quantity-new.quantity
            where item.item_number = new.item_number;

        return new;
    end
$checkitem$ language plpgsql;

--drop trigger checkitem on rented_items;

create trigger checkitem
    after insert on rented_items
    for each row EXECUTE PROCEDURE check_item();